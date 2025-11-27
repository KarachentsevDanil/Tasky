//
//  PatternTrackingService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation

/// Service for analyzing and reporting user patterns
/// Uses data collected by ContextExtractionService to provide insights
@MainActor
class PatternTrackingService {

    // MARK: - Singleton
    static let shared = PatternTrackingService()

    // MARK: - Dependencies
    private let contextService: ContextService
    private let dataService: DataService

    // MARK: - Initialization
    init(contextService: ContextService = .shared, dataService: DataService = DataService()) {
        self.contextService = contextService
        self.dataService = dataService
    }

    // MARK: - Pattern Analysis

    /// Get productivity peak hours based on completion patterns
    func getProductivityPeaks() throws -> [ProductivityPeak] {
        let patterns = try contextService.fetchAllContext(category: .pattern, minConfidence: 0.2)

        var hourlyData: [Int: Int] = [:]

        for pattern in patterns {
            if pattern.key.hasPrefix("completion_hour_") {
                if let hour = Int(pattern.key.replacingOccurrences(of: "completion_hour_", with: "")) {
                    let dataPoints = (pattern.metadataDict?["dataPoints"] as? Int) ?? 1
                    hourlyData[hour, default: 0] += dataPoints
                }
            }
        }

        // Sort by data points and return top periods
        return hourlyData
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { ProductivityPeak(hour: $0.key, completions: $0.value, confidence: calculateConfidence(dataPoints: $0.value)) }
    }

    /// Get most active days of the week
    func getActiveDays() throws -> [ActiveDay] {
        let patterns = try contextService.fetchAllContext(category: .pattern, minConfidence: 0.2)
        let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

        var weekdayData: [Int: Int] = [:]

        for pattern in patterns {
            if pattern.key.hasPrefix("completion_day_") {
                if let weekday = Int(pattern.key.replacingOccurrences(of: "completion_day_", with: "")) {
                    let dataPoints = (pattern.metadataDict?["dataPoints"] as? Int) ?? 1
                    weekdayData[weekday, default: 0] += dataPoints
                }
            }
        }

        return weekdayData
            .sorted { $0.value > $1.value }
            .map { ActiveDay(weekday: $0.key, name: weekdayNames[$0.key], completions: $0.value) }
    }

    /// Get preferred scheduling times
    func getPreferredTimes() throws -> [PreferredTime] {
        let patterns = try contextService.fetchAllContext(category: .pattern, minConfidence: 0.2)

        var timeData: [String: Int] = [:]

        for pattern in patterns {
            if pattern.key.hasPrefix("preferred_time_") {
                let timeCategory = pattern.key.replacingOccurrences(of: "preferred_time_", with: "")
                let dataPoints = (pattern.metadataDict?["dataPoints"] as? Int) ?? 1
                timeData[timeCategory, default: 0] += dataPoints
            }
        }

        return timeData
            .sorted { $0.value > $1.value }
            .map { PreferredTime(category: $0.key, displayName: formatTimeCategory($0.key), count: $0.value) }
    }

    /// Get user's goals sorted by confidence
    func getActiveGoals() throws -> [UserGoal] {
        let goals = try contextService.fetchAllContext(category: .goal, minConfidence: 0.3)

        return goals.map { goal in
            UserGoal(
                key: goal.key,
                description: goal.value,
                confidence: goal.effectiveConfidence,
                lastReinforced: goal.updatedAt
            )
        }
    }

    /// Get frequently mentioned people
    func getFrequentPeople() throws -> [FrequentPerson] {
        let people = try contextService.fetchAllContext(category: .person, minConfidence: 0.3)

        return people.map { person in
            let relationship = (person.metadataDict?["relationship"] as? String) ?? "other"
            return FrequentPerson(
                name: person.value,
                relationship: relationship,
                confidence: person.effectiveConfidence,
                reinforcementCount: Int(person.reinforcementCount)
            )
        }
    }

