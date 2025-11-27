//
//  DeleteTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for deleting one or more tasks with confirmation for bulk operations
struct DeleteTasksTool: Tool {
    let name = "deleteTasks"
    let description = "Delete tasks permanently. Triggers: delete, remove, cancel task. NOT for done/complete."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks for deletion")
        let filter: TaskFilter

        @Guide(description: "Set to true to confirm deletion of 3+ tasks. Required for bulk delete.")
        let confirmed: Bool?

        @Guide(description: "Set to true to delete ALL tasks matching the filter. Use with extreme caution.")
        let deleteAll: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("deleteTasks")
        let result = try await executeDelete(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeDelete(arguments: Arguments) async throws -> String {
        let deleteAll = arguments.deleteAll ?? false
        let confirmed = arguments.confirmed ?? false

        // If deleteAll is requested, require explicit confirmation
        if deleteAll && !confirmed {
            let allTasks = try? dataService.fetchAllTasks()
            let count = allTasks?.count ?? 0
            return "⚠️ This will permanently delete ALL \(count) tasks. This action cannot be undone.\n\nSay \"delete all tasks, confirm\" to proceed."
        }

        // Fetch tasks matching filter
        let tasks: [TaskEntity]
        do {
            if deleteAll {
                tasks = (try? dataService.fetchAllTasks()) ?? []
            } else {
                tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
            }
        } catch {
            return "Could not find tasks matching your criteria."
        }

        guard !tasks.isEmpty else {
            return "No tasks found matching your criteria."
        }

        let taskTitles = tasks.map { $0.title }

        // Require confirmation for bulk deletes (3+ tasks)
        if tasks.count >= 3 && !confirmed {
            let preview = taskTitles.prefix(5).map { "• \($0)" }.joined(separator: "\n")
            let suffix = tasks.count > 5 ? "\n• ...and \(tasks.count - 5) more" : ""
            return "This will delete \(tasks.count) tasks:\n\(preview)\(suffix)\n\nSay \"confirm delete\" to proceed."
        }

        // Execute deletion
        do {
            let count = try dataService.deleteTasks(tasks)

            // Post notification
            NotificationCenter.default.post(
                name: .aiBulkTasksDeleted,
                object: nil,
                userInfo: [
                    "taskTitles": taskTitles,
                    "count": count
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            // Format response
            if count == 1 {
                return "✓ Deleted '\(taskTitles[0])'"
            } else {
                let titles = taskTitles.prefix(3).joined(separator: ", ")
                let suffix = count > 3 ? " and \(count - 3) more" : ""
                return "✓ Deleted \(count) tasks: \(titles)\(suffix)"
            }
        } catch {
            HapticManager.shared.error()
            return "Failed to delete tasks. Please try again."
        }
    }
}
