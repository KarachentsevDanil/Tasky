//
//  ProgressAchievementsManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Service for managing and calculating achievements
final class ProgressAchievementsManager {

    // MARK: - Achievement Calculation
    func calculateAchievements(from tasks: [TaskEntity], focusSessions: [FocusSessionEntity], lists: [TaskListEntity], streak: Int) -> [AchievementData] {
        let completed = tasks.filter { $0.isCompleted }.count
        let totalFocusHours = Double(tasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }) / 3600.0
        let completedSessions = focusSessions.filter { $0.completed }.count

        var achievements: [AchievementData] = []

        // MARK: - Streak Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 1,
                name: "Week Warrior",
                icon: "🔥",
                description: "Complete tasks 7 days in a row",
                unlocked: streak >= 7,
                progress: min(streak, 7),
                required: 7
            ),
            AchievementData(
                id: 4,
                name: "Diamond",
                icon: "💎",
                description: "Complete tasks 30 days in a row",
                unlocked: streak >= 30,
                progress: min(streak, 30),
                required: 30
            )
        ])

        // MARK: - Speed & Volume Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 2,
                name: "Speed Demon",
                icon: "⚡",
                description: "Complete 10 tasks in a single day",
                unlocked: hasCompletedTasksInDay(tasks: tasks, count: 10),
                progress: maxTasksInOneDay(tasks: tasks),
                required: 10
            ),
            AchievementData(
                id: 5,
                name: "Champion",
                icon: "🏆",
                description: "Complete 100 tasks total",
                unlocked: completed >= 100,
                progress: min(completed, 100),
                required: 100
            ),
            AchievementData(
                id: 20,
                name: "Task Master",
                icon: "👑",
                description: "Complete 500 tasks total",
                unlocked: completed >= 500,
                progress: min(completed, 500),
                required: 500
            ),
            AchievementData(
                id: 21,
                name: "Productivity Legend",
                icon: "🌠",
                description: "Complete 1,000 tasks total",
                unlocked: completed >= 1000,
                progress: min(completed, 1000),
                required: 1000
            )
        ])

        // MARK: - Quality & Completion Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 3,
                name: "Perfectionist",
                icon: "🎯",
                description: "Achieve 100% weekly completion rate",
                unlocked: hasHundredPercentCompletion(tasks: tasks),
                progress: Int(calculateWeekCompletionRate(tasks: tasks)),
                required: 100
            ),
            AchievementData(
                id: 12,
                name: "Inbox Zero",
                icon: "✨",
                description: "Complete all today's tasks 5 times",
                unlocked: inboxZeroCount(tasks: tasks) >= 5,
                progress: min(inboxZeroCount(tasks: tasks), 5),
                required: 5
            ),
            AchievementData(
                id: 13,
                name: "Consistency Champion",
                icon: "🌟",
                description: "Complete all tasks 3 days in a row",
                unlocked: consecutiveCompleteDays(tasks: tasks) >= 3,
                progress: min(consecutiveCompleteDays(tasks: tasks), 3),
                required: 3
            ),
            AchievementData(
                id: 14,
                name: "Perfect Week",
                icon: "💫",
                description: "Complete all tasks Monday-Friday",
                unlocked: hasPerfectWeek(tasks: tasks),
                progress: perfectWeekProgress(tasks: tasks),
                required: 5
            )
        ])

        // MARK: - Focus Session Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 6,
                name: "All-Star",
                icon: "🌟",
                description: "Log 30 hours of focus time",
                unlocked: totalFocusHours >= 30,
                progress: Int(min(totalFocusHours, 30)),
                required: 30
            ),
            AchievementData(
                id: 7,
                name: "Focus Beginner",
                icon: "🧘",
                description: "Complete 5 focus sessions",
                unlocked: completedSessions >= 5,
                progress: min(completedSessions, 5),
                required: 5
            ),
            AchievementData(
                id: 8,
                name: "Focus Warrior",
                icon: "🔥",
                description: "Complete 25 focus sessions",
                unlocked: completedSessions >= 25,
                progress: min(completedSessions, 25),
                required: 25
            ),
            AchievementData(
                id: 9,
                name: "Focus Legend",
                icon: "⚡",
                description: "Complete 100 focus sessions",
                unlocked: completedSessions >= 100,
                progress: min(completedSessions, 100),
                required: 100
            ),
            AchievementData(
                id: 26,
                name: "Time Logger",
                icon: "⏱️",
                description: "Log 25 hours of focus time",
                unlocked: totalFocusHours >= 25,
                progress: Int(min(totalFocusHours, 25)),
                required: 25
            ),
            AchievementData(
                id: 27,
                name: "Marathon Runner",
                icon: "🏃",
                description: "Log 100 hours of focus time",
                unlocked: totalFocusHours >= 100,
                progress: Int(min(totalFocusHours, 100)),
                required: 100
            )
        ])

        // MARK: - Planning & Scheduling Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 10,
                name: "Week Planner",
                icon: "📅",
                description: "Schedule tasks for 7 days in a row",
                unlocked: consecutiveSchedulingDays(tasks: tasks) >= 7,
                progress: min(consecutiveSchedulingDays(tasks: tasks), 7),
                required: 7
            ),
            AchievementData(
                id: 11,
                name: "Schedule Pro",
                icon: "📊",
                description: "Use time blocking for 30 days",
                unlocked: daysWithScheduledTasks(tasks: tasks) >= 30,
                progress: min(daysWithScheduledTasks(tasks: tasks), 30),
                required: 30
            )
        ])

        // MARK: - Priority Management Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 18,
                name: "Priority Master",
                icon: "⚡",
                description: "Complete all P0 tasks for 10 days",
                unlocked: daysWithAllP0Complete(tasks: tasks) >= 10,
                progress: min(daysWithAllP0Complete(tasks: tasks), 10),
                required: 10
            ),
            AchievementData(
                id: 19,
                name: "Prioritizer",
                icon: "🎖️",
                description: "Use all 4 priority levels effectively",
                unlocked: hasUsedAllPriorityLevels(tasks: tasks),
                progress: uniquePriorityLevelsUsed(tasks: tasks),
                required: 4
            )
        ])

        // MARK: - Habit Building Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 22,
                name: "Morning Person",
                icon: "🌅",
                description: "Complete first task before 9 AM, 10 times",
                unlocked: earlyMorningCompletions(tasks: tasks) >= 10,
                progress: min(earlyMorningCompletions(tasks: tasks), 10),
                required: 10
            )
        ])

        // MARK: - Organization Achievements
        achievements.append(contentsOf: [
            AchievementData(
                id: 24,
                name: "List Curator",
                icon: "📚",
                description: "Create and use 5 different lists",
                unlocked: lists.count >= 5,
                progress: min(lists.count, 5),
                required: 5
            ),
            AchievementData(
                id: 25,
                name: "Personalization Pro",
                icon: "🎨",
                description: "Customize 5 lists with unique colors",
                unlocked: listsWithCustomColors(lists: lists) >= 5,
                progress: min(listsWithCustomColors(lists: lists), 5),
                required: 5
            )
        ])

        // MARK: - AI & Voice Achievements (Placeholder - requires tracking implementation)
        // These will be implemented when AI/Voice usage tracking is added to the data model
        achievements.append(contentsOf: [
            AchievementData(
                id: 15,
                name: "AI Assistant",
                icon: "🤖",
                description: "Create 10 tasks using AI chat",
                unlocked: false, // TODO: Implement AI task tracking
                progress: 0,
                required: 10
            ),
            AchievementData(
                id: 16,
                name: "Voice Pro",
                icon: "🎤",
                description: "Create 25 tasks using voice input",
                unlocked: false, // TODO: Implement voice task tracking
                progress: 0,
                required: 25
            ),
            AchievementData(
                id: 17,
                name: "AI Power User",
                icon: "🚀",
                description: "Create 100 tasks via AI or Voice",
                unlocked: false, // TODO: Implement combined AI/Voice tracking
                progress: 0,
                required: 100
            ),
            AchievementData(
                id: 23,
                name: "Daily Planner",
                icon: "📝",
                description: "Plan tomorrow's tasks today, 10 times",
                unlocked: false, // TODO: Implement planning tracking
                progress: 0,
                required: 10
            )
        ])

        return achievements.sorted { $0.id < $1.id }
    }

    // MARK: - Achievement Helpers

    // MARK: Speed & Volume Helpers
    private func hasCompletedTasksInDay(tasks: [TaskEntity], count: Int) -> Bool {
        let calendar = Calendar.current
        var dayCounts: [Date: Int] = [:]

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                dayCounts[day, default: 0] += 1
            }
        }

        return dayCounts.values.contains { $0 >= count }
    }

    private func maxTasksInOneDay(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var dayCounts: [Date: Int] = [:]

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                dayCounts[day, default: 0] += 1
            }
        }

        return dayCounts.values.max() ?? 0
    }

    // MARK: Completion Rate Helpers
    private func hasHundredPercentCompletion(tasks: [TaskEntity]) -> Bool {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekTasks = tasks.filter {
            let date = $0.createdAt
            return date >= weekAgo
        }

        if weekTasks.isEmpty { return false }

        let completed = weekTasks.filter { $0.isCompleted }.count
        return completed == weekTasks.count
    }

    private func calculateWeekCompletionRate(tasks: [TaskEntity]) -> Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekTasks = tasks.filter {
            let date = $0.createdAt
            return date >= weekAgo
        }

        if weekTasks.isEmpty { return 0 }

        let completed = weekTasks.filter { $0.isCompleted }.count
        return Double(completed) / Double(weekTasks.count) * 100
    }

    // MARK: Inbox Zero Helpers
    private func inboxZeroCount(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var completeDays: Set<Date> = []

        // Group tasks by their due date
        var tasksByDay: [Date: [TaskEntity]] = [:]
        for task in tasks {
            if let dueDate = task.dueDate {
                let day = calendar.startOfDay(for: dueDate)
                tasksByDay[day, default: []].append(task)
            }
        }

        // Check each day to see if all tasks were completed
        for (day, dayTasks) in tasksByDay {
            let allCompleted = dayTasks.allSatisfy { $0.isCompleted }
            if allCompleted && !dayTasks.isEmpty {
                completeDays.insert(day)
            }
        }

        return completeDays.count
    }

    // MARK: Consistency Helpers
    private func consecutiveCompleteDays(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var tasksByDay: [Date: [TaskEntity]] = [:]

        // Group tasks by completion date
        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                tasksByDay[day, default: []].append(task)
            }
        }

        // Find consecutive days where all tasks were completed
        let sortedDays = tasksByDay.keys.sorted(by: >)
        var maxConsecutive = 0
        var currentConsecutive = 0

        for i in 0..<sortedDays.count {
            let currentDay = sortedDays[i]

            // Check if this day had all tasks completed
            let dayTasks = tasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: currentDay)
            }

            if !dayTasks.isEmpty && dayTasks.allSatisfy({ $0.isCompleted }) {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else if !dayTasks.isEmpty {
                currentConsecutive = 0
            }
        }

        return maxConsecutive
    }

    // MARK: Perfect Week Helpers
    private func hasPerfectWeek(tasks: [TaskEntity]) -> Bool {
        let calendar = Calendar.current
        let today = Date()

        // Find the most recent Monday
        var monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        // Check last 4 weeks for a perfect week
        for _ in 0..<4 {
            var hasAllDays = true

            for dayOffset in 0..<5 { // Monday to Friday
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monday) else {
                    hasAllDays = false
                    break
                }

                let dayTasks = tasks.filter {
                    guard let dueDate = $0.dueDate else { return false }
                    return calendar.isDate(dueDate, inSameDayAs: day)
                }

                if dayTasks.isEmpty || !dayTasks.allSatisfy({ $0.isCompleted }) {
                    hasAllDays = false
                    break
                }
            }

            if hasAllDays {
                return true
            }

            // Move to previous week
            monday = calendar.date(byAdding: .day, value: -7, to: monday)!
        }

        return false
    }

    private func perfectWeekProgress(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        let today = Date()
        let monday = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today))!

        var completedDays = 0

        for dayOffset in 0..<5 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: monday) else { continue }

            let dayTasks = tasks.filter {
                guard let dueDate = $0.dueDate else { return false }
                return calendar.isDate(dueDate, inSameDayAs: day)
            }

            if !dayTasks.isEmpty && dayTasks.allSatisfy({ $0.isCompleted }) {
                completedDays += 1
            }
        }

        return completedDays
    }

    // MARK: Scheduling Helpers
    private func consecutiveSchedulingDays(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var daysWithScheduling: Set<Date> = []

        for task in tasks where task.scheduledTime != nil {
            let day = calendar.startOfDay(for: task.scheduledTime!)
            daysWithScheduling.insert(day)
        }

        let sortedDays = daysWithScheduling.sorted(by: >)
        if sortedDays.isEmpty { return 0 }

        var maxConsecutive = 1
        var currentConsecutive = 1

        for i in 1..<sortedDays.count {
            let daysDiff = calendar.dateComponents([.day], from: sortedDays[i], to: sortedDays[i-1]).day ?? 0

            if daysDiff == 1 {
                currentConsecutive += 1
                maxConsecutive = max(maxConsecutive, currentConsecutive)
            } else {
                currentConsecutive = 1
            }
        }

        return maxConsecutive
    }

    private func daysWithScheduledTasks(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var daysWithScheduling: Set<Date> = []

        for task in tasks where task.scheduledTime != nil {
            let day = calendar.startOfDay(for: task.scheduledTime!)
            daysWithScheduling.insert(day)
        }

        return daysWithScheduling.count
    }

    // MARK: Priority Helpers
    private func daysWithAllP0Complete(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var daysCount = 0

        // Get unique completion days
        var completionDays: Set<Date> = []
        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                completionDays.insert(calendar.startOfDay(for: completedAt))
            }
        }

        // Check each day
        for day in completionDays {
            let dayP0Tasks = tasks.filter {
                $0.priority == 0 && // P0 priority
                calendar.isDate($0.createdAt, inSameDayAs: day)
            }

            if !dayP0Tasks.isEmpty && dayP0Tasks.allSatisfy({ $0.isCompleted }) {
                daysCount += 1
            }
        }

        return daysCount
    }

    private func hasUsedAllPriorityLevels(tasks: [TaskEntity]) -> Bool {
        let priorities = Set(tasks.map { $0.priority })
        return priorities.contains(0) && priorities.contains(1) &&
               priorities.contains(2) && priorities.contains(3)
    }

    private func uniquePriorityLevelsUsed(tasks: [TaskEntity]) -> Int {
        let priorities = Set(tasks.map { $0.priority })
        return min(priorities.count, 4)
    }

    // MARK: Morning Person Helpers
    private func earlyMorningCompletions(tasks: [TaskEntity]) -> Int {
        let calendar = Calendar.current
        var earlyCount = 0

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let hour = calendar.component(.hour, from: completedAt)
                if hour < 9 {
                    earlyCount += 1
                }
            }
        }

        return earlyCount
    }

    // MARK: Organization Helpers
    private func listsWithCustomColors(lists: [TaskListEntity]) -> Int {
        return lists.filter { $0.colorHex != nil && !$0.colorHex!.isEmpty }.count
    }
}
