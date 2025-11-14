//
//  NotificationManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
import UserNotifications
import Combine

/// Manager for handling local notifications
@MainActor
class NotificationManager: NSObject, ObservableObject {

    // MARK: - Singleton
    static let shared = NotificationManager()

    // MARK: - Published Properties
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined

    // MARK: - Properties
    private let center = UNUserNotificationCenter.current()

    // MARK: - Notification Categories
    private enum Category: String {
        case task = "TASK_NOTIFICATION"
        case timer = "TIMER_NOTIFICATION"
    }

    // MARK: - Notification Actions
    private enum Action: String {
        case complete = "COMPLETE_ACTION"
        case snooze = "SNOOZE_ACTION"
        case startFocus = "START_FOCUS_ACTION"
    }

    // MARK: - Initialization
    private override init() {
        super.init()
        center.delegate = self
        setupNotificationCategories()
        Task {
            await checkAuthorizationStatus()
        }
    }

    // MARK: - Authorization

    /// Request notification permissions
    func requestAuthorization() async throws {
        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        await checkAuthorizationStatus()

        if granted {
            print("✅ Notifications authorized")
        } else {
            print("❌ Notifications denied")
        }
    }

    /// Check current authorization status
    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    // MARK: - Task Notifications

    /// Schedule notification for a task
    func scheduleTaskNotification(taskId: UUID, title: String, date: Date, isScheduledTime: Bool = false) async throws {
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard authorizationStatus == .authorized else {
            print("❌ Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = isScheduledTime ? "Scheduled Task" : "Task Due"
        content.body = title
        content.sound = .default
        content.categoryIdentifier = Category.task.rawValue
        content.userInfo = ["taskId": taskId.uuidString, "type": "task"]

        // Calculate time interval
        let timeInterval = date.timeIntervalSinceNow
        guard timeInterval > 0 else {
            print("⚠️ Notification date is in the past")
            return
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let identifier = "task-\(taskId.uuidString)-\(isScheduledTime ? "scheduled" : "due")"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        print("✅ Task notification scheduled: \(title) at \(date)")
    }

    /// Schedule notification 15 minutes before task due date
    func scheduleTaskReminderNotification(taskId: UUID, title: String, dueDate: Date) async throws {
        let reminderDate = Calendar.current.date(byAdding: .minute, value: -15, to: dueDate) ?? dueDate

        guard reminderDate > Date() else {
            print("⚠️ Reminder date is in the past")
            return
        }

        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard authorizationStatus == .authorized else {
            print("❌ Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Task Reminder"
        content.body = "\(title) is due in 15 minutes"
        content.sound = .default
        content.categoryIdentifier = Category.task.rawValue
        content.userInfo = ["taskId": taskId.uuidString, "type": "reminder"]

        let timeInterval = reminderDate.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let identifier = "task-\(taskId.uuidString)-reminder"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        print("✅ Task reminder scheduled: \(title) at \(reminderDate)")
    }

    /// Cancel all notifications for a specific task
    func cancelTaskNotifications(taskId: UUID) {
        let identifiers = [
            "task-\(taskId.uuidString)-due",
            "task-\(taskId.uuidString)-scheduled",
            "task-\(taskId.uuidString)-reminder"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        print("✅ Cancelled notifications for task: \(taskId)")
    }

    // MARK: - Timer Notifications

    /// Schedule notification for timer completion
    func scheduleTimerNotification(sessionType: String, duration: TimeInterval) async throws {
        // Request authorization if needed
        if authorizationStatus == .notDetermined {
            try await requestAuthorization()
        }

        guard authorizationStatus == .authorized else {
            print("❌ Notifications not authorized")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "\(sessionType) Complete!"
        content.body = sessionType == "Focus" ?
            "Great work! Time for a break." :
            "Break's over! Ready to focus?"
        content.sound = .default
        content.categoryIdentifier = Category.timer.rawValue
        content.userInfo = ["type": "timer", "sessionType": sessionType]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: duration, repeats: false)
        let identifier = "timer-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await center.add(request)
        print("✅ Timer notification scheduled: \(sessionType) for \(duration)s")
    }

    /// Cancel all timer notifications
    func cancelAllTimerNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let timerIdentifiers = pending
            .filter { $0.identifier.starts(with: "timer-") }
            .map { $0.identifier }

        center.removePendingNotificationRequests(withIdentifiers: timerIdentifiers)
        print("✅ Cancelled all timer notifications")
    }

    // MARK: - Utility

    /// Cancel all pending notifications
    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
        print("✅ Cancelled all pending notifications")
    }

    /// Get count of pending notifications
    func getPendingNotificationCount() async -> Int {
        let pending = await center.pendingNotificationRequests()
        return pending.count
    }

    /// List all pending notifications (for debugging)
    func listPendingNotifications() async {
        let pending = await center.pendingNotificationRequests()
        print("📋 Pending notifications: \(pending.count)")
        for request in pending {
            print("  - \(request.identifier): \(request.content.title)")
        }
    }

    // MARK: - Notification Categories Setup

    private func setupNotificationCategories() {
        // Task notification actions
        let completeAction = UNNotificationAction(
            identifier: Action.complete.rawValue,
            title: "Complete",
            options: [.foreground]
        )

        let snoozeAction = UNNotificationAction(
            identifier: Action.snooze.rawValue,
            title: "Snooze 15m",
            options: []
        )

        let taskCategory = UNNotificationCategory(
            identifier: Category.task.rawValue,
            actions: [completeAction, snoozeAction],
            intentIdentifiers: [],
            options: []
        )

        // Timer notification actions
        let startFocusAction = UNNotificationAction(
            identifier: Action.startFocus.rawValue,
            title: "Start Focus",
            options: [.foreground]
        )

        let timerCategory = UNNotificationCategory(
            identifier: Category.timer.rawValue,
            actions: [startFocusAction],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([taskCategory, timerCategory])
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {

    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        switch response.actionIdentifier {
        case Action.complete.rawValue:
            handleCompleteAction(userInfo: userInfo)

        case Action.snooze.rawValue:
            handleSnoozeAction(userInfo: userInfo)

        case Action.startFocus.rawValue:
            handleStartFocusAction(userInfo: userInfo)

        case UNNotificationDefaultActionIdentifier:
            // User tapped the notification
            handleNotificationTap(userInfo: userInfo)

        default:
            break
        }

        completionHandler()
    }

    // MARK: - Action Handlers

    private func handleCompleteAction(userInfo: [AnyHashable: Any]) {
        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }

        print("📝 Complete action for task: \(taskId)")
        // Post notification for app to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("CompleteTaskFromNotification"),
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }

    private func handleSnoozeAction(userInfo: [AnyHashable: Any]) {
        guard let taskIdString = userInfo["taskId"] as? String,
              let taskId = UUID(uuidString: taskIdString) else {
            return
        }

        print("⏰ Snooze action for task: \(taskId)")
        // Post notification for app to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("SnoozeTaskFromNotification"),
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }

    private func handleStartFocusAction(userInfo: [AnyHashable: Any]) {
        print("🎯 Start focus action")
        // Post notification for app to handle
        NotificationCenter.default.post(
            name: NSNotification.Name("StartFocusFromNotification"),
            object: nil
        )
    }

    private func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        if let taskIdString = userInfo["taskId"] as? String,
           let taskId = UUID(uuidString: taskIdString) {
            print("👆 Task notification tapped: \(taskId)")
            // Post notification for app to navigate to task
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenTaskFromNotification"),
                object: nil,
                userInfo: ["taskId": taskId]
            )
        } else if userInfo["type"] as? String == "timer" {
            print("👆 Timer notification tapped")
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenTimerFromNotification"),
                object: nil
            )
        }
    }
}
