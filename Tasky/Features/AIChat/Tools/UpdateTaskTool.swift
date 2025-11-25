//
//  UpdateTaskTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for updating existing task properties via LLM
/// Optimized for local LLM with explicit parameter guidance
struct UpdateTaskTool: Tool {
    let name = "updateTask"

    let description = "Update task properties. Triggers: rename, change, set priority, add notes, move to list, make urgent."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with explicit @Guide descriptions for local LLM
    @Generable
    struct Arguments {
        @Guide(description: "Current task title to find. Use exact words from user.")
        let taskTitle: String

        @Guide(description: "New title for the task. Only set if user wants to rename.")
        let newTitle: String?

        @Guide(description: "New notes or description. Only set if user mentions notes.")
        let newNotes: String?

        @Guide(description: "New priority: 0=none, 1=low, 2=medium, 3=high. Only set if user mentions priority/importance/urgent.")
        let newPriority: Int?

        @Guide(description: "List name to move task to. Only set if user mentions moving to a list.")
        let newListName: String?

        @Guide(description: "New due date in ISO 8601: YYYY-MM-DDTHH:MM:SSZ. Only set if user mentions new date.")
        let newDueDate: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("updateTask")
        let result = await executeUpdate(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeUpdate(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(arguments.taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "Could not find a task matching '\(arguments.taskTitle)'."
            } else {
                return "Could not find '\(arguments.taskTitle)'. Did you mean:\n\(suggestion)"
            }
        }

        // Store previous state for undo
        let previousState = TaskPreviousState(
            title: task.title,
            notes: task.notes,
            dueDate: task.dueDate,
            scheduledTime: task.scheduledTime,
            scheduledEndTime: task.scheduledEndTime,
            priority: task.priority,
            listId: task.taskList?.id
        )

        // Track changes for response
        var changes: [String] = []
        let originalTitle = task.title

        // Find list if specified
        var targetList: TaskListEntity? = task.taskList
        if let listName = arguments.newListName {
            if let matchedList = AIToolHelpers.findList(listName, dataService: dataService) {
                targetList = matchedList
                changes.append("moved to '\(matchedList.name)'")
            } else {
                return "List '\(listName)' not found. Available: \(AIToolHelpers.getAvailableListNames(dataService: dataService))"
            }
        }

        // Parse due date if provided
        var newDueDate: Date? = task.dueDate
        if let dueDateString = arguments.newDueDate {
            if let parsed = AIToolHelpers.parseISO8601Date(dueDateString) {
                newDueDate = parsed
                changes.append("due \(AIToolHelpers.formatRelativeDate(parsed))")
            } else {
                return "Invalid date format. Use ISO 8601: YYYY-MM-DDTHH:MM:SSZ"
            }
        }

        // Validate priority
        var newPriority = task.priority
        if let priority = arguments.newPriority {
            let clampedPriority = Int16(min(max(priority, 0), 3))
            newPriority = clampedPriority
            changes.append("priority: \(AIToolHelpers.priorityName(Int(clampedPriority)))")
        }

        // Track title change
        var finalTitle = task.title
        if let newTitle = arguments.newTitle, !newTitle.isEmpty {
            finalTitle = newTitle
            changes.append("renamed to '\(newTitle)'")
        }

        // Track notes change
        var finalNotes = task.notes
        if let newNotes = arguments.newNotes {
            finalNotes = newNotes
            changes.append("notes updated")
        }

        // Check if anything changed
        if changes.isEmpty {
            return "No changes specified for '\(originalTitle)'."
        }

        // Perform update
        do {
            try dataService.updateTask(
                task,
                title: finalTitle,
                notes: finalNotes,
                dueDate: newDueDate,
                scheduledTime: task.scheduledTime,
                scheduledEndTime: task.scheduledEndTime,
                priority: newPriority,
                priorityOrder: task.priorityOrder,
                list: targetList
            )

            // Post notification for UI feedback with undo support
            NotificationCenter.default.post(
                name: .aiTaskUpdated,
                object: nil,
                userInfo: [
                    "taskId": task.id as Any,
                    "taskTitle": originalTitle,
                    "changes": changes,
                    "previousState": previousState,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            let changeList = changes.joined(separator: ", ")
            return "Updated '\(originalTitle)': \(changeList)"

        } catch {
            HapticManager.shared.error()
            return "Failed to update task: \(error.localizedDescription)"
        }
    }
}
