//
//  TaskAnalyticsTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for providing rich task analytics and productivity insights
/// Optimized for local LLM with explicit analytics type options
struct TaskAnalyticsTool: Tool {
    let name = "taskAnalytics"

    let description = "Show productivity stats and analytics. Triggers: how am I doing, progress, stats, summary, streak, productivity."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with explicit analytics types
    @Generable
    struct Arguments {
        @Guide(description: "Type of analytics to retrieve")
        @Guide(.anyOf(["daily_summary", "weekly_summary", "monthly_summary", "completion_rate", "overdue_count", "list_breakdown", "productivity_streak", "best_time", "focus_stats", "weekly_comparison"]))
        let analyticsType: String

        @Guide(description: "Optional list name to filter by. Leave empty for all tasks.")
        let listName: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("taskAnalytics")
        let result = await executeAnalytics(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAnalytics(arguments: Arguments) async -> String {
        switch arguments.analyticsType.lowercased() {
        case "daily_summary":
            return getDailySummary(listName: arguments.listName)
        case "weekly_summary":
            return getWeeklySummary(listName: arguments.listName)
        case "monthly_summary":
            return getMonthlySummary(listName: arguments.listName)
        case "completion_rate":
            return getCompletionRate(listName: arguments.listName)
        case "overdue_count":
            return getOverdueCount(listName: arguments.listName)
        case "list_breakdown":
            return getListBreakdown()
        case "productivity_streak":
            return getProductivityStreak()
        case "best_time":
            return getBestProductiveTime()
        case "focus_stats":
            return getFocusStats(listName: arguments.listName)
        case "weekly_comparison":
            return getWeeklyComparison()
        default:
            return "Unknown analytics type. Use: daily_summary, weekly_summary, monthly_summary, completion_rate, overdue_count, list_breakdown, productivity_streak, best_time, focus_stats, weekly_comparison"
        }
    }

    // MARK: - Daily Summary

    @MainActor
    private func getDailySummary(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedToday = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= today && completedAt < tomorrow
        }.count

        let dueToday = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate >= today && dueDate < tomorrow
        }.count

        let overdue = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < today
        }.count

        let totalIncomplete = tasks.filter { !$0.isCompleted }.count

        // Calculate completion percentage
        let totalDueToday = dueToday + completedToday
        let todayRate = totalDueToday > 0 ? Int((Double(completedToday) / Double(totalDueToday)) * 100) : 0

        var summary = "Today's Summary\n"
        summary += "Completed: \(completedToday)"
        if totalDueToday > 0 {
            summary += " (\(todayRate)% of today's tasks)"
        }
        summary += "\nStill due today: \(dueToday)\n"
        summary += "Overdue: \(overdue)\n"
        summary += "Total remaining: \(totalIncomplete)"

        // Add motivational feedback
        if completedToday >= 5 {
            summary += "\n\nGreat momentum! \(completedToday) tasks done today!"
        } else if completedToday > 0 && dueToday == 0 && overdue == 0 {
            summary += "\n\nAll caught up! Nice work!"
        } else if overdue > 3 {
            summary += "\n\nYou have \(overdue) overdue tasks. Consider tackling the oldest ones first."
        }

