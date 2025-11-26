//
//  RescheduleTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for rescheduling one or more tasks to a new date
struct RescheduleTasksTool: Tool {
    let name = "rescheduleTasks"
    let description = "Reschedule tasks to new date. Triggers: move, postpone, reschedule, push to, delay, do on."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks")
        let filter: TaskFilter

        @Guide(description: "Target date for rescheduling")
        @Guide(.anyOf(["today", "tomorrow", "next_week", "next_month", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "specific_date"]))
        let targetDate: String

        @Guide(description: "ISO 8601 date if targetDate is specific_date")
        let specificDate: String?

        @Guide(description: "Optional time in HH:MM format")
        let time: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("rescheduleTasks")
        let result = try await executeReschedule(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeReschedule(arguments: Arguments) async throws -> String {
        // Parse target date
        guard let newDate = AIToolHelpers.calculateNewDate(arguments.targetDate, specificDate: arguments.specificDate) else {
            return "Could not understand the date '\(arguments.targetDate)'. Try: today, tomorrow, monday, or a specific date."
        }

        // Fetch tasks matching filter
        let tasks: [TaskEntity]
        do {
            tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
        } catch {
            return "Could not find tasks matching your criteria."
        }

        // Filter to only incomplete tasks
        let tasksToReschedule = tasks.filter { !$0.isCompleted }

        guard !tasksToReschedule.isEmpty else {
            if tasks.isEmpty {
                return "No tasks found matching your criteria."
            } else {
                return "All matching tasks are already completed."
            }
        }

        // Parse optional time
        var scheduledTime: Date?
        if let timeString = arguments.time {
            scheduledTime = AIToolHelpers.parseTime(timeString, onDate: newDate)
        }

        // Execute bulk reschedule
        do {
            let count = try dataService.rescheduleTasks(tasksToReschedule, to: newDate, time: scheduledTime)
            let taskTitles = tasksToReschedule.map { $0.title }
            let taskIds = tasksToReschedule.map { $0.id }

            // Post notification
            NotificationCenter.default.post(
                name: .aiBulkTasksRescheduled,
                object: nil,
                userInfo: [
                    "taskIds": taskIds,
                    "taskTitles": taskTitles,
                    "newDate": newDate,
                    "count": count
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            // Format response
            let dateStr = AIToolHelpers.formatRelativeDate(newDate)
            let timeStr = scheduledTime.map { " at \(AIToolHelpers.formatTime($0))" } ?? ""

            if count == 1 {
                return "✓ Rescheduled '\(taskTitles[0])' to \(dateStr)\(timeStr)"
            } else {
                let titles = taskTitles.prefix(3).joined(separator: ", ")
                let suffix = count > 3 ? " and \(count - 3) more" : ""
                return "✓ Rescheduled \(count) tasks to \(dateStr)\(timeStr): \(titles)\(suffix)"
            }
        } catch {
            HapticManager.shared.error()
            return "Failed to reschedule tasks. Please try again."
        }
    }
}
