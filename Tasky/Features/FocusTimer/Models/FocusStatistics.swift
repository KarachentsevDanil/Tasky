//
//  FocusStatistics.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import Foundation

/// Model for focus statistics data
struct FocusStatistics {
    // Today's stats
    var todaysPomoCount: Int = 0
    var todaysFocusSeconds: Int = 0
    var yesterdaysPomoCount: Int = 0
    var yesterdaysFocusSeconds: Int = 0

    // Total stats
    var totalPomoCount: Int = 0
    var totalFocusSeconds: Int = 0

    // MARK: - Computed Properties

    var todaysPomoChange: Int {
        todaysPomoCount - yesterdaysPomoCount
    }

    var todaysFocusChange: Int {
        todaysFocusSeconds - yesterdaysFocusSeconds
    }

    var todaysFocusFormatted: String {
        formatDuration(todaysFocusSeconds)
    }

    var totalFocusFormatted: String {
        formatDuration(totalFocusSeconds)
    }

    var todaysFocusChangeFormatted: String {
        formatDurationChange(todaysFocusChange)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatDurationChange(_ seconds: Int) -> String {
        let prefix = seconds >= 0 ? "+" : ""
        let hours = abs(seconds) / 3600
        let minutes = (abs(seconds) % 3600) / 60

        if hours > 0 {
            return "\(prefix)\(hours)h \(minutes)m"
        } else {
            return "\(prefix)\(minutes)m"
        }
    }
}

/// Represents a day's focus data for heatmap
struct DayFocusData: Identifiable {
    let id = UUID()
    let date: Date
    var totalSeconds: Int
    var sessionCount: Int

    var intensity: Double {
        // Normalize to 0-1 scale (cap at 4 hours = 14400 seconds)
        min(Double(totalSeconds) / 14400.0, 1.0)
    }

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Represents a task's total focus time for ranking
struct TaskFocusRanking: Identifiable {
    let id: UUID
    let taskTitle: String
    let taskListName: String?
    let totalSeconds: Int
    let sessionCount: Int

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

/// Period type for statistics filtering
enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case day = "Day"
    case week = "Week"
    case month = "Month"

    var id: String { rawValue }
}
