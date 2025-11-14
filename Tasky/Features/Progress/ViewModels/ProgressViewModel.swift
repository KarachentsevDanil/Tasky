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
    @Published var selectedPeriod: ProgressTimePeriod = .week
    @Published var statisticsState: LoadingState<ProgressStatistics> = .idle
    @Published var newlyUnlockedAchievements: [AchievementData] = []

    // MARK: - Computed Properties (for backward compatibility)
    var statistics: ProgressStatistics? {
        statisticsState.data
    }

    var isLoading: Bool {
        statisticsState.isLoading
    }

    var error: Error? {
        statisticsState.error
    }

    // MARK: - Dependencies
    private let dataService: DataService
    private let statsCalculator: ProgressStatsCalculator
    private let insightsGenerator: ProgressInsightsGenerator
    private let achievementsManager: ProgressAchievementsManager

    // MARK: - Private State
    private var previousAchievements: Set<Int> = []

    // MARK: - Initialization
    init(
        dataService: DataService,
        statsCalculator: ProgressStatsCalculator = ProgressStatsCalculator(),
        insightsGenerator: ProgressInsightsGenerator = ProgressInsightsGenerator(),
        achievementsManager: ProgressAchievementsManager = ProgressAchievementsManager()
    ) {
        self.dataService = dataService
        self.statsCalculator = statsCalculator
        self.insightsGenerator = insightsGenerator
        self.achievementsManager = achievementsManager
    }

    // MARK: - Data Loading
    func loadStatistics() async {
        statisticsState = .loading

        do {
            let allTasks = try dataService.fetchAllTasks()
            let newStats = calculateStatistics(from: allTasks, period: selectedPeriod)

            // Detect newly unlocked achievements
            detectNewlyUnlockedAchievements(newStats.achievements)

            statisticsState = .loaded(newStats)
        } catch {
            statisticsState = .error(error)
        }
    }

    /// Retry loading statistics after an error
    func retryLoadStatistics() async {
        await loadStatistics()
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
    private func calculateStatistics(from tasks: [TaskEntity], period: ProgressTimePeriod) -> ProgressStatistics {
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
        let streak = statsCalculator.calculateCurrentStreak(from: tasks)

        // Calculate weekly activity
        let weeklyActivity = statsCalculator.calculateWeeklyActivity(from: tasks, period: period)

        // Calculate heatmap data
        let heatmapData = statsCalculator.calculateHeatmapData(from: tasks, period: period)

        // Calculate productivity score
        let consistency = statsCalculator.calculateConsistency(from: currentPeriodTasks, period: period)
        let productivityScore = statsCalculator.calculateProductivityScore(
            completionRate: completionRate,
            consistency: consistency
        )

        // Generate insights
        let insights = insightsGenerator.generateInsights(from: tasks, period: period)

        // Calculate personal best
        let personalBest = statsCalculator.calculatePersonalBest(from: tasks)

        // Achievements
        let achievements = achievementsManager.calculateAchievements(from: tasks, streak: streak.current)

        return ProgressStatistics(
            // Streak
            currentStreak: streak.current,
            recordStreak: streak.record,
            streakMessage: statsCalculator.generateStreakMessage(current: streak.current, record: streak.record),

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
}
