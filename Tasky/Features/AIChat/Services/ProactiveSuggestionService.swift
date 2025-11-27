//
//  ProactiveSuggestionService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import Combine

// MARK: - Proactive Suggestion Model

/// A proactive suggestion that the AI can initiate without user input
struct ProactiveSuggestion: Identifiable, Equatable {
    let id: UUID
    let type: SuggestionType
    let title: String
    let message: String
    let suggestedAction: String
    let icon: String
    let priority: Priority
    let createdAt: Date
    var relatedTaskIds: [UUID]
    var metadata: [String: String]

    enum SuggestionType: String, Codable, CaseIterable {
        case stuckTask          // Task rescheduled 3+ times
        case neglectedGoal      // Goal not worked on in 5+ days
        case overduePile        // 5+ overdue tasks
        case cleanSlate         // All today's tasks completed
        case birthdayReminder   // Context birthday approaching
        case streakMilestone    // Hit 7, 30, 100 day streak
        case weeklyReviewTime   // Sunday evening prompt
        case unusualProductivity // Completed 2x normal tasks
        case morningPlan        // Morning planning reminder
        case eveningWrapup      // Evening wrap-up reminder

        var displayName: String {
            switch self {
            case .stuckTask: return "Stuck Task"
            case .neglectedGoal: return "Neglected Goal"
            case .overduePile: return "Overdue Tasks"
            case .cleanSlate: return "All Done!"
            case .birthdayReminder: return "Reminder"
            case .streakMilestone: return "Milestone"
            case .weeklyReviewTime: return "Weekly Review"
            case .unusualProductivity: return "Great Progress"
            case .morningPlan: return "Morning Planning"
            case .eveningWrapup: return "Evening Wrap-up"
            }
        }

        var defaultIcon: String {
            switch self {
            case .stuckTask: return "arrow.triangle.2.circlepath"
            case .neglectedGoal: return "target"
            case .overduePile: return "exclamationmark.triangle.fill"
            case .cleanSlate: return "checkmark.circle.fill"
            case .birthdayReminder: return "gift.fill"
            case .streakMilestone: return "flame.fill"
            case .weeklyReviewTime: return "calendar.badge.clock"
            case .unusualProductivity: return "star.fill"
            case .morningPlan: return "sun.horizon.fill"
            case .eveningWrapup: return "moon.stars.fill"
            }
        }
    }

    enum Priority: Int, Comparable {
        case low = 0
        case medium = 1
        case high = 2
        case urgent = 3

        static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    static func == (lhs: ProactiveSuggestion, rhs: ProactiveSuggestion) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Proactive Suggestion Service

/// Service for generating and managing proactive AI suggestions
/// Evaluates trigger conditions and respects user preferences
@MainActor
class ProactiveSuggestionService: ObservableObject {

    // MARK: - Singleton
    static let shared = ProactiveSuggestionService()

    // MARK: - Published Properties
    @Published private(set) var currentSuggestion: ProactiveSuggestion?
    @Published private(set) var suggestionHistory: [ProactiveSuggestion] = []

    // MARK: - Dependencies
    private let dataService: DataService
    private let contextService: ContextService

    // MARK: - Configuration
    private let maxSuggestionsPerDay = 2
    private let quietHoursStart = 22  // 10 PM
    private let quietHoursEnd = 7     // 7 AM
    private let stuckTaskThreshold = 3
    private let neglectedGoalDays = 5
    private let overduePileThreshold = 5

    // MARK: - State
    private var dismissedSuggestionIds: Set<String> {
        get {
            Set(UserDefaults.standard.stringArray(forKey: "dismissedProactiveSuggestions") ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "dismissedProactiveSuggestions")
        }
    }

    private var snoozedSuggestions: [String: Date] {
        get {
            let data = UserDefaults.standard.data(forKey: "snoozedProactiveSuggestions") ?? Data()
            return (try? JSONDecoder().decode([String: Date].self, from: data)) ?? [:]
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "snoozedProactiveSuggestions")
            }
        }
    }

    private var suggestionsShownToday: Int {
        get {
            let lastDate = UserDefaults.standard.object(forKey: "lastSuggestionDate") as? Date
            let count = UserDefaults.standard.integer(forKey: "suggestionsShownToday")

            // Reset count if it's a new day
            if let lastDate = lastDate, !Calendar.current.isDateInToday(lastDate) {
                return 0
            }
            return count
        }
        set {
            UserDefaults.standard.set(Date(), forKey: "lastSuggestionDate")
            UserDefaults.standard.set(newValue, forKey: "suggestionsShownToday")
        }
    }

    // MARK: - Initialization
    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    // MARK: - Public Methods

