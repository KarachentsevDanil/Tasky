//
//  CompleteTaskTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for marking tasks as complete or incomplete via LLM
/// Optimized for local LLM with explicit triggers and simple parameters
struct CompleteTaskTool: Tool {
    let name = "completeTask"

    let description = "Mark task done or incomplete. Triggers: done, finished, completed, check off, reopen, uncomplete."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with @Guide descriptions optimized for local LLM
    @Generable
    struct Arguments {
        @Guide(description: "Task title to find. Use exact words from user. Example: 'groceries' or 'buy groceries'")
        let taskTitle: String

        @Guide(description: "true = mark complete (done/finished), false = mark incomplete (reopen/uncomplete)")
        let completed: Bool
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("completeTask")
        let result = await executeCompletion(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeCompletion(arguments: Arguments) async -> String {
        // Find the task using fuzzy matching
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(arguments.taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "Could not find a task matching '\(arguments.taskTitle)'. Try using more of the task title."
            } else {
                return "Could not find '\(arguments.taskTitle)'. Did you mean:\n\(suggestion)"
            }
        }

        // Check if already in desired state
        if task.isCompleted == arguments.completed {
            let state = arguments.completed ? "already complete" : "already incomplete"
            return "'\(task.title)' is \(state)."
        }

        // Store previous state for undo
        let previousState = task.isCompleted
        let taskId = task.id
        let taskTitle = task.title

        // Toggle completion
        do {
            try dataService.toggleTaskCompletion(task)

            let statusText = arguments.completed ? "Done" : "Reopened"

            // Post notification for UI feedback with undo support
            NotificationCenter.default.post(
                name: .aiTaskCompleted,
                object: nil,
                userInfo: [
                    "taskId": taskId as Any,
                    "taskTitle": taskTitle,
                    "completed": arguments.completed,
                    "previousState": previousState,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            return "\(statusText): '\(taskTitle)'"

        } catch {
            HapticManager.shared.error()
            return "Failed to update task: \(error.localizedDescription)"
        }
    }
}