    /// Get list usage statistics
    func getListPreferences() throws -> [ListPreference] {
        let preferences = try contextService.fetchAllContext(category: .preference, minConfidence: 0.2)

        var listUsage: [String: Int] = [:]

        for pref in preferences {
            if pref.key.hasPrefix("list_usage_") || pref.key.hasPrefix("list_") {
                let listName = pref.key
                    .replacingOccurrences(of: "list_usage_", with: "")
                    .replacingOccurrences(of: "list_", with: "")
                listUsage[listName, default: 0] += Int(pref.reinforcementCount) + 1
            }
        }

        return listUsage
            .sorted { $0.value > $1.value }
            .map { ListPreference(listName: $0.key.capitalized, usageCount: $0.value) }
    }

    // MARK: - Insights Generation

    /// Generate personalized insights based on patterns
    func generateInsights() throws -> [PatternInsight] {
        var insights: [PatternInsight] = []

        // Productivity peak insight
        let peaks = try getProductivityPeaks()
        if let topPeak = peaks.first, topPeak.completions >= 3 {
            let timeStr = formatHour(topPeak.hour)
            insights.append(PatternInsight(
                type: .productivityPeak,
                title: "Peak Productivity Time",
                description: "You complete most tasks around \(timeStr). Consider scheduling important work then.",
                confidence: topPeak.confidence
            ))
        }

        // Active day insight
        let activeDays = try getActiveDays()
        if let topDay = activeDays.first, topDay.completions >= 3 {
            insights.append(PatternInsight(
                type: .activeDays,
                title: "Most Active Day",
                description: "\(topDay.name) is your most productive day with \(topDay.completions) completions.",
                confidence: calculateConfidence(dataPoints: topDay.completions)
            ))
        }

        // Goal focus insight
        let goals = try getActiveGoals()
        if goals.count >= 2 {
            let topGoals = goals.prefix(2).map { $0.key.capitalized }
            insights.append(PatternInsight(
                type: .goalFocus,
                title: "Current Focus Areas",
                description: "Your main focus areas are \(topGoals.joined(separator: " and ")).",
                confidence: goals.first?.confidence ?? 0.5
            ))
        }

        // Frequent collaborator insight
        let people = try getFrequentPeople()
        if let topPerson = people.first, topPerson.reinforcementCount >= 2 {
            insights.append(PatternInsight(
                type: .frequentCollaborator,
                title: "Frequent Collaborator",
                description: "You often work with \(topPerson.name). Consider creating a shared list or project.",
                confidence: topPerson.confidence
            ))
        }

        return insights.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Summary for AI Prompts

    /// Get a formatted summary of patterns for AI context injection
    func getPatternSummaryForPrompt() throws -> String {
        var summary: [String] = []

        // Add productivity peaks
        let peaks = try getProductivityPeaks()
        if let topPeak = peaks.first, topPeak.completions >= 2 {
            summary.append("Most productive around \(formatHour(topPeak.hour))")
        }

        // Add active days
        let activeDays = try getActiveDays()
        if let topDay = activeDays.first, topDay.completions >= 2 {
            summary.append("Most active on \(topDay.name)s")
        }

        // Add top goals
        let goals = try getActiveGoals()
        let topGoals = goals.prefix(2).map { $0.key }
        if !topGoals.isEmpty {
            summary.append("Focus areas: \(topGoals.joined(separator: ", "))")
        }

        return summary.joined(separator: "; ")
    }

    // MARK: - Helper Methods

    private func calculateConfidence(dataPoints: Int) -> Float {
        // More data points = higher confidence, with diminishing returns
        return min(Float(dataPoints) * 0.15, 0.95)
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"

        var components = DateComponents()
        components.hour = hour

        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
    }

    private func formatTimeCategory(_ category: String) -> String {
        category.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

// MARK: - Data Models

struct ProductivityPeak {
    let hour: Int
    let completions: Int
    let confidence: Float
}

struct ActiveDay {
    let weekday: Int
    let name: String
    let completions: Int
}

struct PreferredTime {
    let category: String
    let displayName: String
    let count: Int
}

struct UserGoal {
    let key: String
    let description: String
    let confidence: Float
    let lastReinforced: Date
}

struct FrequentPerson {
    let name: String
    let relationship: String
    let confidence: Float
    let reinforcementCount: Int
}

struct ListPreference {
    let listName: String
    let usageCount: Int
}

struct PatternInsight {
    let type: InsightType
    let title: String
    let description: String
    let confidence: Float

    enum InsightType {
        case productivityPeak
        case activeDays
        case goalFocus
        case frequentCollaborator
        case listUsage
    }
}
