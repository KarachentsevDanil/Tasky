//
//  ProgressStatsCalculator.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Service for calculating progress statistics
final class ProgressStatsCalculator {

    // MARK: - Streak Calculation
    func calculateCurrentStreak(from tasks: [TaskEntity]) -> (current: Int, record: Int) {
        let calendar = Calendar.current
        let completedTasks = tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }

        var currentStreak = 0
        var recordStreak = 0
        var tempStreak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Calculate current streak (consecutive days)
        while true {
            let hasTaskOnDate = completedTasks.contains { task in
                guard let completedAt = task.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: checkDate)
            }

            if hasTaskOnDate {
                currentStreak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                // Allow one day gap (today might not have completions yet)
                if currentStreak == 0 && calendar.isDateInToday(checkDate) {
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
                    continue
                }
                break
            }
        }

        // Calculate record streak (all time)
        tempStreak = 0
        var previousDate: Date?

        for task in completedTasks {
            guard let completedAt = task.completedAt else { continue }
            let taskDay = calendar.startOfDay(for: completedAt)

            if let prevDate = previousDate {
                let dayDifference = calendar.dateComponents([.day], from: taskDay, to: prevDate).day ?? 0

                if dayDifference == 1 {
                    tempStreak += 1
                    recordStreak = max(recordStreak, tempStreak)
                } else if dayDifference == 0 {
                    // Same day, continue streak
                    continue
                } else {
                    tempStreak = 1
                }
            } else {
                tempStreak = 1
            }

            previousDate = taskDay
        }

        recordStreak = max(recordStreak, tempStreak)
        recordStreak = max(recordStreak, currentStreak)

        return (max(currentStreak, 0), max(recordStreak, 0))
    }

    func generateStreakMessage(current: Int, record: Int) -> String {
        let remaining = record - current

        if current == 0 {
            return "Complete a task today to start your streak!"
        } else if current >= record {
            return "New record! You're unstoppable! 🎉"
        } else if remaining <= 3 {
            return "\(remaining) more day\(remaining == 1 ? "" : "s") to beat your record! 🎯"
        } else {
            return "Building momentum! 💪"
        }
    }

    // MARK: - Activity Calculation
    func calculateWeeklyActivity(from tasks: [TaskEntity], period: ProgressTimePeriod) -> [DayActivity] {
        let calendar = Calendar.current
        let now = Date()
        var activities: [DayActivity] = []

        let daysToShow: Int
        let groupByDay: Bool

        switch period {
        case .week:
            daysToShow = 7
            groupByDay = true
        case .month:
            daysToShow = 4 // 4 weeks
            groupByDay = false
        case .year:
            daysToShow = 12 // 12 months
            groupByDay = false
        }

        for i in (0..<daysToShow).reversed() {
            let date: Date
            let label: String

            if groupByDay {
                date = calendar.date(byAdding: .day, value: -i, to: now) ?? now
                label = AppDateFormatters.weekdayFormatter.string(from: date)
            } else if period == .month {
                date = calendar.date(byAdding: .weekOfYear, value: -i, to: now) ?? now
                label = "W\(i + 1)"
            } else {
                date = calendar.date(byAdding: .month, value: -i, to: now) ?? now
                // Extract month abbreviation from monthYearFormatter
                let monthYear = AppDateFormatters.monthYearFormatter.string(from: date)
                label = String(monthYear.prefix(3))
            }

            let startOfPeriod: Date
            let endOfPeriod: Date

            if groupByDay {
                startOfPeriod = calendar.startOfDay(for: date)
                endOfPeriod = calendar.date(byAdding: .day, value: 1, to: startOfPeriod) ?? date
            } else if period == .month {
                startOfPeriod = calendar.startOfDay(for: date)
                endOfPeriod = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfPeriod) ?? date
            } else {
                startOfPeriod = calendar.startOfDay(for: date)
                endOfPeriod = calendar.date(byAdding: .month, value: 1, to: startOfPeriod) ?? date
            }

            let tasksInPeriod = tasks.filter { task in
                let taskDate = task.completedAt ?? task.createdAt
                return taskDate >= startOfPeriod && taskDate < endOfPeriod
            }

            let total = tasksInPeriod.count
            let completed = tasksInPeriod.filter { $0.isCompleted }.count

            activities.append(DayActivity(label: label, total: total, completed: completed))
        }

        return activities
    }

    // MARK: - Heatmap Calculation
    func calculateHeatmapData(from tasks: [TaskEntity], period: ProgressTimePeriod) -> [Int] {
        let calendar = Calendar.current
        let today = Date()
        var data: [Int] = []

        let daysToShow: Int
        switch period {
        case .week:
            daysToShow = 28 // 4 weeks
        case .month:
            daysToShow = 84 // 12 weeks
        case .year:
            daysToShow = 365 // Full year
        }

        for i in (0..<daysToShow).reversed() {
            let date = calendar.date(byAdding: .day, value: -i, to: today) ?? today
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date

            let completedOnDay = tasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= startOfDay && completedAt < endOfDay
            }.count

            data.append(completedOnDay)
        }

        return data
    }

    // MARK: - Productivity Score
    func calculateProductivityScore(completionRate: Double, consistency: Double) -> Int {
        let score = (completionRate * 0.6) + (consistency * 0.4)
        return min(100, max(0, Int(score)))
    }

    func calculateConsistency(from tasks: [TaskEntity], period: ProgressTimePeriod) -> Double {
        let calendar = Calendar.current

        var daysActive = Set<Date>()

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let day = calendar.startOfDay(for: completedAt)
                daysActive.insert(day)
            }
        }

        let consistency = Double(daysActive.count) / Double(period.days) * 100
        return min(100, max(0, consistency))
    }

    // MARK: - Personal Best
    func calculatePersonalBest(from tasks: [TaskEntity]) -> PersonalBest? {
        let calendar = Calendar.current
        var weekCounts: [Date: Int] = [:]

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let weekStart = calendar.dateInterval(of: .weekOfYear, for: completedAt)?.start ?? completedAt
                weekCounts[weekStart, default: 0] += 1
            }
        }

        guard let bestWeek = weekCounts.max(by: { $0.value < $1.value }) else {
            return nil
        }

        let periodString = AppDateFormatters.monthYearFormatter.string(from: bestWeek.key)

        return PersonalBest(
            metric: "tasks",
            value: bestWeek.value,
            period: periodString
        )
    }
}
