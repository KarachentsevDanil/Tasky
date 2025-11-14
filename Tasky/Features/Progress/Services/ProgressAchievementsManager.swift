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
    func calculateAchievements(from tasks: [TaskEntity], streak: Int) -> [AchievementData] {
        let completed = tasks.filter { $0.isCompleted }.count
        let totalFocusHours = Double(tasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }) / 3600.0

        return [
            AchievementData(
                id: 1,
                name: "Week Warrior",
                icon: "🔥",
                description: "7 day streak",
                unlocked: streak >= 7,
                progress: streak,
                required: 7
            ),
            AchievementData(
                id: 2,
                name: "Speed Demon",
                icon: "⚡",
                description: "10 tasks in 1 day",
                unlocked: hasCompletedTasksInDay(tasks: tasks, count: 10),
                progress: maxTasksInOneDay(tasks: tasks),
                required: 10
            ),
            AchievementData(
                id: 3,
                name: "Perfectionist",
                icon: "🎯",
                description: "100% completion rate",
                unlocked: hasHundredPercentCompletion(tasks: tasks),
                progress: Int(calculateWeekCompletionRate(tasks: tasks)),
                required: 100
            ),
            AchievementData(
                id: 4,
                name: "Diamond",
                icon: "💎",
                description: "30 day streak",
                unlocked: streak >= 30,
                progress: streak,
                required: 30
            ),
            AchievementData(
                id: 5,
                name: "Champion",
                icon: "🏆",
                description: "100 tasks",
                unlocked: completed >= 100,
                progress: completed,
                required: 100
            ),
            AchievementData(
                id: 6,
                name: "All-Star",
                icon: "🌟",
                description: "30 focus hours",
                unlocked: totalFocusHours >= 30,
                progress: Int(totalFocusHours),
                required: 30
            )
        ]
    }

    // MARK: - Achievement Helpers
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
}