    /// Evaluate all trigger conditions and return the highest priority suggestion
    func evaluateSuggestions() async -> ProactiveSuggestion? {
        // Check rate limiting
        guard suggestionsShownToday < maxSuggestionsPerDay else {
            print("ProactiveSuggestionService: Daily limit reached")
            return nil
        }

        // Check quiet hours
        guard !isQuietHours() else {
            print("ProactiveSuggestionService: Quiet hours active")
            return nil
        }

        // Evaluate all triggers and collect suggestions
        var suggestions: [ProactiveSuggestion] = []

        // High priority triggers
        if let suggestion = await checkOverduePile() {
            suggestions.append(suggestion)
        }

        if let suggestion = await checkStuckTasks() {
            suggestions.append(suggestion)
        }

        // Medium priority triggers
        if let suggestion = await checkCleanSlate() {
            suggestions.append(suggestion)
        }

        if let suggestion = await checkNeglectedGoals() {
            suggestions.append(suggestion)
        }

        // Low priority triggers
        if let suggestion = checkWeeklyReviewTime() {
            suggestions.append(suggestion)
        }

        if let suggestion = checkMorningPlan() {
            suggestions.append(suggestion)
        }

        if let suggestion = checkEveningWrapup() {
            suggestions.append(suggestion)
        }

        // Filter out dismissed and snoozed
        let filtered = suggestions.filter { !isSuggestionSuppressed($0) }

        // Return highest priority
        let sorted = filtered.sorted { $0.priority > $1.priority }
        if let best = sorted.first {
            currentSuggestion = best
            return best
        }

        return nil
    }

    /// Dismiss a suggestion permanently (for this trigger instance)
    func dismissSuggestion(_ suggestion: ProactiveSuggestion) {
        let key = suggestionKey(for: suggestion)
        dismissedSuggestionIds.insert(key)
        suggestionsShownToday += 1

        if currentSuggestion?.id == suggestion.id {
            currentSuggestion = nil
        }

        // Track dismissal for learning
        trackSuggestionInteraction(suggestion, action: .dismissed)

        print("ProactiveSuggestionService: Dismissed suggestion '\(suggestion.type.rawValue)'")
    }

    /// Snooze a suggestion for a specified duration
    func snoozeSuggestion(_ suggestion: ProactiveSuggestion, for hours: Int = 4) {
        let key = suggestionKey(for: suggestion)
        let snoozeUntil = Calendar.current.date(byAdding: .hour, value: hours, to: Date()) ?? Date()
        snoozedSuggestions[key] = snoozeUntil

        if currentSuggestion?.id == suggestion.id {
            currentSuggestion = nil
        }

        // Track snooze for learning
        trackSuggestionInteraction(suggestion, action: .snoozed)

        print("ProactiveSuggestionService: Snoozed suggestion '\(suggestion.type.rawValue)' until \(snoozeUntil)")
    }

    /// User engaged with the suggestion (tapped action)
    func engageWithSuggestion(_ suggestion: ProactiveSuggestion) {
        suggestionsShownToday += 1
        suggestionHistory.append(suggestion)

        if currentSuggestion?.id == suggestion.id {
            currentSuggestion = nil
        }

        // Track engagement for learning
        trackSuggestionInteraction(suggestion, action: .engaged)

        print("ProactiveSuggestionService: User engaged with suggestion '\(suggestion.type.rawValue)'")
    }

    /// Clear current suggestion without counting toward daily limit
    func clearCurrentSuggestion() {
        currentSuggestion = nil
    }

    /// Reset daily counters (call at midnight or app launch on new day)
    func resetDailyCounters() {
        let lastDate = UserDefaults.standard.object(forKey: "lastSuggestionDate") as? Date
        if let lastDate = lastDate, !Calendar.current.isDateInToday(lastDate) {
            suggestionsShownToday = 0

            // Clear old snoozed items
            var snoozes = snoozedSuggestions
            let now = Date()
            snoozes = snoozes.filter { $0.value > now }
            snoozedSuggestions = snoozes
        }
    }

    // MARK: - Trigger Evaluators

    /// Check for stuck tasks (rescheduled 3+ times)
    private func checkStuckTasks() async -> ProactiveSuggestion? {
        do {
            let allTasks = try dataService.fetchAllTasks()
            let stuckTasks = allTasks.filter { $0.isStuck }

            guard !stuckTasks.isEmpty else { return nil }

            // Get the most stuck task
            let mostStuck = stuckTasks.sorted { $0.rescheduleCount > $1.rescheduleCount }.first!

            return ProactiveSuggestion(
                id: UUID(),
                type: .stuckTask,
                title: "Stuck Task Detected",
                message: "'\(mostStuck.title)' has been rescheduled \(mostStuck.rescheduleCount) times. Would you like to break it down or remove it?",
                suggestedAction: "Help me break down '\(mostStuck.title)' into smaller tasks",
                icon: ProactiveSuggestion.SuggestionType.stuckTask.defaultIcon,
                priority: .high,
                createdAt: Date(),
                relatedTaskIds: [mostStuck.id],
                metadata: ["taskTitle": mostStuck.title, "rescheduleCount": "\(mostStuck.rescheduleCount)"]
            )
        } catch {
            print("ProactiveSuggestionService: Failed to check stuck tasks: \(error)")
            return nil
        }
    }

