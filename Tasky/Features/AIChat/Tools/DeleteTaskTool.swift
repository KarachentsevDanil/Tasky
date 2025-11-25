//
//  DeleteTaskTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for deleting tasks via LLM with undo support
/// Optimized for local LLM with explicit trigger clarification
struct DeleteTaskTool: Tool {
    let name = "deleteTask"

    let description = "Delete task permanently. Triggers: delete, remove, cancel task, get rid of. NOT for done/finished."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Simple arguments - task title only
    @Generable
    struct Arguments {
        @Guide(description: "Task title to delete. Use exact words from user.")
        let taskTitle: String
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("deleteTask")
        let result = await executeDelete(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeDelete(arguments: Arguments) async -> String {
        // Find the task
        guard let task = AIToolHelpers.findTask(arguments.taskTitle, dataService: dataService) else {
            let suggestion = AIToolHelpers.findSimilarTasks(arguments.taskTitle, dataService: dataService)
            if suggestion.isEmpty {
                return "Could not find a task matching '\(arguments.taskTitle)'."
            } else {
                return "Could not find '\(arguments.taskTitle)'. Did you mean:\n\(suggestion)"
            }
        }

        let taskTitle = task.title
        let taskId = task.id

        // Store complete task info for undo restoration
        let deletedTaskInfo = DeletedTaskInfo(
            id: taskId,
            title: taskTitle,
            notes: task.notes,
            dueDate: task.dueDate,
            scheduledTime: task.scheduledTime,
            scheduledEndTime: task.scheduledEndTime,
            priority: Int(task.priority),
            listId: task.taskList?.id,
            listName: task.taskList?.name,
            isRecurring: task.isRecurring,
            recurrenceDays: task.recurrenceDays,
            estimatedDuration: Int(task.estimatedDuration)
        )

        // Perform deletion
        do {
            try dataService.deleteTask(task)

            // Post notification for undo UI (5-second window)
            NotificationCenter.default.post(
                name: .aiTaskDeleted,
                object: nil,
                userInfo: [
                    "deletedTaskInfo": deletedTaskInfo,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.lightImpact()

            return "Deleted '\(taskTitle)'"

        } catch {
            HapticManager.shared.error()
            return "Failed to delete task: \(error.localizedDescription)"
        }
    }
}
