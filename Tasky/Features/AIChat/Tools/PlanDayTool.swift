//
//  PlanDayTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when day plan is generated
extension Notification.Name {
    static let aiDayPlanGenerated = Notification.Name("aiDayPlanGenerated")
}

/// Tool for AI-driven daily planning that considers user context and calendar events
struct PlanDayTool: Tool {
    let name = "planDay"

    let description = "Create a daily plan based on tasks, user context, calendar events, and patterns. Triggers: plan my day, what should I do today, daily planning, schedule my day."

    let dataService: DataService
    let contextService: ContextService
    let calendarService: CalendarService

    init(
        dataService: DataService = DataService(),
        contextService: ContextService = .shared,
        calendarService: CalendarService = .shared
    ) {
        self.dataService = dataService
        self.contextService = contextService
        self.calendarService = calendarService
    }

    @Generable
    struct Arguments {
        @Guide(description: "The date to plan for")
        @Guide(.anyOf(["today", "tomorrow"]))
        let targetDate: String?

        @Guide(description: "Focus areas or priorities for the day (e.g., 'meetings', 'deep work', 'errands')")
        let focusAreas: [String]?

        @Guide(description: "Available hours for work (e.g., 8 for 8 hours)")
        let availableHours: Int?

        @Guide(description: "Include context from user's schedule constraints and preferences")
        let useContext: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("planDay")
        let result = try await executePlan(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executePlan(arguments: Arguments) async throws -> String {
        let calendar = Calendar.current
        let targetDate: Date

        // Determine target date
        switch arguments.targetDate?.lowercased() {
        case "tomorrow":
            targetDate = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        default:
            targetDate = calendar.startOfDay(for: Date())
        }

        let isToday = calendar.isDateInToday(targetDate)
        let dateLabel = isToday ? "today" : "tomorrow"

        // Fetch tasks for the target date
        let allTasks = (try? dataService.fetchAllTasks()) ?? []
        let incompleteTasks = allTasks.filter { !$0.isCompleted }

        // Get tasks due on target date or earlier (including overdue)
        let relevantTasks = incompleteTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate <= calendar.date(byAdding: .day, value: 1, to: targetDate)!
        }

        // Get tasks scheduled for target date
        let scheduledTasks = incompleteTasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            return calendar.isDate(scheduledTime, inSameDayAs: targetDate)
        }

        // Get unscheduled high-priority tasks
        let unscheduledHighPriority = incompleteTasks.filter { task in
            task.priority >= 2 && task.scheduledTime == nil
        }

        // Fetch user context if enabled
        var contextInfo = ""
        let useContext = arguments.useContext ?? true
        if useContext {
            do {
                let context = try contextService.fetchContextForIntent(.planDay)
                if !context.isEmpty {
                    contextInfo = contextService.formatContextForPrompt(context)
                }
            } catch {
                print("⚠️ Failed to fetch context for planning: \(error)")
            }
        }

        // Fetch calendar events for the target date
        var calendarEvents: [ExternalEvent] = []
        var calendarBlockedMinutes = 0

        if calendarService.permissionStatus.hasAccess {
            do {
                calendarEvents = try await calendarService.fetchEventsForDay(targetDate)
                // Calculate time blocked by calendar events (non-all-day events)
                for event in calendarEvents where !event.isAllDay {
                    calendarBlockedMinutes += event.durationMinutes
                }
            } catch {
                print("⚠️ Failed to fetch calendar events: \(error)")
            }
        }

        // Calculate available time
        let availableHours = arguments.availableHours ?? 8
        let totalMinutesAvailable = availableHours * 60

        // Calculate scheduled time already committed (tasks)
        var scheduledMinutes = 0
        for task in scheduledTasks {
            if let duration = task.scheduledEndTime?.timeIntervalSince(task.scheduledTime ?? Date()) {
                scheduledMinutes += Int(duration / 60)
            } else if task.estimatedDuration > 0 {
                scheduledMinutes += Int(task.estimatedDuration)
            } else {
                scheduledMinutes += 30 // Default 30 min
            }
        }

        // Total blocked = scheduled tasks + calendar events
        let totalBlockedMinutes = scheduledMinutes + calendarBlockedMinutes
        let freeMinutes = max(0, totalMinutesAvailable - totalBlockedMinutes)

