//
//  WeeklyReviewTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for weekly productivity review with actionable suggestions
struct WeeklyReviewTool: Tool {
    let name = "weeklyReview"
    let description = "Weekly productivity summary. Triggers: weekly review, how was my week, summary, progress, how am I doing."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Include actionable suggestions. Default true.")
        let includeSuggestions: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("weeklyReview")
        let result = try await executeReview(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeReview(arguments: Arguments) async throws -> String {
        let includeSuggestions = arguments.includeSuggestions ?? true
        let calendar = Calendar.current

        // Calculate week boundaries
        let now = Date()
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        // Fetch data
        let completedThisWeek = (try? dataService.fetchTasksCompletedBetween(start: weekStart, end: weekEnd)) ?? []
        let createdThisWeek = (try? dataService.fetchTasksCreatedBetween(start: weekStart, end: weekEnd)) ?? []
        let overdueTasks = (try? dataService.fetchOverdueTasks()) ?? []
        let highPriorityPending = (try? dataService.fetchHighPriorityPendingTasks()) ?? []
        let allLists = (try? dataService.fetchAllTaskLists()) ?? []

        let completedCount = completedThisWeek.count
        let createdCount = createdThisWeek.count
        let overdueCount = overdueTasks.count
        let highPriorityCount = highPriorityPending.count

        // Calculate completion rate
        let totalTasks = max(completedCount + overdueCount, 1)
        let completionRate = Int(Double(completedCount) / Double(totalTasks) * 100)

        // Calculate daily pattern
        var completionsByDay: [Int: Int] = [:]
        for task in completedThisWeek {
            if let completedAt = task.completedAt {
                let weekday = calendar.component(.weekday, from: completedAt)
                completionsByDay[weekday, default: 0] += 1
            }
        }
        let bestDay = completionsByDay.max { $0.value < $1.value }
        let bestDayName = bestDay.map { dayName(for: $0.key) }
        let bestDayCount = bestDay?.value ?? 0

        // Calculate list breakdown
        var listCompletions: [(String, Int)] = []
        for list in allLists {
            let completedInList = completedThisWeek.filter { $0.taskList?.id == list.id }.count
            if completedInList > 0 {
                listCompletions.append((list.name, completedInList))
            }
        }
        let inboxCompleted = completedThisWeek.filter { $0.taskList == nil }.count
        if inboxCompleted > 0 {
            listCompletions.append(("Inbox", inboxCompleted))
        }
        listCompletions.sort { $0.1 > $1.1 }

        // Calculate streak (consecutive days with completions)
        let streak = calculateStreak(completedTasks: completedThisWeek)

        // Format date range
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d"
        let weekRangeStr = "\(dateFormatter.string(from: weekStart))-\(dateFormatter.string(from: weekEnd))"

        // Build output
        var output = "Weekly Review (\(weekRangeStr))\n\n"

        // Stats
        output += "Completed: \(completedCount) tasks\n"
        output += "Created: \(createdCount) tasks\n"
        output += "Rate: \(completionRate)%\n"

        // Top lists
        if !listCompletions.isEmpty {
            output += "\nTop Lists:\n"
            for (listName, count) in listCompletions.prefix(3) {
                output += "• \(listName): \(count) done\n"
            }
        }

        // Best day and streak
        if let dayName = bestDayName, bestDayCount > 0 {
            output += "\nBest Day: \(dayName) (\(bestDayCount) tasks)\n"
        }
        if streak > 1 {
            output += "Streak: \(streak) days\n"
        }

        // Needs attention
        if overdueCount > 0 || highPriorityCount > 0 {
            output += "\nNeeds Attention:\n"
            if overdueCount > 0 {
                output += "• \(overdueCount) overdue tasks\n"
            }
            if highPriorityCount > 0 {
                output += "• \(highPriorityCount) high priority pending\n"
            }
        }

        // Suggestions
        if includeSuggestions && (overdueCount > 0 || highPriorityCount > 0) {
            output += "\n"
            if overdueCount > 0 {
                output += "Say \"move overdue to today\" to catch up.\n"
            }
        }

        // Motivation
        if completedCount > createdCount && completedCount > 10 {
            output += "\nGreat week! You completed more than you created.\n"
        }

        // Post notification
        NotificationCenter.default.post(
            name: .aiWeeklyReviewCompleted,
            object: nil,
            userInfo: [
                "completedCount": completedCount,
                "createdCount": createdCount,
                "completionRate": Double(completionRate)
            ]
        )

        HapticManager.shared.success()
        return output
    }

    // MARK: - Helpers

    private func dayName(for weekday: Int) -> String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekday >= 1 && weekday <= 7 ? days[weekday] : "Unknown"
    }

    private func calculateStreak(completedTasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())

        // Get unique completion dates
        let completionDates = Set(completedTasks.compactMap { task -> Date? in
            guard let completedAt = task.completedAt else { return nil }
            return calendar.startOfDay(for: completedAt)
        })

        // Count consecutive days backwards from today
        while completionDates.contains(currentDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
            currentDate = previousDay
        }

        return streak
    }
}
