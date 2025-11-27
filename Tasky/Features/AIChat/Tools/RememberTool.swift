//
//  RememberTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Tool for saving user context to the ContextStore
struct RememberTool: Tool {
    let name = "remember"

    let description = "Save information about the user: people, preferences, schedule patterns, goals, or constraints. For future reference."

    let contextService: ContextService

    init(contextService: ContextService = .shared) {
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "What to remember (1-500 chars)")
        let information: String

        @Guide(description: "Type of information")
        @Guide(.anyOf(["person", "preference", "schedule", "goal", "constraint", "other"]))
        let category: String

        @Guide(description: "Short identifier key for retrieval. Auto-generated if not provided.")
        let key: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("remember")
        let result = try await executeRemember(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeRemember(arguments: Arguments) async throws -> String {
        // Validate information length
        let info = arguments.information.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !info.isEmpty else {
            return "Please provide some information to remember."
        }
        guard info.count <= 500 else {
            return "Information is too long. Please keep it under 500 characters."
        }

        // Parse category
        let category = ContextCategory(rawValue: arguments.category) ?? .other

        // Generate key if not provided
        let key = arguments.key?.lowercased().trimmingCharacters(in: .whitespaces)
            ?? generateKey(from: info, category: category)

        // Build metadata based on category
        var metadata: [String: Any]?

        if category == .person {
            // Try to infer relationship from common patterns
            let relationship = inferRelationship(from: info)
            if let relationship = relationship {
                let personMeta = PersonMetadata(
                    relationship: relationship,
                    importance: .medium,
                    associatedLists: nil,
                    lastMentionedTaskId: nil
                )
                if let encoded = try? JSONEncoder().encode(personMeta),
                   let dict = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] {
                    metadata = dict
                }
            }
        }

        do {
            let context = try contextService.saveContext(
                category: category,
                key: key,
                value: info,
                source: .explicit,
                metadata: metadata
            )

            // Format response based on category
            let response: String
            switch category {
            case .person:
                response = "I'll remember that \(key.capitalized) is \(info)."
            case .preference:
                response = "Got it, I'll keep in mind that you \(info.lowercased())."
            case .schedule:
                response = "I'll remember your schedule: \(info)."
            case .goal:
                response = "I'll keep track of your goal: \(info)."
            case .constraint:
                response = "Noted. I'll respect that \(info.lowercased())."
            case .pattern, .other:
                response = "I'll remember that: \(info)."
            }

            HapticManager.shared.success()
            return response

        } catch {
            print("❌ RememberTool error: \(error)")
            HapticManager.shared.error()
            return "Sorry, I couldn't save that information. Please try again."
        }
    }

    /// Generate a key from the information text
    private func generateKey(from info: String, category: ContextCategory) -> String {
        let words = info.lowercased()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && $0.count > 2 }

        // For people, try to extract the name (capitalized words)
        if category == .person {
            let capitalizedWords = info
                .components(separatedBy: .whitespaces)
                .filter { word in
                    guard let first = word.first else { return false }
                    return first.isUppercase && word.count > 1
                }
            if let name = capitalizedWords.first {
                return name.lowercased()
            }
        }

        // Take first 2-3 significant words
        let significant = words.prefix(3)
        return significant.joined(separator: "_")
    }

    /// Try to infer relationship from common patterns
    private func inferRelationship(from info: String) -> PersonMetadata.PersonRelationship? {
        let lowercased = info.lowercased()

        if lowercased.contains("manager") || lowercased.contains("boss") {
            return .manager
        }
        if lowercased.contains("colleague") || lowercased.contains("coworker") || lowercased.contains("team") {
            return .colleague
        }
        if lowercased.contains("report") || lowercased.contains("direct report") {
            return .report
        }
        if lowercased.contains("client") || lowercased.contains("customer") {
            return .client
        }
        if lowercased.contains("mom") || lowercased.contains("dad") || lowercased.contains("parent")
            || lowercased.contains("brother") || lowercased.contains("sister") || lowercased.contains("family") {
            return .family
        }
        if lowercased.contains("friend") {
            return .friend
        }
        if lowercased.contains("partner") || lowercased.contains("spouse") || lowercased.contains("husband")
            || lowercased.contains("wife") {
            return .partner
        }

        return nil
    }
}
