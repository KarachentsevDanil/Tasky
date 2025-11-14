//
//  ProgressInsightsGenerator.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Service for generating progress insights and recommendations
final class ProgressInsightsGenerator {

    // MARK: - Insights Generation
    func generateInsights(from tasks: [TaskEntity], period: ProgressTimePeriod) -> [String] {
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

    // MARK: - Most Productive Day
    func findMostProductiveDay(from tasks: [TaskEntity]) -> String? {
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

    // MARK: - Best Time of Day
    func findBestTimeOfDay(from tasks: [TaskEntity]) -> String? {
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
}
