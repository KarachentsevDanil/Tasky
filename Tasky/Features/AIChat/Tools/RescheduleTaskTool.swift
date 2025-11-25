//
//  RescheduleTaskTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for rescheduling tasks with natural date expressions
/// Optimized for local LLM with explicit shortcuts
struct RescheduleTaskTool: Tool {
    let name = "rescheduleTask"

    let description = "Reschedule task to new date. Triggers: move to, postpone, reschedule, push to, do on."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with explicit shortcuts documented
    @Generable
    struct Arguments {
        @Guide(description: "Task title to reschedule. Use exact words from user.")
        let taskTitle: String

        @Guide(description: "When to reschedule the task")
        @Guide(.anyOf(["today", "tomorrow", "next_week", "next_month", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "specific_date"]))
        let when: String

        @Guide(description: "ISO 8601 date YYYY-MM-DDTHH:MM:SSZ. Only needed if when=specific_date")
        let specificDate: String?

        @Guide(description: "Time in HH:MM format like 14:30. Optional for scheduling specific time.")
        let time: String?

        @Guide(description: "Duration in minutes for time block. Optional. Common: 15, 30, 45, 60")
        let durationMinutes: Int?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeReschedule(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeReschedule(arguments: Arguments) async -> String {
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
        let previousDueDate = task.dueDate
        let previousScheduledTime = task.scheduledTime
        let previousScheduledEndTime = task.scheduledEndTime
        let taskTitle = task.title

        // Calculate new date
        guard let newDate = AIToolHelpers.calculateNewDate(arguments.when, specificDate: arguments.specificDate) else {
            return "Invalid date. Use: today, tomorrow, next_week, next_month, weekday names, or specific_date with ISO 8601 format."
        }

        // Parse optional time
        var scheduledTime: Date?
        var scheduledEndTime: Date?

        if let timeString = arguments.time {
            if let time = AIToolHelpers.parseTime(timeString, onDate: newDate) {
                scheduledTime = time

                // Calculate end time if duration provided
                if let duration = arguments.durationMinutes, duration > 0 {
                    scheduledEndTime = Calendar.current.date(byAdding: .minute, value: duration, to: time)
                }
            }
        }

        // Perform update
        do {
            try dataService.updateTask(
                task,
                title: task.title,
                notes: task.notes,
                dueDate: newDate,
                scheduledTime: scheduledTime,
                scheduledEndTime: scheduledEndTime,
                priority: task.priority,
                priorityOrder: task.priorityOrder,
                list: task.taskList
            )

            // Build response
            var response = "Rescheduled '\(taskTitle)' to \(AIToolHelpers.formatRelativeDate(newDate))"

            if let time = scheduledTime {
                response += " at \(AIToolHelpers.formatTime(time))"

                if let endTime = scheduledEndTime {
                    response += " - \(AIToolHelpers.formatTime(endTime))"
                }
            }

            // Post notification with undo support
            NotificationCenter.default.post(
                name: .aiTaskRescheduled,
                object: nil,
                userInfo: [
                    "taskId": task.id as Any,
                    "taskTitle": taskTitle,
                    "newDate": newDate,
                    "previousDueDate": previousDueDate as Any,
                    "previousScheduledTime": previousScheduledTime as Any,
                    "previousScheduledEndTime": previousScheduledEndTime as Any,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            return response

        } catch {
            HapticManager.shared.error()
            return "Failed to reschedule: \(error.localizedDescription)"
        }
    }
}
