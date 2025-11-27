//
//  UpdateTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for updating properties (priority, list) on one or more tasks
struct UpdateTasksTool: Tool {
    let name = "updateTasks"
    let description = "Update task properties. Triggers: set priority, make urgent, move to list, change priority."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks")
        let filter: TaskFilter

        @Guide(description: "New priority level")
        @Guide(.anyOf(["high", "medium", "low", "none"]))
        let newPriority: String?

        @Guide(description: "Move tasks to this list name")
        let newListName: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("updateTasks")
        let result = try await executeUpdate(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeUpdate(arguments: Arguments) async throws -> String {
        // Validate at least one update is specified
        guard arguments.newPriority != nil || arguments.newListName != nil else {
            return "Please specify what to update: newPriority (high/medium/low/none) or newListName."
        }

        // Fetch tasks matching filter
        let tasks: [TaskEntity]
        do {
            tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
        } catch {
            return "Could not find tasks matching your criteria."
        }

        // Filter to only incomplete tasks
        let tasksToUpdate = tasks.filter { !$0.isCompleted }

        guard !tasksToUpdate.isEmpty else {
            if tasks.isEmpty {
                return "No tasks found matching your criteria."
            } else {
                return "All matching tasks are completed. Cannot update completed tasks."
            }
        }

        var changes: [String] = []
        var updatedCount = 0

        // Update priority if specified
        if let priorityStr = arguments.newPriority {
            let priority: Int16
            switch priorityStr.lowercased() {
            case "high": priority = 2
            case "medium": priority = 1
            case "low": priority = 0
            case "none": priority = 0
            default: priority = 1
            }

            do {
                updatedCount = try dataService.updateTasksPriority(tasksToUpdate, priority: priority)
                changes.append("priority → \(priorityStr)")
            } catch {
                return "Failed to update priority. Please try again."
            }
        }

        // Update list if specified
        if let listName = arguments.newListName {
            let targetList = AIToolHelpers.findList(listName, dataService: dataService)

            // If list not found, treat as removing from list (move to Inbox)
            do {
                updatedCount = try dataService.moveTasksToList(tasksToUpdate, list: targetList)
                if let list = targetList {
                    changes.append("list → \(list.name)")
                } else {
                    changes.append("list → Inbox")
                }
            } catch {
                return "Failed to move tasks. Please try again."
            }
        }

        let taskTitles = tasksToUpdate.map { $0.title }
        let taskIds = tasksToUpdate.map { $0.id }
        let changesStr = changes.joined(separator: ", ")

        // Post notification
        NotificationCenter.default.post(
            name: .aiBulkTasksUpdated,
            object: nil,
            userInfo: [
                "taskIds": taskIds,
                "taskTitles": taskTitles,
                "changes": changesStr,
                "count": updatedCount
            ]
        )

        // Haptic feedback
        HapticManager.shared.success()

        // Format response
        if updatedCount == 1 {
            return "✓ Updated '\(taskTitles[0])': \(changesStr)"
        } else {
            let titles = taskTitles.prefix(3).joined(separator: ", ")
            let suffix = updatedCount > 3 ? " and \(updatedCount - 3) more" : ""
            return "✓ Updated \(updatedCount) tasks (\(changesStr)): \(titles)\(suffix)"
        }
    }
}
