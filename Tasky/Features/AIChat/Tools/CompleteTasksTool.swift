//
//  CompleteTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for completing one or more tasks via filter or explicit names
struct CompleteTasksTool: Tool {
    let name = "completeTasks"
    let description = "Mark tasks as done. Triggers: done, finished, complete, check off, mark done, all done."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks. Can use list, status, keyword, or explicit taskNames.")
        let filter: TaskFilter

        @Guide(description: "true = mark complete, false = reopen/uncomplete. Default true.")
        let completed: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("completeTasks")
        let result = try await executeComplete(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeComplete(arguments: Arguments) async throws -> String {
        let completed = arguments.completed ?? true

        // Fetch tasks matching filter
        let tasks: [TaskEntity]
        do {
            tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
        } catch {
            return "Could not find tasks matching your criteria."
        }

        // Filter to only tasks that need state change
        let tasksToChange = tasks.filter { $0.isCompleted != completed }

        guard !tasksToChange.isEmpty else {
            if tasks.isEmpty {
                return "No tasks found matching your criteria."
            } else {
                let action = completed ? "already complete" : "already incomplete"
                return tasks.count == 1
                    ? "'\(tasks[0].title)' is \(action)."
                    : "All \(tasks.count) matching tasks are \(action)."
            }
        }

        // Execute bulk complete
        do {
            let count = try dataService.completeTasks(tasksToChange, completed: completed)
            let taskTitles = tasksToChange.map { $0.title }
            let taskIds = tasksToChange.map { $0.id }

            // Post notification
            NotificationCenter.default.post(
                name: .aiBulkTasksCompleted,
                object: nil,
                userInfo: [
                    "taskIds": taskIds,
                    "taskTitles": taskTitles,
                    "completed": completed,
                    "count": count
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            // Format response
            let action = completed ? "Completed" : "Reopened"
            if count == 1 {
                return "✓ \(action) '\(taskTitles[0])'"
            } else {
                let titles = taskTitles.prefix(3).joined(separator: ", ")
                let suffix = count > 3 ? " and \(count - 3) more" : ""
                return "✓ \(action) \(count) tasks: \(titles)\(suffix)"
            }
        } catch {
            HapticManager.shared.error()
            return "Failed to complete tasks. Please try again."
        }
    }
}
