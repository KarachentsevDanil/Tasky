//
//  ShowTodayIntent.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import AppIntents

/// App Intent for opening the Today view via Siri or Shortcuts
@available(iOS 16.0, *)
struct ShowTodayIntent: AppIntent {

    static var title: LocalizedStringResource = "Show Today's Tasks"

    static var description = IntentDescription("Open Tasky to see today's tasks")

    static var openAppWhenRun: Bool = true

    // MARK: - Perform

    func perform() async throws -> some IntentResult {
        // Post notification to navigate to Today view
        await MainActor.run {
            NotificationCenter.default.post(
                name: .navigateToToday,
                object: nil
            )
        }

        return .result()
    }
}

// MARK: - Navigation Notification

extension Notification.Name {
    static let navigateToToday = Notification.Name("navigateToToday")
    static let navigateToTask = Notification.Name("navigateToTask")
}
