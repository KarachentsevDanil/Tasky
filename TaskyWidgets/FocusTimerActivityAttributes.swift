//
//  FocusTimerActivityAttributes.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import Foundation
import ActivityKit

/// Attributes for Focus Timer Live Activity (Dynamic Island)
struct FocusTimerActivityAttributes: ActivityAttributes {

    /// Static content that doesn't change during the activity
    public struct ContentState: Codable, Hashable {
        /// Remaining time in seconds
        var remainingSeconds: Int

        /// Whether this is a break session
        var isBreak: Bool

        /// Timer state
        var isPaused: Bool

        /// Current session number (e.g., 2 of 4)
        var currentSession: Int

        /// Target session count
        var targetSessions: Int

        /// Progress from 0.0 to 1.0
        var progress: Double
    }

    /// Task title - static, doesn't change during activity
    var taskTitle: String

    /// Total duration in seconds for this session
    var totalDuration: Int

    /// Start time for the timer (used for countdown)
    var startTime: Date
}