    /// Check for overdue pile (5+ overdue tasks)
    private func checkOverduePile() async -> ProactiveSuggestion? {
        do {
            let overdueTasks = try dataService.fetchOverdueTasks()

            guard overdueTasks.count >= overduePileThreshold else { return nil }

            return ProactiveSuggestion(
                id: UUID(),
                type: .overduePile,
                title: "Overdue Tasks Piling Up",
                message: "You have \(overdueTasks.count) overdue tasks. Let's triage them together.",
                suggestedAction: "Help me clean up my overdue tasks",
                icon: ProactiveSuggestion.SuggestionType.overduePile.defaultIcon,
                priority: .urgent,
                createdAt: Date(),
                relatedTaskIds: overdueTasks.map { $0.id },
                metadata: ["overdueCount": "\(overdueTasks.count)"]
            )
        } catch {
            print("ProactiveSuggestionService: Failed to check overdue pile: \(error)")
            return nil
        }
    }

    /// Check for clean slate (all today's tasks completed)
    private func checkCleanSlate() async -> ProactiveSuggestion? {
        do {
            let todayTasks = try dataService.fetchTodayTasks()

            // Must have at least 3 tasks and all completed
            guard todayTasks.count >= 3 else { return nil }

            let allCompleted = todayTasks.allSatisfy { $0.isCompleted }
            guard allCompleted else { return nil }

            return ProactiveSuggestion(
                id: UUID(),
                type: .cleanSlate,
                title: "All Done! 🎉",
                message: "You've completed all \(todayTasks.count) tasks for today. Great work!",
                suggestedAction: "What should I focus on tomorrow?",
                icon: ProactiveSuggestion.SuggestionType.cleanSlate.defaultIcon,
                priority: .medium,
                createdAt: Date(),
                relatedTaskIds: todayTasks.map { $0.id },
                metadata: ["completedCount": "\(todayTasks.count)"]
            )
        } catch {
            print("ProactiveSuggestionService: Failed to check clean slate: \(error)")
            return nil
        }
    }

    /// Check for neglected goals (no related tasks completed in 5+ days)
    private func checkNeglectedGoals() async -> ProactiveSuggestion? {
        do {
            let goals = try contextService.fetchAllContext(category: .goal, minConfidence: 0.3)

            for goal in goals {
                // Check if goal hasn't been accessed in neglectedGoalDays
                if goal.daysSinceAccess >= neglectedGoalDays {
                    return ProactiveSuggestion(
                        id: UUID(),
                        type: .neglectedGoal,
                        title: "Goal Reminder",
                        message: "You haven't worked on '\(goal.key)' in \(goal.daysSinceAccess) days. Want to add a task for it?",
                        suggestedAction: "Add a task related to \(goal.key)",
                        icon: ProactiveSuggestion.SuggestionType.neglectedGoal.defaultIcon,
                        priority: .medium,
                        createdAt: Date(),
                        relatedTaskIds: [],
                        metadata: ["goalKey": goal.key, "daysSinceAccess": "\(goal.daysSinceAccess)"]
                    )
                }
            }
            return nil
        } catch {
            print("ProactiveSuggestionService: Failed to check neglected goals: \(error)")
            return nil
        }
    }

    /// Check if it's Sunday evening (weekly review time)
    private func checkWeeklyReviewTime() -> ProactiveSuggestion? {
        let calendar = Calendar.current
        let now = Date()
        let weekday = calendar.component(.weekday, from: now)
        let hour = calendar.component(.hour, from: now)

        // Sunday (weekday == 1) between 5 PM and 8 PM
        guard weekday == 1 && hour >= 17 && hour <= 20 else { return nil }

        return ProactiveSuggestion(
            id: UUID(),
            type: .weeklyReviewTime,
            title: "Weekly Review Time",
            message: "It's Sunday evening - a great time to review your week and plan ahead.",
            suggestedAction: "How was my week?",
            icon: ProactiveSuggestion.SuggestionType.weeklyReviewTime.defaultIcon,
            priority: .low,
            createdAt: Date(),
            relatedTaskIds: [],
            metadata: [:]
        )
    }

