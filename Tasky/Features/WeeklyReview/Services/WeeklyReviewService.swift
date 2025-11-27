//
//  WeeklyReviewService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Combine
import Foundation
import UserNotifications

/// Service for managing weekly review scheduling and streak tracking
@MainActor
final class WeeklyReviewService: ObservableObject {

    // MARK: - Singleton
    static let shared = WeeklyReviewService()

    // MARK: - Published Properties
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var lastReviewDate: Date?
    @Published private(set) var nextScheduledReview: Date?

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let reviewEnabled = "weeklyReviewEnabled"
        static let reviewDay = "weeklyReviewDay"
        static let reviewHour = "weeklyReviewHour"
        static let streak = "weeklyReviewStreak"
        static let lastReviewDate = "lastWeeklyReviewDate"
        static let longestStreak = "weeklyReviewLongestStreak"
    }

    // MARK: - Properties
    private let defaults = UserDefaults.standard
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - Computed Properties

    /// Whether weekly review reminders are enabled
    var isEnabled: Bool {
        get { defaults.bool(forKey: Keys.reviewEnabled) }
        set {
            defaults.set(newValue, forKey: Keys.reviewEnabled)
            if newValue {
                scheduleNextReviewNotification()
            } else {
                cancelReviewNotification()
            }
        }
    }

    /// Day of week for review (1 = Sunday, 7 = Saturday)
    var reviewDay: Int {
        get { defaults.integer(forKey: Keys.reviewDay).clamped(to: 1...7) }
        set {
            defaults.set(newValue.clamped(to: 1...7), forKey: Keys.reviewDay)
            updateNextScheduledReview()
            scheduleNextReviewNotification()
        }
    }

    /// Hour for review (0-23)
    var reviewHour: Int {
        get { defaults.integer(forKey: Keys.reviewHour).clamped(to: 0...23) }
        set {
            defaults.set(newValue.clamped(to: 0...23), forKey: Keys.reviewHour)
            updateNextScheduledReview()
            scheduleNextReviewNotification()
        }
    }

    /// Longest streak ever achieved
    var longestStreak: Int {
        get { defaults.integer(forKey: Keys.longestStreak) }
        set { defaults.set(newValue, forKey: Keys.longestStreak) }
    }

    /// Day name for display
    var reviewDayName: String {
        let days = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return days[reviewDay]
    }

    /// Formatted review time
    var reviewTimeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = reviewHour
        components.minute = 0
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(reviewHour):00"
    }

    // MARK: - Initialization
    private init() {
        // Set defaults if not already set
        if defaults.object(forKey: Keys.reviewEnabled) == nil {
            defaults.set(true, forKey: Keys.reviewEnabled)
        }
        if defaults.object(forKey: Keys.reviewDay) == nil {
            defaults.set(1, forKey: Keys.reviewDay) // Sunday
        }
        if defaults.object(forKey: Keys.reviewHour) == nil {
            defaults.set(18, forKey: Keys.reviewHour) // 6 PM
        }

        loadState()
        updateNextScheduledReview()
    }

    // MARK: - State Management

    private func loadState() {
        currentStreak = defaults.integer(forKey: Keys.streak)

        if let timestamp = defaults.object(forKey: Keys.lastReviewDate) as? Double {
            lastReviewDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func saveState() {
        defaults.set(currentStreak, forKey: Keys.streak)

        if let date = lastReviewDate {
            defaults.set(date.timeIntervalSince1970, forKey: Keys.lastReviewDate)
        }
    }

    // MARK: - Review Completion

    /// Call when user completes a weekly review
    func completeReview() {
        let now = Date()
        let calendar = Calendar.current

        // Check if this continues the streak or resets it
        if let lastDate = lastReviewDate {
            let daysSinceLastReview = calendar.dateComponents([.day], from: lastDate, to: now).day ?? 0

            if daysSinceLastReview <= 7 {
                // Continuing streak
                currentStreak += 1
            } else {
                // Streak broken, start fresh
                currentStreak = 1
            }
        } else {
            // First review ever
            currentStreak = 1
        }

        // Update longest streak if needed
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }

        lastReviewDate = now
        saveState()
        updateNextScheduledReview()
        scheduleNextReviewNotification()

        print("Weekly review completed. Streak: \(currentStreak)")
    }

    /// Check if user missed a week (streak should be reset)
    func checkStreakStatus() {
        guard let lastDate = lastReviewDate else { return }

        let daysSinceLastReview = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0

        if daysSinceLastReview > 14 {
            // More than 2 weeks since last review, reset streak
            currentStreak = 0
            saveState()
        }
    }

    // MARK: - Scheduling

    private func updateNextScheduledReview() {
        let calendar = Calendar.current
        let now = Date()

        // Find next occurrence of reviewDay at reviewHour
        var components = DateComponents()
        components.weekday = reviewDay
        components.hour = reviewHour
        components.minute = 0

        if let nextDate = calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        ) {
            nextScheduledReview = nextDate
        }
    }

    // MARK: - Notifications

    private let notificationIdentifier = "com.tasky.weeklyReview"

    func scheduleNextReviewNotification() {
        guard isEnabled else { return }

        // Cancel existing notification
        cancelReviewNotification()

        // Create new notification
        let content = UNMutableNotificationContent()
        content.title = "Weekly Review Time"
        content.body = "Take a few minutes to reflect on your week and plan ahead."
        content.sound = .default
        content.categoryIdentifier = "WEEKLY_REVIEW"

        // Create trigger for weekly review time
        var dateComponents = DateComponents()
        dateComponents.weekday = reviewDay
        dateComponents.hour = reviewHour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to schedule weekly review notification: \(error)")
            } else {
                print("Weekly review notification scheduled for \(self.reviewDayName) at \(self.reviewTimeFormatted)")
            }
        }
    }

    func cancelReviewNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
    }

    // MARK: - Review Data

    /// Get summary data for the completed week
    func getWeekSummary(dataService: DataService) async throws -> WeekReviewData {
        let calendar = Calendar.current
        let now = Date()

        // Calculate week boundaries (previous Sunday to Saturday)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!

        // Fetch data
        let completedThisWeek = try dataService.fetchTasksCompletedBetween(start: weekStart, end: weekEnd)
        let createdThisWeek = try dataService.fetchTasksCreatedBetween(start: weekStart, end: weekEnd)
        let overdueTasks = try dataService.fetchOverdueTasks()

        // Calculate incomplete tasks (created this week, not completed)
        let allTasks = try dataService.fetchAllTasks()
        let incompleteTasks = allTasks.filter { task in
            !task.isCompleted &&
            !task.isOverdue &&
            (task.dueDate == nil || calendar.isDate(task.dueDate!, inSameDayAs: now) || task.dueDate! > now)
        }

        // Calculate focus time
        let focusSessions = try dataService.fetchFocusSessions(from: weekStart, to: weekEnd)
        let totalFocusSeconds = focusSessions.reduce(0) { $0 + Int($1.duration) }

        // Calculate upcoming tasks (next week)
        let nextWeekStart = weekEnd
        let nextWeekEnd = calendar.date(byAdding: .day, value: 7, to: nextWeekStart)!
        let upcomingTasks = allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= nextWeekStart && dueDate < nextWeekEnd && !task.isCompleted
        }

        return WeekReviewData(
            weekStart: weekStart,
            weekEnd: weekEnd,
            completedTasks: completedThisWeek,
            incompleteTasks: incompleteTasks,
            overdueTasks: overdueTasks,
            upcomingTasks: upcomingTasks,
            createdCount: createdThisWeek.count,
            totalFocusSeconds: totalFocusSeconds,
            currentStreak: currentStreak
        )
    }
}

// MARK: - Week Review Data Model
struct WeekReviewData {
    let weekStart: Date
    let weekEnd: Date
    let completedTasks: [TaskEntity]
    let incompleteTasks: [TaskEntity]
    let overdueTasks: [TaskEntity]
    let upcomingTasks: [TaskEntity]
    let createdCount: Int
    let totalFocusSeconds: Int
    let currentStreak: Int

    var completedCount: Int { completedTasks.count }
    var incompleteCount: Int { incompleteTasks.count }
    var overdueCount: Int { overdueTasks.count }
    var upcomingCount: Int { upcomingTasks.count }

    var completionRate: Int {
        let total = completedCount + incompleteCount + overdueCount
        guard total > 0 else { return 0 }
        return Int(Double(completedCount) / Double(total) * 100)
    }

    var formattedFocusTime: String {
        let hours = totalFocusSeconds / 3600
        let minutes = (totalFocusSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var weekRangeFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
}

// MARK: - Int Extension
private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
