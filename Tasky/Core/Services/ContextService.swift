//
//  ContextService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

internal import CoreData
import Foundation

// MARK: - Context Service Error
enum ContextServiceError: LocalizedError {
    case saveFailed(underlying: Error)
    case fetchFailed(underlying: Error)
    case deleteFailed(underlying: Error)
    case contextNotFound(key: String, category: String)
    case invalidData(reason: String)

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Unable to save context"
        case .fetchFailed:
            return "Unable to load context"
        case .deleteFailed:
            return "Unable to delete context"
        case .contextNotFound(let key, let category):
            return "Context '\(key)' not found in \(category)"
        case .invalidData(let reason):
            return "Invalid data: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .fetchFailed, .deleteFailed:
            return "Please try again. If the problem persists, restart the app."
        case .contextNotFound:
            return "The item may have been deleted."
        case .invalidData:
            return "Please check your input and try again."
        }
    }
}

/// Service for managing user context memory
/// Handles CRUD operations, confidence management, and retrieval for AI prompts
@MainActor
class ContextService {

    // MARK: - Singleton
    static let shared = ContextService()

    // MARK: - Properties
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - Constants
    private let maxContextItems = 100
    private let minConfidenceThreshold: Float = 0.1
    private let staleAccessDays = 90

    // MARK: - Initialization
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - CRUD Operations

    /// Save or update context item
    /// If an item with the same key+category exists, it will be reinforced instead of duplicated
    @discardableResult
    func saveContext(
        category: ContextCategory,
        key: String,
        value: String,
        source: ContextSource,
        metadata: [String: Any]? = nil
    ) throws -> UserContextEntity {
        let normalizedKey = key.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for existing context with same key + category
        if let existing = try fetchContext(category: category, key: normalizedKey) {
            // Reinforce existing context
            try reinforceContext(existing, newValue: value)
            return existing
        }

        // Create new context
        let context = UserContextEntity(context: viewContext)
        context.id = UUID()
        context.category = category.rawValue
        context.key = normalizedKey
        context.value = value
        context.source = source.rawValue
        context.confidence = source.baseConfidence
        context.createdAt = Date()
        context.updatedAt = Date()
        context.accessCount = 0
        context.reinforcementCount = 0

        if let metadata = metadata {
            context.setMetadata(metadata)
        }

        // Enforce max items limit
        try enforceItemLimit()

        try persistenceController.save(context: viewContext)
        print("✅ ContextService: Saved new context '\(normalizedKey)' in category '\(category.rawValue)'")

        return context
    }

    /// Fetch a specific context item by category and key
    func fetchContext(category: ContextCategory, key: String) throws -> UserContextEntity? {
        let normalizedKey = key.lowercased().trimmingCharacters(in: .whitespaces)

        let request = UserContextEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "category == %@ AND key == %@",
            category.rawValue,
            normalizedKey
        )
        request.fetchLimit = 1