        // Build the plan response
        var response = "📅 **Plan for \(dateLabel.capitalized)**\n\n"

        // Show calendar events (external commitments)
        if !calendarEvents.isEmpty {
            response += "📆 **Calendar:**\n"
            let sortedEvents = calendarEvents.sorted { $0.startDate < $1.startDate }
            for event in sortedEvents.prefix(5) {
                if event.isAllDay {
                    response += "• All day - \(event.title)\n"
                } else {
                    let timeStr = AIToolHelpers.formatTime(event.startDate)
                    let duration = event.durationMinutes < 60 ? "\(event.durationMinutes)m" : "\(event.durationMinutes / 60)h"
                    response += "• \(timeStr) (\(duration)) - \(event.title)\n"
                }
            }
            if sortedEvents.count > 5 {
                response += "• ...and \(sortedEvents.count - 5) more events\n"
            }
            response += "\n"
        }

        // Show scheduled time blocks (tasks)
        if !scheduledTasks.isEmpty {
            response += "🗓️ **Scheduled Tasks:**\n"
            let sortedScheduled = scheduledTasks.sorted { ($0.scheduledTime ?? Date()) < ($1.scheduledTime ?? Date()) }
            for task in sortedScheduled {
                if let time = task.scheduledTime {
                    let timeStr = AIToolHelpers.formatTime(time)
                    let priorityEmoji = AIToolHelpers.priorityEmoji(Int(task.priority))
                    response += "• \(timeStr) - \(task.title) \(priorityEmoji)\n"
                }
            }
            response += "\n"
        }

        // Show due tasks not yet scheduled
        let dueTodayUnscheduled = relevantTasks.filter { task in
            !scheduledTasks.contains(where: { $0.id == task.id })
        }

        if !dueTodayUnscheduled.isEmpty {
            response += "⚡ **Due \(dateLabel):**\n"
            let sorted = dueTodayUnscheduled.sorted { $0.priority > $1.priority }
            for task in sorted.prefix(5) {
                let priorityEmoji = AIToolHelpers.priorityEmoji(Int(task.priority))
                let duration = task.estimatedDuration > 0 ? " (~\(task.estimatedDuration)m)" : ""
                response += "• \(task.title)\(duration) \(priorityEmoji)\n"
            }
            if sorted.count > 5 {
                response += "• ...and \(sorted.count - 5) more\n"
            }
            response += "\n"
        }

        // Show high-priority unscheduled tasks
        let additionalHighPriority = unscheduledHighPriority.filter { task in
            !relevantTasks.contains(where: { $0.id == task.id })
        }

        if !additionalHighPriority.isEmpty {
            response += "🔴 **High Priority (consider adding):**\n"
            for task in additionalHighPriority.prefix(3) {
                let duration = task.estimatedDuration > 0 ? " (~\(task.estimatedDuration)m)" : ""
                response += "• \(task.title)\(duration)\n"
            }
            response += "\n"
        }

        // Time summary
        response += "⏱️ **Time:**\n"
        if calendarBlockedMinutes > 0 {
            response += "• Calendar: \(AIToolHelpers.formatDuration(calendarBlockedMinutes))\n"
        }
        response += "• Tasks: \(AIToolHelpers.formatDuration(scheduledMinutes))\n"
        response += "• Free: \(AIToolHelpers.formatDuration(freeMinutes))\n"

        // Add context-based suggestions if available
        if !contextInfo.isEmpty {
            response += "\n💡 **Based on what I know about you:**\n"
            let contextLines = contextInfo.components(separatedBy: "\n- ").prefix(3)
            for line in contextLines {
                let cleanLine = line.hasPrefix("- ") ? String(line.dropFirst(2)) : line
                if !cleanLine.isEmpty {
                    response += "• \(cleanLine)\n"
                }
            }
        }

        // Post notification for UI
        NotificationCenter.default.post(
            name: .aiDayPlanGenerated,
            object: nil,
            userInfo: [
                "date": targetDate,
                "scheduledCount": scheduledTasks.count,
                "dueCount": dueTodayUnscheduled.count,
                "freeMinutes": freeMinutes
            ]
        )

        HapticManager.shared.success()

        return response
    }
}
