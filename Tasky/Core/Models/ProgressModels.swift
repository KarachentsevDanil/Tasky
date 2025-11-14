//
//  ProgressModels.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

// MARK: - Time Period
enum ProgressTimePeriod: String, CaseIterable {
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

// MARK: - Progress Statistics
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

// MARK: - Day Activity
struct DayActivity: Identifiable {
    let id = UUID()
    let label: String
    let total: Int
    let completed: Int
}

// MARK: - Personal Best
struct PersonalBest {
    let metric: String
    let value: Int
    let period: String
}

// MARK: - Achievement Data
struct AchievementData: Identifiable, Equatable {
    let id: Int
    let name: String
    let icon: String
    let description: String
    let unlocked: Bool
    let progress: Int
    let required: Int
}
