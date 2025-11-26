//
//  AIUsageTracker.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import Combine

/// Tracks AI tool usage for personalized suggestions
/// Persists to UserDefaults and enables data-driven personalization after threshold
@MainActor
final class AIUsageTracker: ObservableObject {

    // MARK: - Singleton
    static let shared = AIUsageTracker()

    // MARK: - Constants
    private let storageKey = "aiToolUsageStats"
    private let minimumCallsForPersonalization = 50

    // MARK: - Usage Stats Model
    struct ToolUsageStats: Codable, Identifiable {
        var id: String { toolName }
        var toolName: String
        var totalCalls: Int
        var lastUsed: Date

        /// Map tool to suggestion configuration
        var suggestionMapping: SuggestionMapping? {
            SuggestionMapping(rawValue: toolName)
        }
    }

    // MARK: - Suggestion Mapping
    /// Maps tool names to suggestion configurations for bulk-focused AI tools
    enum SuggestionMapping: String, CaseIterable {
        // Core task creation
        case createTasks
        // Task operations
        case completeTasks
        case rescheduleTasks
        case deleteTasks
        case updateTasks
        // Smart operations
        case planMyDay
        case cleanup
        case weeklyReview

        var toolName: String { rawValue }

        var suggestionText: String {
            switch self {
            case .createTasks: return "Add new tasks"
            case .completeTasks: return "Mark tasks done"
            case .rescheduleTasks: return "Move tasks"
            case .deleteTasks: return "Delete tasks"
            case .updateTasks: return "Change priority"
            case .planMyDay: return "Plan my day"
            case .cleanup: return "Reschedule overdue"
            case .weeklyReview: return "Weekly summary"
            }
        }

        var icon: String {
            switch self {
            case .createTasks: return "plus.circle.fill"
            case .completeTasks: return "checkmark.circle.fill"
            case .rescheduleTasks: return "calendar.badge.clock"
            case .deleteTasks: return "trash"
            case .updateTasks: return "flag.fill"
            case .planMyDay: return "sun.max.fill"
            case .cleanup: return "arrow.clockwise"
            case .weeklyReview: return "chart.bar.fill"
            }
        }

        var prompt: String {
            switch self {
            case .createTasks: return "Add: "
            case .completeTasks: return "Mark done: "
            case .rescheduleTasks: return "Move to tomorrow: "
            case .deleteTasks: return "Delete: "
            case .updateTasks: return "Set high priority: "
            case .planMyDay: return "Plan my day"
            case .cleanup: return "Reschedule overdue to today"
            case .weeklyReview: return "How was my week?"
            }
        }

        /// Determine suggestion type based on prompt
        var suggestionType: SuggestionType {
            switch self {
            case .createTasks, .completeTasks, .rescheduleTasks, .deleteTasks, .updateTasks:
                return .action
            case .planMyDay, .cleanup, .weeklyReview:
                return .query
            }
        }

        enum SuggestionType {
            case query
            case action
        }
    }

    // MARK: - Published Properties
    @Published private(set) var usageStats: [ToolUsageStats] = []

    // MARK: - Computed Properties

    /// Total number of tool calls across all tools
    var totalCalls: Int {
        usageStats.reduce(0) { $0 + $1.totalCalls }
    }

    /// Whether we have enough data to enable personalization
    var hasEnoughDataForPersonalization: Bool {
        totalCalls >= minimumCallsForPersonalization
    }

    /// Progress towards personalization threshold (0.0 - 1.0)
    var personalizationProgress: Double {
        min(Double(totalCalls) / Double(minimumCallsForPersonalization), 1.0)
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
    }

    // MARK: - Public API

    /// Track a tool call - call this when any AI tool is invoked
    /// - Parameter toolName: The name of the tool (e.g., "createTasks", "queryTasks")
    func trackToolCall(_ toolName: String) {
        if let index = usageStats.firstIndex(where: { $0.toolName == toolName }) {
            // Update existing entry
            usageStats[index].totalCalls += 1
            usageStats[index].lastUsed = Date()
        } else {
            // Create new entry
            usageStats.append(ToolUsageStats(
                toolName: toolName,
                totalCalls: 1,
                lastUsed: Date()
            ))
        }
        saveToStorage()

        #if DEBUG
        print("📊 AIUsageTracker: \(toolName) called (total: \(totalCalls)/\(minimumCallsForPersonalization))")
        #endif
    }

    /// Get top tools sorted by usage frequency
    /// - Parameter limit: Maximum number of tools to return
    /// - Returns: Array of tool stats sorted by usage (most used first)
    func topToolsByUsage(limit: Int = 6) -> [ToolUsageStats] {
        Array(
            usageStats
                .sorted { $0.totalCalls > $1.totalCalls }
                .prefix(limit)
        )
    }

    /// Get usage count for a specific tool
    /// - Parameter toolName: The tool name to query
    /// - Returns: Number of times the tool was called, or 0 if never used
    func usageCount(for toolName: String) -> Int {
        usageStats.first { $0.toolName == toolName }?.totalCalls ?? 0
    }

    /// Reset all usage statistics (for testing or user preference)
    func resetStatistics() {
        usageStats = []
        saveToStorage()

        #if DEBUG
        print("📊 AIUsageTracker: Statistics reset")
        #endif
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            usageStats = try JSONDecoder().decode([ToolUsageStats].self, from: data)
            #if DEBUG
            print("📊 AIUsageTracker: Loaded \(usageStats.count) tool stats (total: \(totalCalls) calls)")
            #endif
        } catch {
            print("⚠️ AIUsageTracker: Failed to decode stats: \(error)")
            usageStats = []
        }
    }

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(usageStats)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("⚠️ AIUsageTracker: Failed to encode stats: \(error)")
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when an AI tool is called - userInfo contains "toolName": String
    static let aiToolCalled = Notification.Name("aiToolCalled")
}