    /// Check if it's morning planning time
    private func checkMorningPlan() -> ProactiveSuggestion? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Between 7 AM and 9 AM
        guard hour >= 7 && hour <= 9 else { return nil }

        // Only suggest if not already planned today (check if we have today's tasks)
        do {
            let todayTasks = try dataService.fetchTodayTasks()
            // If no tasks for today, suggest planning
            guard todayTasks.filter({ !$0.isCompleted }).isEmpty else { return nil }

            return ProactiveSuggestion(
                id: UUID(),
                type: .morningPlan,
                title: "Good Morning!",
                message: "Ready to plan your day? Let me help you organize your tasks.",
                suggestedAction: "Plan my day",
                icon: ProactiveSuggestion.SuggestionType.morningPlan.defaultIcon,
                priority: .low,
                createdAt: Date(),
                relatedTaskIds: [],
                metadata: [:]
            )
        } catch {
            return nil
        }
    }

    /// Check if it's evening wrap-up time
    private func checkEveningWrapup() -> ProactiveSuggestion? {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: Date())

        // Between 7 PM and 9 PM
        guard hour >= 19 && hour <= 21 else { return nil }

        do {
            let todayTasks = try dataService.fetchTodayTasks()
            let incomplete = todayTasks.filter { !$0.isCompleted }

            // Only suggest if there are incomplete tasks
            guard incomplete.count >= 2 else { return nil }

            return ProactiveSuggestion(
                id: UUID(),
                type: .eveningWrapup,
                title: "Evening Wrap-up",
                message: "You have \(incomplete.count) tasks remaining. Want to reschedule them for tomorrow?",
                suggestedAction: "Move today's incomplete tasks to tomorrow",
                icon: ProactiveSuggestion.SuggestionType.eveningWrapup.defaultIcon,
                priority: .low,
                createdAt: Date(),
                relatedTaskIds: incomplete.map { $0.id },
                metadata: ["incompleteCount": "\(incomplete.count)"]
            )
        } catch {
            return nil
        }
    }

    // MARK: - Helper Methods

    private func isQuietHours() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour >= quietHoursStart || hour < quietHoursEnd
    }

    private func suggestionKey(for suggestion: ProactiveSuggestion) -> String {
        // Create a key based on type and related data so similar suggestions are grouped
        let dateKey = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        switch suggestion.type {
        case .stuckTask:
            return "\(suggestion.type.rawValue)_\(suggestion.relatedTaskIds.first?.uuidString ?? "")_\(dateKey)"
        case .overduePile, .cleanSlate:
            return "\(suggestion.type.rawValue)_\(dateKey)"
        case .neglectedGoal:
            return "\(suggestion.type.rawValue)_\(suggestion.metadata["goalKey"] ?? "")_\(dateKey)"
        case .weeklyReviewTime, .morningPlan, .eveningWrapup:
            return "\(suggestion.type.rawValue)_\(dateKey)"
        default:
            return "\(suggestion.type.rawValue)_\(dateKey)"
        }
    }

    private func isSuggestionSuppressed(_ suggestion: ProactiveSuggestion) -> Bool {
        let key = suggestionKey(for: suggestion)

        // Check if dismissed
        if dismissedSuggestionIds.contains(key) {
            return true
        }

        // Check if snoozed
        if let snoozeUntil = snoozedSuggestions[key], snoozeUntil > Date() {
            return true
        }

        return false
    }

    // MARK: - Analytics/Learning

    enum SuggestionAction: String {
        case dismissed
        case snoozed
        case engaged
    }

    private func trackSuggestionInteraction(_ suggestion: ProactiveSuggestion, action: SuggestionAction) {
        // Track for future learning - store in UserDefaults for now
        let key = "suggestionStats_\(suggestion.type.rawValue)"
        var stats = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] ?? [:]

        stats[action.rawValue, default: 0] += 1
        UserDefaults.standard.set(stats, forKey: key)

        print("ProactiveSuggestionService: Tracked \(action.rawValue) for \(suggestion.type.rawValue)")
    }

    /// Get engagement rate for a suggestion type (for future personalization)
    func getEngagementRate(for type: ProactiveSuggestion.SuggestionType) -> Double {
        let key = "suggestionStats_\(type.rawValue)"
        guard let stats = UserDefaults.standard.dictionary(forKey: key) as? [String: Int] else {
            return 0.5 // Default 50% assumed engagement
        }

        let engaged = stats["engaged"] ?? 0
        let dismissed = stats["dismissed"] ?? 0
        let snoozed = stats["snoozed"] ?? 0
        let total = engaged + dismissed + snoozed

        guard total > 0 else { return 0.5 }

        return Double(engaged) / Double(total)
    }
}