        return try viewContext.fetch(request).first
    }

    /// Fetch all context items, optionally filtered by category and minimum confidence
    func fetchAllContext(
        category: ContextCategory? = nil,
        minConfidence: Float = 0,
        limit: Int? = nil
    ) throws -> [UserContextEntity] {
        let request = UserContextEntity.fetchRequest()

        var predicates: [NSPredicate] = []

        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category.rawValue))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UserContextEntity.confidence, ascending: false),
            NSSortDescriptor(keyPath: \UserContextEntity.updatedAt, ascending: false)
        ]

        if let limit = limit {
            request.fetchLimit = limit
        }

        let results = try viewContext.fetch(request)

        // Filter by effective confidence (includes decay)
        if minConfidence > 0 {
            return results.filter { $0.effectiveConfidence >= minConfidence }
        }

        return results
    }

    /// Fetch context items from multiple categories
    func fetchAllContext(
        categories: [ContextCategory],
        minConfidence: Float = 0,
        limit: Int? = nil
    ) throws -> [UserContextEntity] {
        let request = UserContextEntity.fetchRequest()

        let categoryStrings = categories.map { $0.rawValue }
        request.predicate = NSPredicate(format: "category IN %@", categoryStrings)

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UserContextEntity.confidence, ascending: false),
            NSSortDescriptor(keyPath: \UserContextEntity.updatedAt, ascending: false)
        ]

        if let limit = limit {
            request.fetchLimit = limit
        }

        let results = try viewContext.fetch(request)

        // Filter by effective confidence
        if minConfidence > 0 {
            return results.filter { $0.effectiveConfidence >= minConfidence }
        }

        return results
    }

    /// Get total context item count
    func fetchContextCount() throws -> Int {
        let request = UserContextEntity.fetchRequest()
        return try viewContext.count(for: request)
    }

    /// Delete a specific context item
    func deleteContext(_ context: UserContextEntity) throws {
        viewContext.delete(context)
        try persistenceController.save(context: viewContext)
        print("🗑️ ContextService: Deleted context '\(context.key)'")
    }

    /// Delete all context items in a category
    func deleteAllContext(category: ContextCategory) throws -> Int {
        let request = UserContextEntity.fetchRequest()
        request.predicate = NSPredicate(format: "category == %@", category.rawValue)

        let items = try viewContext.fetch(request)
        let count = items.count

        for item in items {
            viewContext.delete(item)
        }

        try persistenceController.save(context: viewContext)
        print("🗑️ ContextService: Deleted \(count) items from category '\(category.rawValue)'")

        return count
    }

    /// Delete all context items
    func deleteAllContext() throws -> Int {
        let request = UserContextEntity.fetchRequest()
        let items = try viewContext.fetch(request)
        let count = items.count

        for item in items {
            viewContext.delete(item)
        }

        try persistenceController.save(context: viewContext)
        print("🗑️ ContextService: Deleted all \(count) context items")

        return count
    }

    // MARK: - Confidence Management

    /// Reinforce an existing context item (increase confidence, update timestamp)
    func reinforceContext(_ context: UserContextEntity, newValue: String? = nil) throws {
        let boostFactor = context.sourceEnum.boostFactor

        // Asymptotic reinforcement: newConfidence = current + (1 - current) * boost
        context.confidence = context.confidence + (1.0 - context.confidence) * boostFactor
        context.reinforcementCount += 1
        context.updatedAt = Date()

        // Merge values if new info provided and not already present
        if let newValue = newValue,
           !newValue.isEmpty,
           !context.value.lowercased().contains(newValue.lowercased()) {
            context.value = "\(context.value); \(newValue)"
        }

        try persistenceController.save(context: viewContext)
        print("🔄 ContextService: Reinforced context '\(context.key)' -> confidence: \(context.confidence)")
    }

    /// Mark context as accessed (for staleness tracking)
    func markAsAccessed(_ context: UserContextEntity) throws {
        context.lastAccessedAt = Date()
        context.accessCount += 1
        try persistenceController.save(context: viewContext)
    }

    /// Mark multiple contexts as accessed
    func markAsAccessed(_ contexts: [UserContextEntity]) throws {
        let now = Date()
        for context in contexts {
            context.lastAccessedAt = now
            context.accessCount += 1
        }
        try persistenceController.save(context: viewContext)
    }

    // MARK: - AI Prompt Retrieval

    /// Fetch relevant context for AI prompts
    func fetchRelevantContext(
        for query: String = "",
        maxItems: Int = 12,
        minConfidence: Float = 0.3
    ) throws -> [UserContextEntity] {
        let allContext = try fetchAllContext(minConfidence: minConfidence)

        // If no query, return top items by confidence
        if query.isEmpty {
            let topItems = Array(allContext.prefix(maxItems))
            try markAsAccessed(topItems)
            return topItems
        }

        // Score items by relevance to query
        let queryWords = Set(query.lowercased().components(separatedBy: .whitespaces))
        let scored = allContext.map { context -> (UserContextEntity, Double) in
            var score = Double(context.effectiveConfidence)

            // Boost if key matches query
            if queryWords.contains(context.key.lowercased()) {
                score += 1.0
            }

            // Boost if value contains query words
            let valueWords = Set(context.value.lowercased().components(separatedBy: .whitespaces))
            let overlap = queryWords.intersection(valueWords).count
            score += Double(overlap) * 0.3

            return (context, score)
        }

        // Sort by score and take top items
        let topItems = scored
            .sorted { $0.1 > $1.1 }
            .prefix(maxItems)
            .map { $0.0 }

        try markAsAccessed(Array(topItems))
        return Array(topItems)
    }

    /// Fetch context for specific AI intent
    func fetchContextForIntent(_ intent: AIIntent) throws -> [UserContextEntity] {
        switch intent {
        case .createTask:
            return try fetchAllContext(categories: [.person, .goal], minConfidence: 0.5, limit: 5)
        case .planDay:
            return try fetchAllContext(categories: [.schedule, .constraint, .goal, .pattern], minConfidence: 0.5, limit: 10)
        case .prioritize:
            return try fetchAllContext(categories: [.goal, .person], minConfidence: 0.5, limit: 8)
        case .query:
            return try fetchAllContext(categories: [.person, .goal], minConfidence: 0.3, limit: 5)
        case .general:
            return try fetchAllContext(minConfidence: 0.5, limit: 12)
        }
    }

    /// Format context items for inclusion in AI prompt
    func formatContextForPrompt(_ contexts: [UserContextEntity]) -> String {
        guard !contexts.isEmpty else { return "" }

        let lines = contexts.map { $0.promptDescription }
        return lines.joined(separator: "\n- ")
    }

    // MARK: - Maintenance Operations

    /// Perform daily maintenance (prune stale items, enforce limits)
    func performDailyMaintenance() async throws {
        print("🔧 ContextService: Starting daily maintenance...")

        var prunedCount = 0
        var limitEnforced = 0

        // 1. Prune stale items (low confidence AND not accessed recently)
        let allContext = try fetchAllContext()
        for context in allContext {
            if context.isStale {
                viewContext.delete(context)
                prunedCount += 1
            }
        }

        // 2. Remove weak patterns (< 3 data points AND older than 30 days)
        let patterns = try fetchAllContext(category: .pattern)
        for pattern in patterns {
            if let metadata = try? JSONDecoder().decode(PatternMetadata.self, from: pattern.metadata ?? Data()),
               metadata.dataPoints < 3,
               pattern.daysSinceUpdate > 30 {
                viewContext.delete(pattern)
                prunedCount += 1
            }
        }

        try persistenceController.save(context: viewContext)

        // 3. Enforce 100 item limit
        let count = try fetchContextCount()
        if count > maxContextItems {
            let excess = count - maxContextItems
            let sortedByConfidence = try fetchAllContext()
                .sorted { $0.effectiveConfidence < $1.effectiveConfidence }

            for item in sortedByConfidence.prefix(excess) {
                viewContext.delete(item)
                limitEnforced += 1
            }
            try persistenceController.save(context: viewContext)
        }

        print("🔧 ContextService: Maintenance complete - pruned: \(prunedCount), limit enforced: \(limitEnforced)")
    }

    /// Perform light maintenance (quick check, only if obviously needed)
    func performLightMaintenance() async throws {
        let count = try fetchContextCount()
        if count > maxContextItems {
            try await performDailyMaintenance()
        }
    }

    // MARK: - Private Helpers

    /// Enforce maximum items limit by removing lowest confidence items
    private func enforceItemLimit() throws {
        let count = try fetchContextCount()
        if count >= maxContextItems {
            // Remove the lowest confidence item
            let request = UserContextEntity.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \UserContextEntity.confidence, ascending: true)
            ]
            request.fetchLimit = 1

            if let lowest = try viewContext.fetch(request).first {
                viewContext.delete(lowest)
                print("🗑️ ContextService: Removed lowest confidence item '\(lowest.key)' to enforce limit")
            }
        }
    }

    // MARK: - Fuzzy Search

    /// Search context items by keyword (fuzzy matching)
    func searchContext(keyword: String) throws -> [UserContextEntity] {
        let lowercased = keyword.lowercased().trimmingCharacters(in: .whitespaces)

        let request = UserContextEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "key CONTAINS[cd] %@ OR value CONTAINS[cd] %@",
            lowercased,
            lowercased
        )
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \UserContextEntity.confidence, ascending: false)
        ]

        return try viewContext.fetch(request)
    }
}

// MARK: - AI Intent
enum AIIntent {
    case createTask
    case planDay
    case prioritize
    case query
    case general
}
