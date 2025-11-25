//
//  FocusSessionTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for managing focus/Pomodoro sessions via LLM
/// Optimized for local LLM with explicit action options
struct FocusSessionTool: Tool {
    let name = "focusSession"

    let description = "Manage focus sessions. Triggers: focus on, start focus, pomodoro, deep work, stop focus, end session."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with explicit action options
    @Generable
    struct Arguments {
        @Guide(description: "Focus session action")
        @Guide(.anyOf(["start", "stop", "status"]))
        let action: String

        @Guide(description: "Task title to focus on. Required for start action.")
        let taskTitle: String?

        @Guide(description: "Duration in minutes. Default 25. Common: 15, 25, 45, 60")
        let durationMinutes: Int?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeAction(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAction(arguments: Arguments) async -> String {
        switch arguments.action.lowercased() {
        case "start":
            return await startSession(arguments)
        case "stop":
            return await stopSession()
        case "status":
            return await getStatus()
        default:
            return "Unknown action '\(arguments.action)'. Use: start, stop, or status."
        }
    }

    @MainActor
    private func startSession(_ arguments: Arguments) async -> String {
        // Check for task title
        guard let taskTitle = arguments.taskTitle, !taskTitle.isEmpty else {
            return "Please specify which task to focus on."
        }

        // Find the task
        guard let task = AIToolHelpers.findTask(taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "Could not find a task matching '\(taskTitle)'."
            } else {
                return "Could not find '\(taskTitle)'. Did you mean:\n\(suggestion)"
            }
        }

        // Check if task is completed
        if task.isCompleted {
            return "'\(task.title)' is already completed. Choose an active task to focus on."
        }

        // Get duration (default 25 minutes, clamp between 5-120)
        let duration = min(max(arguments.durationMinutes ?? 25, 5), 120)

        // Post notification to start focus session
        NotificationCenter.default.post(
            name: .aiFocusSessionStart,
            object: nil,
            userInfo: [
                "taskId": task.id as Any,
                "taskTitle": task.title,
                "durationMinutes": duration
            ]
        )

        HapticManager.shared.success()

        var response = "Focus session started!\n"
        response += "Task: \(task.title)\n"
        response += "Duration: \(duration) minutes\n"
        response += "\nStay focused! Say \"stop focus\" when done."

        // Add tip based on duration
        if duration >= 45 {
            response += "\n\nLong session - consider a 10-15 min break after."
        } else if duration == 25 {
            response += "\n\nClassic Pomodoro! Take a 5 min break after."
        }

        return response
    }

    @MainActor
    private func stopSession() async -> String {
        // Post notification to stop focus session
        NotificationCenter.default.post(
            name: .aiFocusSessionStop,
            object: nil,
            userInfo: [:]
        )

        HapticManager.shared.lightImpact()

        return "Focus session ended.\n\nGreat work! Take a short break before your next session."
    }

    @MainActor
    private func getStatus() async -> String {
        // Post notification requesting status update in the UI
        NotificationCenter.default.post(
            name: .aiFocusSessionStatus,
            object: nil,
            userInfo: [:]
        )

        // Note: Focus session state is managed by the FocusTimerViewModel
        // The tool can signal intent but actual status is shown in the app header
        return "Check the focus timer in the app header for your current session status.\n\nTo start a session, say \"focus on [task name]\".\nTo end a session, say \"stop focus\"."
    }
}
