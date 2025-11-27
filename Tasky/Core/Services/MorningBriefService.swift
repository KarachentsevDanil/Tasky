//
//  MorningBriefService.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 27.11.2025.
//

import Combine
import Foundation
import UserNotifications

/// Service for managing Morning Brief functionality
@MainActor
class MorningBriefService: ObservableObject {

    // MARK: - Singleton
    static let shared = MorningBriefService()

    // MARK: - Published Properties
    @Published var briefData: MorningBriefData?
    @Published var isLoading = false

    // MARK: - Properties
    private let dataService: DataService
    private let notificationCenter = UNUserNotificationCenter.current()

    // MARK: - User Defaults Keys
    private enum Keys {
        static let morningBriefEnabled = "morningBriefEnabled"
        static let morningBriefHour = "morningBriefHour"
        static let morningBriefMinute = "morningBriefMinute"
        static let lastBriefReviewedDate = "lastBriefReviewedDate"
        static let weekendBriefHour = "weekendBriefHour"
        static let weekendBriefMinute = "weekendBriefMinute"
        static let useWeekendTime = "useWeekendBriefTime"
    }

    // MARK: - Settings
    var isBriefEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.morningBriefEnabled) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.morningBriefEnabled)
            if newValue {
                Task { await scheduleMorningBriefNotification() }
            } else {
                cancelMorningBriefNotification()
            }
        }
    }

    var briefHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: Keys.morningBriefHour)
            return hour == 0 ? 7 : hour // Default 7 AM
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.morningBriefHour)
            Task { await scheduleMorningBriefNotification() }
        }
    }

    var briefMinute: Int {
        get { UserDefaults.standard.integer(forKey: Keys.morningBriefMinute) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.morningBriefMinute)
            Task { await scheduleMorningBriefNotification() }
        }
    }

    var weekendBriefHour: Int {
        get {
            let hour = UserDefaults.standard.integer(forKey: Keys.weekendBriefHour)
            return hour == 0 ? 9 : hour // Default 9 AM for weekends
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.weekendBriefHour)
            Task { await scheduleMorningBriefNotification() }
        }
    }

    var weekendBriefMinute: Int {
        get { UserDefaults.standard.integer(forKey: Keys.weekendBriefMinute) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.weekendBriefMinute)
            Task { await scheduleMorningBriefNotification() }
        }
    }

    var useWeekendTime: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.useWeekendTime) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.useWeekendTime)
            Task { await scheduleMorningBriefNotification() }
        }
    }

    var briefTime: Date {
        get {
            var components = DateComponents()
            components.hour = briefHour
            components.minute = briefMinute
            return Calendar.current.date(from: components) ?? Date()
        }
        set {
            let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
            briefHour = components.hour ?? 7
            briefMinute = components.minute ?? 0
        }
    }

    // MARK: - Initialization
    private init(dataService: DataService = DataService()) {
        self.dataService = dataService

        // Set defaults if first launch
        if !UserDefaults.standard.bool(forKey: "morningBriefDefaultsSet") {
            UserDefaults.standard.set(true, forKey: Keys.morningBriefEnabled)
            UserDefaults.standard.set(7, forKey: Keys.morningBriefHour)
            UserDefaults.standard.set(0, forKey: Keys.morningBriefMinute)
            UserDefaults.standard.set(true, forKey: "morningBriefDefaultsSet")
        }
    }

    // MARK: - Brief Data Generation

    /// Generate morning brief data
    func generateBriefData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch today's tasks
            let todayTasks = try dataService.fetchTodayTasks()
            let incompleteTasks = todayTasks.filter { !$0.isCompleted }

            // Get top 3 focus tasks (highest AI priority)
            let focusTasks = incompleteTasks
                .sorted { $0.aiPriorityScore > $1.aiPriorityScore }
                .prefix(3)
                .map { task in
                    BriefTask(
                        id: task.id,
                        title: task.title,
                        priority: Int(task.priority),
                        scheduledTime: task.scheduledTime,
                        listName: task.taskList?.name
                    )
                }

            // Get overdue count
            let overdueTasks = try dataService.fetchOverdueTasks()
            let overdueCount = overdueTasks.count

            // Get high priority pending tasks count
            let highPriorityTasks = try dataService.fetchHighPriorityPendingTasks()
            let highPriorityCount = highPriorityTasks.count

            // Calculate schedule overview
            let scheduledTasks = incompleteTasks.filter { $0.scheduledTime != nil }
            let scheduleOverview = generateScheduleOverview(from: scheduledTasks)

            // Generate greeting based on time of day
            let greeting = generateGreeting()

            briefData = MorningBriefData(
                greeting: greeting,
                totalTasksToday: incompleteTasks.count,
                focusTasks: Array(focusTasks),
                overdueCount: overdueCount,
                highPriorityCount: highPriorityCount,
                scheduleOverview: scheduleOverview,
                generatedAt: Date()
            )
        } catch {
            print("❌ Failed to generate morning brief: \(error)")
            briefData = nil
        }
    }

    /// Generate greeting based on time of day
    private func generateGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            return "Good morning!"
        case 12..<17:
            return "Good afternoon!"
        case 17..<21:
            return "Good evening!"
        default:
            return "Hello!"
        }
    }

    /// Generate schedule overview from scheduled tasks
    private func generateScheduleOverview(from tasks: [TaskEntity]) -> [ScheduleBlock] {
        let sortedTasks = tasks.sorted { ($0.scheduledTime ?? Date()) < ($1.scheduledTime ?? Date()) }

        return sortedTasks.prefix(5).compactMap { task in
            guard let startTime = task.scheduledTime else { return nil }

            return ScheduleBlock(
                taskTitle: task.title,
                startTime: startTime,
                endTime: task.scheduledEndTime,
                isHighPriority: task.priority >= 2
            )
        }
    }

    // MARK: - Brief Review Tracking

    /// Check if brief should be shown (first open of day)
    func shouldShowBrief() -> Bool {
        guard isBriefEnabled else { return false }

        let lastReviewed = UserDefaults.standard.object(forKey: Keys.lastBriefReviewedDate) as? Date

        if let lastReviewed = lastReviewed {
            // Check if it's a new day
            return !Calendar.current.isDateInToday(lastReviewed)
        }

        // Never reviewed, show brief
        return true
    }

    /// Mark brief as reviewed
    func markBriefAsReviewed() {
        UserDefaults.standard.set(Date(), forKey: Keys.lastBriefReviewedDate)
    }

    /// Skip brief for today
    func skipBriefForToday() {
        markBriefAsReviewed()
    }

    // MARK: - Notification Scheduling

    /// Schedule the morning brief notification
    func scheduleMorningBriefNotification() async {
        guard isBriefEnabled else {
            cancelMorningBriefNotification()
            return
        }

        // Remove existing notifications
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morning-brief"])

        let content = UNMutableNotificationContent()
        content.title = "☀️ Your Morning Brief"
        content.body = "Review your day and start focused"
        content.sound = .default
        content.categoryIdentifier = "MORNING_BRIEF"
        content.userInfo = ["type": "morning-brief"]

        // Create trigger for daily notification
        var dateComponents = DateComponents()

        let isWeekend = isCurrentDayWeekend()
        if useWeekendTime && isWeekend {
            dateComponents.hour = weekendBriefHour
            dateComponents.minute = weekendBriefMinute
        } else {
            dateComponents.hour = briefHour
            dateComponents.minute = briefMinute
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "morning-brief", content: content, trigger: trigger)

        do {
            try await notificationCenter.add(request)
            print("✅ Morning brief notification scheduled for \(dateComponents.hour ?? 7):\(String(format: "%02d", dateComponents.minute ?? 0))")
        } catch {
            print("❌ Failed to schedule morning brief: \(error)")
        }
    }

    /// Cancel the morning brief notification
    func cancelMorningBriefNotification() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: ["morning-brief"])
        print("✅ Morning brief notification cancelled")
    }

    /// Check if current day is weekend
    private func isCurrentDayWeekend() -> Bool {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }

    // MARK: - Notification Summary Text

    /// Generate notification summary for brief
    func generateNotificationSummary() async -> String {
        do {
            let todayTasks = try dataService.fetchTodayTasks()
            let incompleteTasks = todayTasks.filter { !$0.isCompleted }
            let overdueCount = try dataService.fetchOverdueTasks().count

            var summary = "\(incompleteTasks.count) tasks today"
            if overdueCount > 0 {
                summary += ", \(overdueCount) overdue"
            }

            if let topTask = incompleteTasks.sorted(by: { $0.aiPriorityScore > $1.aiPriorityScore }).first {
                summary += ". Top: \(topTask.title)"
            }

            return summary
        } catch {
            return "Tap to see your daily brief"
        }
    }
}

// MARK: - Brief Data Models

struct MorningBriefData: Identifiable {
    let id = UUID()
    let greeting: String
    let totalTasksToday: Int
    let focusTasks: [BriefTask]
    let overdueCount: Int
    let highPriorityCount: Int
    let scheduleOverview: [ScheduleBlock]
    let generatedAt: Date

    var hasOverdueTasks: Bool {
        overdueCount > 0
    }

    var isEmpty: Bool {
        totalTasksToday == 0 && overdueCount == 0
    }
}

struct BriefTask: Identifiable {
    let id: UUID
    let title: String
    let priority: Int
    let scheduledTime: Date?
    let listName: String?
}

struct ScheduleBlock: Identifiable {
    let id = UUID()
    let taskTitle: String
    let startTime: Date
    let endTime: Date?
    let isHighPriority: Bool

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if let endTime = endTime {
            return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
        }
        return formatter.string(from: startTime)
    }
}
