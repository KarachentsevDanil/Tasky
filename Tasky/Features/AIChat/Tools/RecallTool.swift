//
//  RecallTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when recall returns results (for inline UI display)
extension Notification.Name {
    static let aiRecallResults = Notification.Name("aiRecallResults")
}

/// Tool for retrieving stored user context
struct RecallTool: Tool {
    let name = "recall"

    let description = "Show what I know about the user: people, preferences, schedule, goals, or constraints."

    let contextService: ContextService

    init(contextService: ContextService = .shared) {
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter by type")
        @Guide(.anyOf(["all", "person", "preference", "schedule", "goal", "constraint", "pattern"]))
        let category: String?

        @Guide(description: "Specific topic or keyword to search")
        let topic: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("recall")
        let result = try await executeRecall(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeRecall(arguments: Arguments) async throws -> String {
        var contexts: [UserContextEntity] = []

        // If topic provided, search by keyword
        if let topic = arguments.topic, !topic.isEmpty {
            contexts = try contextService.searchContext(keyword: topic)
        }
        // If category provided (and not "all"), filter by category
        else if let categoryString = arguments.category,
                categoryString != "all",
                let category = ContextCategory(rawValue: categoryString) {
            contexts = try contextService.fetchAllContext(category: category, minConfidence: 0.1)
        }
        // Otherwise, fetch all
        else {
            contexts = try contextService.fetchAllContext(minConfidence: 0.1)
        }

        // No results
        if contexts.isEmpty {
            if let topic = arguments.topic {
                return "I don't have any information stored about '\(topic)'. You can tell me things to remember."
            }
            if let category = arguments.category, category != "all" {
                return "I don't have any \(category) information stored yet. You can tell me things to remember."
            }
            return "I don't have any information stored yet. You can tell me things to remember by saying 'remember that...'."
        }

        // Post notification for inline UI display
        NotificationCenter.default.post(
            name: .aiRecallResults,
            object: nil,
            userInfo: ["contexts": contexts]
        )

        // Format results by category
        return formatResults(contexts)
    }

    /// Format recall results for display
    private func formatResults(_ contexts: [UserContextEntity]) -> String {
        // Group by category
        var grouped: [ContextCategory: [UserContextEntity]] = [:]

        for context in contexts {
            let category = context.categoryEnum
            if grouped[category] == nil {
                grouped[category] = []
            }
            grouped[category]?.append(context)
        }

        // Format output
        var sections: [String] = []
        let categoryOrder: [ContextCategory] = [.person, .schedule, .goal, .preference, .constraint, .pattern, .other]

        for category in categoryOrder {
            guard let items = grouped[category], !items.isEmpty else { continue }

            var section = "\(category.displayName):\n"
            for item in items.prefix(5) {  // Limit to 5 per category
                let confidenceIndicator = confidenceEmoji(item.effectiveConfidence)
                section += "• \(item.key.capitalized): \(item.value) \(confidenceIndicator)\n"
            }

            if items.count > 5 {
                section += "  ...and \(items.count - 5) more\n"
            }

            sections.append(section)
        }

        if sections.isEmpty {
            return "I don't have any information stored yet."
        }

        return "Here's what I know:\n\n" + sections.joined(separator: "\n")
    }

    /// Get emoji indicator for confidence level
    private func confidenceEmoji(_ confidence: Float) -> String {
        if confidence >= 0.7 {
            return ""  // High confidence, no indicator needed
        } else if confidence >= 0.4 {
            return "(~)"  // Medium confidence
        } else {
            return "(?)"  // Low confidence
        }
    }
}