        return summary
    }

    // MARK: - Weekly Summary

    @MainActor
    private func getWeeklySummary(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedThisWeek = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }

        let completedCount = completedThisWeek.count

        // Find busiest day
        var dayCount: [Int: Int] = [:]
        for task in completedThisWeek {
            if let completedAt = task.completedAt {
                let weekday = calendar.component(.weekday, from: completedAt)
                dayCount[weekday, default: 0] += 1
            }
        }

        let busiestDay = dayCount.max(by: { $0.value < $1.value })
        let dayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let busiestDayName = busiestDay.map { dayNames[$0.key] } ?? "None"

        let avgPerDay = Double(completedCount) / 7.0

        var summary = "This Week's Summary\n"
        summary += "Tasks completed: \(completedCount)\n"
        summary += "Most productive day: \(busiestDayName)"
        if let busiest = busiestDay {
            summary += " (\(busiest.value) tasks)"
        }
        summary += "\nDaily average: \(String(format: "%.1f", avgPerDay)) tasks"

        if completedCount >= 25 {
            summary += "\n\nOutstanding week! 25+ tasks completed!"
        } else if completedCount >= 15 {
            summary += "\n\nExcellent week! Keep it up!"
        }

        return summary
    }

    // MARK: - Monthly Summary

    @MainActor
    private func getMonthlySummary(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: today)!

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let completedThisMonth = tasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= monthAgo
        }

        let completedCount = completedThisMonth.count

        var summary = "Monthly Summary (Last 30 Days)\n"
        summary += "Total completed: \(completedCount)\n"
        summary += "Weekly average: \(String(format: "%.1f", Double(completedCount) / 4.0)) tasks\n"
        summary += "Daily average: \(String(format: "%.1f", Double(completedCount) / 30.0)) tasks"

        return summary
    }

    // MARK: - Completion Rate

    @MainActor
    private func getCompletionRate(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        var tasks = allTasks
        var listInfo = ""
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
            listInfo = " for '\(listName)'"
        }

        let total = tasks.count
        let completed = tasks.filter { $0.isCompleted }.count

        guard total > 0 else {
            return "No tasks found\(listInfo). Create some tasks to see your completion rate!"
        }

        let rate = Double(completed) / Double(total) * 100

        var message = ""
        if rate >= 90 {
            message = "Outstanding!"
        } else if rate >= 75 {
            message = "Excellent progress!"
        } else if rate >= 50 {
            message = "Good momentum!"
        } else if rate >= 25 {
            message = "Building up!"
        } else {
            message = "Room to grow!"
        }

        var response = "Completion Rate\(listInfo)\n"
        response += "\(completed) of \(total) tasks completed\n"
        response += "Rate: \(String(format: "%.0f", rate))%\n"
        response += message

        return response
    }

    // MARK: - Overdue Count

    @MainActor
    private func getOverdueCount(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let today = Calendar.current.startOfDay(for: Date())

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        let overdue = tasks.filter { task in
            guard let dueDate = task.dueDate, !task.isCompleted else { return false }
            return dueDate < today
        }.sorted { ($0.dueDate ?? .distantPast) < ($1.dueDate ?? .distantPast) }

        if overdue.isEmpty {
            return "No overdue tasks! You're on track."
        }

        // Categorize by age
        let critical = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days >= 7
        }.count
        let warning = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days >= 3 && days < 7
        }.count
        let recent = overdue.filter { task in
            let days = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            return days < 3
        }.count

        var response = "\(overdue.count) Overdue Task(s)\n\n"

        if critical > 0 {
            response += "Critical (7+ days): \(critical)\n"
        }
        if warning > 0 {
            response += "Warning (3-6 days): \(warning)\n"
        }
        if recent > 0 {
            response += "Recent (1-2 days): \(recent)\n"
        }

        response += "\nTop tasks to address:\n"
        for (index, task) in overdue.prefix(5).enumerated() {
            let daysOverdue = Calendar.current.dateComponents([.day], from: task.dueDate ?? Date(), to: today).day ?? 0
            response += "\(index + 1). \(task.title) (\(daysOverdue)d overdue)\n"
        }

        if overdue.count > 5 {
            response += "... and \(overdue.count - 5) more"
        }

        return response
    }

    // MARK: - List Breakdown

    @MainActor
    private func getListBreakdown() -> String {
        guard let allTasks = try? dataService.fetchAllTasks(),
              let lists = try? dataService.fetchAllTaskLists() else {
            return "Could not fetch data."
        }

        var response = "Tasks by List\n\n"

        // Inbox count
        let inboxTasks = allTasks.filter { $0.taskList == nil }
        let inboxIncomplete = inboxTasks.filter { !$0.isCompleted }.count
        let inboxTotal = inboxTasks.count
        let inboxRate = inboxTotal > 0 ? Int(Double(inboxTotal - inboxIncomplete) / Double(inboxTotal) * 100) : 0
        response += "Inbox: \(inboxIncomplete) active (\(inboxRate)% complete)\n"

        // Each list
        for list in lists {
            let listTasks = allTasks.filter { $0.taskList?.id == list.id }
            let incomplete = listTasks.filter { !$0.isCompleted }.count
            let total = listTasks.count
            let rate = total > 0 ? Int(Double(total - incomplete) / Double(total) * 100) : 0

            response += "\(list.name): \(incomplete) active (\(rate)% complete)\n"
        }

        let totalIncomplete = allTasks.filter { !$0.isCompleted }.count
        let totalComplete = allTasks.filter { $0.isCompleted }.count
        response += "\nTotal: \(totalIncomplete) active, \(totalComplete) completed"

        return response
    }

    // MARK: - Productivity Streak

    @MainActor
    private func getProductivityStreak() -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        var currentStreak = 0
        var longestStreak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check backwards from today for current streak
        while true {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!

            let hasCompletion = allTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= checkDate && completedAt < nextDay
            }

            if hasCompletion {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                break
            }
        }

        // Calculate longest streak (last 90 days)
        let ninetyDaysAgo = calendar.date(byAdding: .day, value: -90, to: Date())!
        var tempStreak = 0
        checkDate = ninetyDaysAgo

        while checkDate <= Date() {
            let nextDay = calendar.date(byAdding: .day, value: 1, to: checkDate)!

            let hasCompletion = allTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= checkDate && completedAt < nextDay
            }

            if hasCompletion {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 0
            }

            checkDate = calendar.date(byAdding: .day, value: 1, to: checkDate)!
        }

        var badge = ""
        if currentStreak >= 30 {
            badge = "Legendary!"
        } else if currentStreak >= 14 {
            badge = "Amazing!"
        } else if currentStreak >= 7 {
            badge = "Great streak!"
        } else if currentStreak >= 3 {
            badge = "Building momentum!"
        }

        var response = "Productivity Streak\n\n"

        if currentStreak == 0 {
            response += "No active streak.\n"
            response += "Complete a task today to start!"
        } else {
            response += "Current: \(currentStreak) day(s) \(badge)\n"
        }

        response += "\nLongest (90 days): \(longestStreak) day(s)"

        if currentStreak > 0 {
            response += "\n\nKeep it going! Don't break the chain!"
        }

        return response
    }

    // MARK: - Best Productive Time

    @MainActor
    private func getBestProductiveTime() -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date())!

        // Group completions by hour
        var hourCounts: [Int: Int] = [:]
        for task in allTasks {
            guard let completedAt = task.completedAt, completedAt >= thirtyDaysAgo else { continue }
            let hour = calendar.component(.hour, from: completedAt)
            hourCounts[hour, default: 0] += 1
        }

        guard !hourCounts.isEmpty else {
            return "Not enough data yet. Complete more tasks to see your productivity patterns!"
        }

        // Group into time periods
        let morning = (5..<12).reduce(0) { $0 + (hourCounts[$1] ?? 0) }
        let afternoon = (12..<17).reduce(0) { $0 + (hourCounts[$1] ?? 0) }
        let evening = (17..<22).reduce(0) { $0 + (hourCounts[$1] ?? 0) }
        let night = (0..<5).reduce(0) { $0 + (hourCounts[$1] ?? 0) } + (22..<24).reduce(0) { $0 + (hourCounts[$1] ?? 0) }

        // Find peak hour
        let peakHour = hourCounts.max(by: { $0.value < $1.value })

        // Determine best period
        let periods = [
            ("Morning (5am-12pm)", morning),
            ("Afternoon (12pm-5pm)", afternoon),
            ("Evening (5pm-10pm)", evening),
            ("Night (10pm-5am)", night)
        ]
        let bestPeriod = periods.max(by: { $0.1 < $1.1 })!

        var response = "Your Productivity Patterns (Last 30 days)\n\n"

        for (name, count) in periods {
            response += "\(name): \(count) tasks\n"
        }

        response += "\nPeak time: "
        if let peak = peakHour {
            let hourString = peak.key < 12 ? "\(peak.key)am" : (peak.key == 12 ? "12pm" : "\(peak.key - 12)pm")
            response += "\(hourString) (\(peak.value) tasks)"
        }

        response += "\nBest period: \(bestPeriod.0.components(separatedBy: " ")[0])"

        return response
    }

    // MARK: - Focus Stats

    @MainActor
    private func getFocusStats(listName: String?) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        var tasks = allTasks
        if let listName = listName, let list = AIToolHelpers.findList(listName, dataService: dataService) {
            tasks = tasks.filter { $0.taskList?.id == list.id }
        }

        // Calculate total focus time from tasks
        let totalFocusSeconds = tasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }
        let totalFocusMinutes = totalFocusSeconds / 60
        let totalFocusHours = totalFocusMinutes / 60

        // Count tasks with focus time
        let tasksWithFocus = tasks.filter { $0.focusTimeSeconds > 0 }.count

        var response = "Focus Statistics\n\n"

        if totalFocusSeconds == 0 {
            response += "No focus time recorded yet.\n"
            response += "Start a focus session to track your deep work!\n"
            response += "\nTry: \"Start 25-minute focus on [task]\""
            return response
        }

        response += "Total focus time: "
        if totalFocusHours > 0 {
            response += "\(totalFocusHours)h \(totalFocusMinutes % 60)m\n"
        } else {
            response += "\(totalFocusMinutes)m\n"
        }

        response += "Tasks with focus time: \(tasksWithFocus)\n"

        if tasksWithFocus > 0 {
            let avgFocusPerTask = totalFocusMinutes / tasksWithFocus
            response += "Average per task: \(avgFocusPerTask)m"
        }

        if totalFocusMinutes >= 120 {
            response += "\n\nGreat deep work! Keep up the focused effort!"
        }

        return response
    }

    // MARK: - Weekly Comparison

    @MainActor
    private func getWeeklyComparison() -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else {
            return "Could not fetch tasks."
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!

        // This week's completions
        let thisWeek = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }.count

        // Last week's completions
        let lastWeek = allTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= twoWeeksAgo && completedAt < weekAgo
        }.count

        var response = "Weekly Comparison\n\n"
        response += "This week: \(thisWeek) tasks\n"
        response += "Last week: \(lastWeek) tasks\n\n"

        if lastWeek == 0 {
            if thisWeek > 0 {
                response += "Great start this week!"
            } else {
                response += "Time to get started!"
            }
        } else {
            let change = thisWeek - lastWeek
            let percentChange = Int((Double(change) / Double(lastWeek)) * 100)

            if change > 0 {
                response += "Up \(change) tasks (+\(percentChange)%)\n"
                response += "Great improvement!"
            } else if change < 0 {
                response += "Down \(abs(change)) tasks (\(percentChange)%)\n"
                response += "Let's pick up the pace!"
            } else {
                response += "Same as last week\n"
                response += "Push for more this week!"
            }
        }

        return response
    }
}
