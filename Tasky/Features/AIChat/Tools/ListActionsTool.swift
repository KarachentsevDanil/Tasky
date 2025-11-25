//
//  ListActionsTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool that lists all available actions/capabilities
/// This ensures consistent responses when users ask "what can you do?" or "what actions are available?"
struct ListActionsTool: Tool {

    // MARK: - Tool Protocol
    let name = "listActions"
    let description = "List available actions and capabilities. Triggers: what can you do, help, available actions, capabilities, commands."

    // MARK: - Arguments
    @Generable
    struct Arguments {
        @Guide(description: "Optional category filter: tasks, lists, productivity, all")
        let category: String?
    }

    // MARK: - Call
    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("listActions")
        let category = arguments.category?.lowercased() ?? "all"

        var actions: [String] = []

        // Task management actions
        if category == "all" || category == "tasks" {
            actions.append(contentsOf: [
                "**Task Management:**",
                "• Create tasks - \"Add buy milk\" or \"Remind me to call mom tomorrow\"",
                "• Complete tasks - \"Done with groceries\" or \"Mark meeting as complete\"",
                "• Reschedule tasks - \"Move laundry to tomorrow\" or \"Postpone report to next week\"",
                "• Update tasks - \"Rename task to...\" or \"Set priority high\" or \"Add notes\"",
                "• Delete tasks - \"Delete the old task\" or \"Remove cancelled meeting\"",
                "• Query tasks - \"What's due today?\" or \"Show overdue tasks\""
            ])
        }

        // List management actions
        if category == "all" || category == "lists" {
            if !actions.isEmpty { actions.append("") }
            actions.append(contentsOf: [
                "**List Management:**",
                "• Create lists - \"Create a Work list\" or \"New list called Shopping\"",
                "• Rename lists - \"Rename Work to Office\"",
                "• Delete lists - \"Delete the old list\""
            ])
        }

        // Productivity actions
        if category == "all" || category == "productivity" {
            if !actions.isEmpty { actions.append("") }
            actions.append(contentsOf: [
                "**Productivity:**",
                "• Focus sessions - \"Start 25-minute focus\" or \"Pomodoro on homework\"",
                "• Analytics - \"How am I doing?\" or \"Show my progress\" or \"My streak\""
            ])
        }

        return GeneratedContent(actions.joined(separator: "\n"))
    }
}
