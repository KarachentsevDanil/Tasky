//
//  ForgetContextTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Tool for deleting stored user context
struct ForgetContextTool: Tool {
    let name = "forgetContext"

    let description = "Delete stored information about the user. Can forget specific topics or clear categories."

    let contextService: ContextService

    init(contextService: ContextService = .shared) {
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "What to forget: specific key, category name (person, preference, schedule, goal, constraint, pattern), or 'all' for everything")
        let topic: String

        @Guide(description: "Must be true to execute deletion. Required for confirmation.")
        let confirm: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("forgetContext")
        let result = try await executeForget(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeForget(arguments: Arguments) async throws -> String {
        let topic = arguments.topic.lowercased().trimmingCharacters(in: .whitespaces)

        // Check for "all" - clear everything
        if topic == "all" {
            if arguments.confirm != true {
                return "This will delete all stored information about you. Say 'forget all, confirm' to proceed."
            }

            do {
                let count = try contextService.deleteAllContext()
                HapticManager.shared.success()
                return "Cleared all stored context (\(count) items)."
            } catch {
                HapticManager.shared.error()
                return "Sorry, I couldn't clear the stored information. Please try again."
            }
        }

        // Check if topic is a category name
        if let category = ContextCategory(rawValue: topic) {
            // Get count first
            let items = try contextService.fetchAllContext(category: category)
            if items.isEmpty {
                return "I don't have any \(category.displayName.lowercased()) information stored."
            }

            if arguments.confirm != true && items.count > 1 {
                return "This will delete \(items.count) items in the \(category.displayName) category. Say 'forget \(topic), confirm' to proceed."
            }

            do {
                let count = try contextService.deleteAllContext(category: category)
                HapticManager.shared.success()
                return "Cleared all \(count) items in the \(category.displayName) category."
            } catch {
                HapticManager.shared.error()
                return "Sorry, I couldn't clear that category. Please try again."
            }
        }

        // Otherwise, try to find specific item(s) by keyword
        let matches = try contextService.searchContext(keyword: topic)

        if matches.isEmpty {
            return "I don't have any information about '\(topic)' stored."
        }

        if matches.count == 1 {
            // Single match - can delete without additional confirmation
            let item = matches[0]
            do {
                try contextService.deleteContext(item)
                HapticManager.shared.success()
                return "Removed information about '\(item.key)'."
            } catch {
                HapticManager.shared.error()
                return "Sorry, I couldn't remove that information. Please try again."
            }
        }

        // Multiple matches - need confirmation
        if arguments.confirm != true {
            let matchList = matches.prefix(3).map { "'\($0.key)'" }.joined(separator: ", ")
            let more = matches.count > 3 ? " and \(matches.count - 3) more" : ""
            return "Found \(matches.count) items matching '\(topic)': \(matchList)\(more). Say 'forget \(topic), confirm' to delete all of them."
        }

        // Delete all matches
        var deletedCount = 0
        for item in matches {
            do {
                try contextService.deleteContext(item)
                deletedCount += 1
            } catch {
                print("❌ Failed to delete context item: \(item.key)")
            }
        }

        HapticManager.shared.success()
        return "Removed \(deletedCount) items matching '\(topic)'."
    }
}
