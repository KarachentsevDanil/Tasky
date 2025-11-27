//
//  IntentDonationManager.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import AppIntents

/// Manages intent donations for Siri suggestions
@available(iOS 16.0, *)
struct IntentDonationManager {

    // MARK: - Donation Methods

    /// Donate an "Add Task" intent after user creates a task
    static func donateAddTask(title: String) {
        let intent = AddTaskIntent()
        intent.title = title
        // Donation happens automatically through AppIntents framework
    }

    /// Donate a "Complete Task" intent after user completes a task
    static func donateCompleteTask(title: String) {
        let intent = CompleteTaskIntent()
        intent.taskName = title
        // Donation happens automatically through AppIntents framework
    }

    /// Donate a "Show Today" intent when user views Today tab
    static func donateShowToday() {
        _ = ShowTodayIntent()
        // Donation happens automatically through AppIntents framework
    }
}

// MARK: - Convenience for Non-iOS 16

/// Wrapper for intent donation that handles availability
enum IntentDonation {

    static func donateTaskCreated(title: String) {
        if #available(iOS 16.0, *) {
            IntentDonationManager.donateAddTask(title: title)
        }
    }

    static func donateTaskCompleted(title: String) {
        if #available(iOS 16.0, *) {
            IntentDonationManager.donateCompleteTask(title: title)
        }
    }

    static func donateTodayViewed() {
        if #available(iOS 16.0, *) {
            IntentDonationManager.donateShowToday()
        }
    }
}
