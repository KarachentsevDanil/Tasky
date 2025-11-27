//
//  PlanMyDayTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for data-driven day planning based on user's actual tasks
struct PlanMyDayTool: Tool {
    let name = "planMyDay"
    let description = "Analyze and organize today's tasks. Triggers: plan my day, organize today, what should I do, prioritize my day."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Available hours for tasks today. Default 8.")
        let availableHours: Int?

        @Guide(description: "Focus area filter")
        @Guide(.anyOf(["work", "personal", "all"]))
        let focus: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("planMyDay")
        let result = try await executePlan(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executePlan(arguments: Arguments) async throws -> String {
        let availableHours = arguments.availableHours ?? 8
        let availableMinutes = availableHours * 60

        // Fetch today's tasks + overdue tasks
        var allTasks: [TaskEntity] = []

        // Get today's tasks
        if let todayTasks = try? dataService.fetchTodayTasks() {
            allTasks.append(contentsOf: todayTasks.filter { !$0.isCompleted })
        }

        // Get overdue tasks
        if let overdueTasks = try? dataService.fetchOverdueTasks() {
            for task in overdueTasks {
                if !allTasks.contains(where: { $0.id == task.id }) {
                    allTasks.append(task)
                }
            }
        }

        // Filter by focus if specified
        if let focus = arguments.focus, focus != "all" {
            // Simple keyword-based filtering
            let focusKeywords: [String]
            switch focus.lowercased() {
            case "work":
                focusKeywords = ["work", "meeting", "call", "project", "report", "email", "office"]
            case "personal":
                focusKeywords = ["personal", "home", "family", "health", "gym", "shopping", "buy"]
            default:
                focusKeywords = []
            }

            if !focusKeywords.isEmpty {
                allTasks = allTasks.filter { task in
                    let title = task.title.lowercased()
                    let listName = task.taskList?.name.lowercased() ?? ""
                    return focusKeywords.contains { title.contains($0) || listName.contains($0) }
                }
            }
        }

        guard !allTasks.isEmpty else {
            return "No tasks for today! Enjoy your free time, or add some tasks to get started."
        }

        // Sort tasks by priority
        let sortedTasks = sortTasksForPlanning(allTasks)

        // Group into categories
        let mustDo = sortedTasks.filter { isHighPriority($0) || isOverdue($0) }
        let shouldDo = sortedTasks.filter { !isHighPriority($0) && !isOverdue($0) && !isQuickWin($0) }
        let quickWins = sortedTasks.filter { isQuickWin($0) && !isHighPriority($0) && !isOverdue($0) }

        // Calculate total time
        let totalMinutes = sortedTasks.reduce(0) { $0 + Int($1.estimatedDuration) }

        // Build output
        var output = "Today: \(sortedTasks.count) tasks"
        if totalMinutes > 0 {
            output += " (~\(AIToolHelpers.formatDuration(totalMinutes)) total)"
        }
        output += "\n"

        // Must Do section
        if !mustDo.isEmpty {
            output += "\nMust Do:\n"
            for (index, task) in mustDo.prefix(5).enumerated() {
                output += formatTaskLine(task, index: index + 1)
            }
        }

        // Should Do section
        if !shouldDo.isEmpty {
            output += "\nShould Do:\n"
            for (index, task) in shouldDo.prefix(5).enumerated() {
                output += formatTaskLine(task, index: mustDo.count + index + 1)
            }
        }

        // Quick Wins section
        if !quickWins.isEmpty {
            output += "\nQuick Wins:\n"
            for (index, task) in quickWins.prefix(3).enumerated() {
                output += formatTaskLine(task, index: mustDo.count + shouldDo.count + index + 1)
            }
        }

        // Summary
        if totalMinutes > 0 && availableMinutes > 0 {
            output += "\n"
            if totalMinutes > availableMinutes {
                let overflow = totalMinutes - availableMinutes
                output += "You have ~\(AIToolHelpers.formatDuration(totalMinutes)) of work for \(availableHours)h available. Consider rescheduling \(AIToolHelpers.formatDuration(overflow))."
            } else {
                output += "You have ~\(AIToolHelpers.formatDuration(totalMinutes)) of work for \(availableHours)h available."
            }
        }

        // Post notification
        NotificationCenter.default.post(
            name: .aiPlanMyDayCompleted,
            object: nil,
            userInfo: [
                "plan": output,
                "taskCount": sortedTasks.count,
                "totalMinutes": totalMinutes
            ]
        )

        HapticManager.shared.success()
        return output
    }

    // MARK: - Helpers

    private func sortTasksForPlanning(_ tasks: [TaskEntity]) -> [TaskEntity] {
        return tasks.sorted { task1, task2 in
            // 1. Scheduled time first (appointments)
            if let time1 = task1.scheduledTime, let time2 = task2.scheduledTime {
                return time1 < time2
            }
            if task1.scheduledTime != nil { return true }
            if task2.scheduledTime != nil { return false }

            // 2. Overdue tasks
            if isOverdue(task1) && !isOverdue(task2) { return true }
            if !isOverdue(task1) && isOverdue(task2) { return false }

            // 3. Priority
            if task1.priority != task2.priority {
                return task1.priority > task2.priority
            }

            // 4. AI priority score
            return task1.aiPriorityScore > task2.aiPriorityScore
        }
    }

    private func isHighPriority(_ task: TaskEntity) -> Bool {
        return task.priority >= 2
    }

    private func isOverdue(_ task: TaskEntity) -> Bool {
        guard let dueDate = task.dueDate else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    private func isQuickWin(_ task: TaskEntity) -> Bool {
        return task.estimatedDuration > 0 && task.estimatedDuration <= 15
    }

    @MainActor
    private func formatTaskLine(_ task: TaskEntity, index: Int) -> String {
        var line = "\(index). "

        // Add scheduled time if present
        if let time = task.scheduledTime {
            line += "\(AIToolHelpers.formatTime(time)) - "
        }

        // Task title
        line += task.title

        // Priority indicator
        if task.priority >= 2 {
            line += " [!]"
        }

        // Duration
        if task.estimatedDuration > 0 {
            line += " - \(AIToolHelpers.formatDuration(Int(task.estimatedDuration)))"
        }

        // Overdue indicator
        if isOverdue(task) {
            line += " - overdue"
        }

        line += "\n"
        return line
    }
}
