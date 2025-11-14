//
//  ProgressViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ProgressViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var selectedPeriod: TimePeriod = .week
    @Published var statistics: ProgressStatistics?
    @Published var isLoading = false
    @Published var error: Error?
    @Published var newlyUnlockedAchievements: [AchievementData] = []

    // MARK: - Dependencies
    private let dataService: DataService

    // MARK: - Private State
    private var previousAchievements: Set<Int> = []

    // MARK: - Initialization
    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Time Period
    enum TimePeriod: String, CaseIterable {
        case week = "Week"
        case month = "Month"
        case year = "Year"

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .year: return 365
            }
        }
    }

    // MARK: - Data Loading
    func loadStatistics() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allTasks = try dataService.fetchAllTasks()
            let newStats = calculateStatistics(from: allTasks, period: selectedPeriod)

            // Detect newly unlocked achievements
            detectNewlyUnlockedAchievements(newStats.achievements)

            statistics = newStats
        } catch {
            self.error = error
        }
    }

    // MARK: - Achievement Unlock Detection
    private func detectNewlyUnlockedAchievements(_ achievements: [AchievementData]) {
        let currentlyUnlocked = Set(achievements.filter { $0.unlocked }.map { $0.id })
        let newUnlocks = currentlyUnlocked.subtracting(previousAchievements)

        if !newUnlocks.isEmpty {
            newlyUnlockedAchievements = achievements.filter { newUnlocks.contains($0.id) }

            // Play haptic feedback for each new unlock
            for _ in newUnlocks {
                HapticManager.shared.success()
            }
        }

        previousAchievements = currentlyUnlocked
    }

    func clearNewlyUnlockedAchievements() {
        newlyUnlockedAchievements = []
    }

    // MARK: - Statistics Calculation
    private func calculateStatistics(from tasks: [TaskEntity], period: TimePeriod) -> ProgressStatistics {
        let calendar = Calendar.current
        let now = Date()
        let periodStart = calendar.date(byAdding: .day, value: -period.days, to: now) ?? now
        let previousPeriodStart = calendar.date(byAdding: .day, value: -period.days * 2, to: now) ?? now

        // Current period tasks
        let currentPeriodTasks = tasks.filter { task in
            let date = task.completedAt ?? task.createdAt
            return date >= periodStart && date <= now
        }

        // Previous period tasks (for trends)
        let previousPeriodTasks = tasks.filter { task in
            let date = task.completedAt ?? task.createdAt
            return date >= previousPeriodStart && date < periodStart
        }

        // Calculate stats
        let completed = currentPeriodTasks.filter { $0.isCompleted }.count
        let previousCompleted = previousPeriodTasks.filter { $0.isCompleted }.count
        let completedChange = completed - previousCompleted

        let totalFocusSeconds = currentPeriodTasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }
        let focusHours = Double(totalFocusSeconds) / 3600.0
        let previousFocusSeconds = previousPeriodTasks.reduce(0) { $0 + Int($1.focusTimeSeconds) }
        let previousFocusHours = Double(previousFocusSeconds) / 3600.0
        let focusHoursChange = focusHours - previousFocusHours

        let completionRate = currentPeriodTasks.isEmpty ? 0 : Double(completed) / Double(currentPeriodTasks.count) * 100
        let previousCompletionRate = previousPeriodTasks.isEmpty ? 0 : Double(previousCompleted) / Double(previousPeriodTasks.count) * 100
        let completionRateChange = completionRate - previousCompletionRate

        let avgPerDay = Double(completed) / Double(period.days)
        let previousAvgPerDay = Double(previousCompleted) / Double(period.days)
        let avgPerDayChange = avgPerDay - previousAvgPerDay

        // Calculate streak
        let streak = calculateCurrentStreak(from: tasks)

        // Calculate weekly activity
        let weeklyActivity = calculateWeeklyActivity(from: tasks, period: period)

        // Calculate heatmap data
        let heatmapData = calculateHeatmapData(from: tasks, period: period)

        // Calculate productivity score
        let productivityScore = calculateProductivityScore(
            completionRate: completionRate,
            consistency: calculateConsistency(from: currentPeriodTasks, period: period)
        )

        // Generate insights
        let insights = generateInsights(from: tasks, period: period)

        // Calculate personal best
        let personalBest = calculatePersonalBest(from: tasks)

        // Achievements
        let achievements = calculateAchievements(from: tasks, streak: streak.current)

        return ProgressStatistics(
            // Streak
            currentStreak: streak.current,
            recordStreak: streak.record,
            streakMessage: generateStreakMessage(current: streak.current, record: streak.record),

            // Stats
            tasksCompleted: completed,
            tasksCompletedChange: completedChange,
            focusHours: focusHours,
            focusHoursChange: focusHoursChange,
            completionRate: completionRate,
            completionRateChange: completionRateChange,
            avgPerDay: avgPerDay,
            avgPerDayChange: avgPerDayChange,

            // Charts
            weeklyActivity: weeklyActivity,
            heatmapData: heatmapData,

            // Score & Insights
            productivityScore: productivityScore,
            insights: insights,

            // Personal Best
            personalBest: personalBest,

            // Achievements
            achievements: achievements
        )
    }

    // MARK: - Streak Calculation
    private func calculateCurrentStreak(from tasks: [TaskEntity]) -> (current: Int, record: Int) {
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

    private func generateStreakMessage(current: Int, record: Int) -> String {
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

    // MARK: - Weekly Activity Calculation
    private func calculateWeeklyActivity(from tasks: [TaskEntity], period: TimePeriod) -> [DayActivity] {
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
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                label = formatter.string(from: date)
            } else if period == .month {
                date = calendar.date(byAdding: .weekOfYear, value: -i, to: now) ?? now
                label = "W\(i + 1)"
            } else {
                date = calendar.date(byAdding: .month, value: -i, to: now) ?? now
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM"
                label = formatter.string(from: date)
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
    private func calculateHeatmapData(from tasks: [TaskEntity], period: TimePeriod) -> [Int] {
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
    private func calculateProductivityScore(completionRate: Double, consistency: Double) -> Int {
        let score = (completionRate * 0.6) + (consistency * 0.4)
        return min(100, max(0, Int(score)))
    }

    private func calculateConsistency(from tasks: [TaskEntity], period: TimePeriod) -> Double {
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

    // MARK: - Insights Generation
    private func generateInsights(from tasks: [TaskEntity], period: TimePeriod) -> [String] {
        var insights: [String] = []

        // Most productive day analysis
        if let mostProductiveDay = findMostProductiveDay(from: tasks) {
            insights.append("You're most productive on \(mostProductiveDay)s")
        }

        // Best time analysis
        if let bestTime = findBestTimeOfDay(from: tasks) {
            insights.append("Try tackling high-priority tasks \(bestTime)")
        }

        // Progress tracking
        let completed = tasks.filter { $0.isCompleted }.count
        insights.append("You're on track! \(completed) tasks completed overall")

        return insights
    }

    private func findMostProductiveDay(from tasks: [TaskEntity]) -> String? {
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let weekday = calendar.component(.weekday, from: completedAt)
                dayCounts[weekday, default: 0] += 1
            }
        }

        guard let mostProductiveWeekday = dayCounts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        let dayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return dayNames[mostProductiveWeekday - 1]
    }

    private func findBestTimeOfDay(from tasks: [TaskEntity]) -> String? {
        let calendar = Calendar.current
        var morningCount = 0
        var afternoonCount = 0
        var eveningCount = 0

        for task in tasks where task.isCompleted {
            if let completedAt = task.completedAt {
                let hour = calendar.component(.hour, from: completedAt)

                if hour >= 6 && hour < 12 {
                    morningCount += 1
                } else if hour >= 12 && hour < 18 {
                    afternoonCount += 1
                } else {
                    eveningCount += 1
                }
            }
        }

        let maxCount = max(morningCount, afternoonCount, eveningCount)

        if morningCount == maxCount {
            return "in the morning (6-12 AM)"
        } else if afternoonCount == maxCount {
            return "in the afternoon (12-6 PM)"
        } else {
            return "in the evening (after 6 PM)"
        }
    }

    // MARK: - Personal Best
    private func calculatePersonalBest(from tasks: [TaskEntity]) -> PersonalBest? {
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

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        let periodString = formatter.string(from: bestWeek.key)

        return PersonalBest(
            metric: "tasks",
            value: bestWeek.value,
            period: periodString
        )
    }

    // MARK: - Achievements
    private func calculateAchievements(from tasks: [TaskEntity], streak: Int) -> [AchievementData] {
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

// MARK: - Data Models
struct ProgressStatistics {
    // Streak
    let currentStreak: Int
    let recordStreak: Int
    let streakMessage: String

    // Stats
    let tasksCompleted: Int
    let tasksCompletedChange: Int
    let focusHours: Double
    let focusHoursChange: Double
    let completionRate: Double
    let completionRateChange: Double
    let avgPerDay: Double
    let avgPerDayChange: Double

    // Charts
    let weeklyActivity: [DayActivity]
    let heatmapData: [Int]

    // Score & Insights
    let productivityScore: Int
    let insights: [String]

    // Personal Best
    let personalBest: PersonalBest?

    // Achievements
    let achievements: [AchievementData]
}

struct DayActivity: Identifiable {
    let id = UUID()
    let label: String
    let total: Int
    let completed: Int
}

struct PersonalBest {
    let metric: String
    let value: Int
    let period: String
}

struct AchievementData: Identifiable, Equatable {
    let id: Int
    let name: String
    let icon: String
    let description: String
    let unlocked: Bool
    let progress: Int
    let required: Int
}
