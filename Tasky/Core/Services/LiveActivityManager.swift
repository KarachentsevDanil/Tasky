//
//  LiveActivityManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import Foundation
import ActivityKit

/// Manager for Focus Timer Live Activities (Dynamic Island support)
@MainActor
final class LiveActivityManager {

    // MARK: - Singleton
    static let shared = LiveActivityManager()

    // MARK: - Properties
    private var currentActivity: Activity<FocusTimerActivityAttributes>?

    // MARK: - Initialization
    private init() {}

    // MARK: - Public Methods

    /// Check if Live Activities are supported and enabled
    var areActivitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Start a new Live Activity for the focus timer
    /// - Parameters:
    ///   - taskTitle: The title of the task being focused on
    ///   - totalDuration: Total duration in seconds
    ///   - isBreak: Whether this is a break session
    ///   - currentSession: Current session number
    ///   - targetSessions: Total target sessions
    func startActivity(
        taskTitle: String,
        totalDuration: Int,
        isBreak: Bool,
        currentSession: Int,
        targetSessions: Int
    ) async {
        // End any existing activity first
        await endActivity()

        #if DEBUG
        print("🔵 Live Activities enabled: \(areActivitiesEnabled)")
        print("🔵 Starting Live Activity for task: \(taskTitle)")
        #endif

        guard areActivitiesEnabled else {
            #if DEBUG
            print("❌ Live Activities are disabled - cannot start activity")
            #endif
            return
        }

        let attributes = FocusTimerActivityAttributes(
            taskTitle: taskTitle,
            totalDuration: totalDuration,
            startTime: Date()
        )

        let initialState = FocusTimerActivityAttributes.ContentState(
            remainingSeconds: totalDuration,
            isBreak: isBreak,
            isPaused: false,
            currentSession: currentSession,
            targetSessions: targetSessions,
            progress: 0.0
        )

        let content = ActivityContent(
            state: initialState,
            staleDate: Date().addingTimeInterval(TimeInterval(totalDuration + 60))
        )

        do {
            currentActivity = try Activity<FocusTimerActivityAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
            #if DEBUG
            print("✅ Live Activity started successfully: \(currentActivity?.id ?? "unknown")")
            #endif
        } catch {
            #if DEBUG
            print("❌ Error starting Live Activity: \(error.localizedDescription)")
            print("❌ Error details: \(error)")
            #endif
        }
    }

    /// Update the Live Activity with new state
    /// - Parameters:
    ///   - remainingSeconds: Remaining time in seconds
    ///   - isBreak: Whether this is a break session
    ///   - isPaused: Whether the timer is paused
    ///   - currentSession: Current session number
    ///   - targetSessions: Total target sessions
    ///   - totalDuration: Total duration for calculating progress
    func updateActivity(
        remainingSeconds: Int,
        isBreak: Bool,
        isPaused: Bool,
        currentSession: Int,
        targetSessions: Int,
        totalDuration: Int
    ) {
        guard let activity = currentActivity else { return }

        let progress = 1.0 - (Double(remainingSeconds) / Double(totalDuration))

        let updatedState = FocusTimerActivityAttributes.ContentState(
            remainingSeconds: remainingSeconds,
            isBreak: isBreak,
            isPaused: isPaused,
            currentSession: currentSession,
            targetSessions: targetSessions,
            progress: max(0, min(1, progress))
        )

        let content = ActivityContent(
            state: updatedState,
            staleDate: Date().addingTimeInterval(TimeInterval(remainingSeconds + 60))
        )

        Task {
            await activity.update(content)
        }
    }

    /// End the current Live Activity
    /// - Parameter dismissed: Whether the activity was dismissed by the user
    func endActivity(dismissed: Bool = false) async {
        guard let activity = currentActivity else { return }

        let finalState = FocusTimerActivityAttributes.ContentState(
            remainingSeconds: 0,
            isBreak: false,
            isPaused: false,
            currentSession: 1,
            targetSessions: 4,
            progress: 1.0
        )

        let content = ActivityContent(
            state: finalState,
            staleDate: Date()
        )

        await activity.end(content, dismissalPolicy: dismissed ? .immediate : .default)
        currentActivity = nil
    }

    /// End all active Focus Timer activities
    func endAllActivities() async {
        for activity in Activity<FocusTimerActivityAttributes>.activities {
            let finalState = FocusTimerActivityAttributes.ContentState(
                remainingSeconds: 0,
                isBreak: false,
                isPaused: false,
                currentSession: 1,
                targetSessions: 4,
                progress: 1.0
            )

            let content = ActivityContent(
                state: finalState,
                staleDate: Date()
            )

            await activity.end(content, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }

    /// Check if there's an active Live Activity
    var hasActiveActivity: Bool {
        currentActivity != nil
    }
}
