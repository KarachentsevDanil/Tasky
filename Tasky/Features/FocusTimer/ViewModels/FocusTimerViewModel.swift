//
//  FocusTimerViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
import Combine
import AudioToolbox
import ActivityKit
internal import CoreData

/// ViewModel for managing focus timer (Pomodoro technique)
@MainActor
class FocusTimerViewModel: ObservableObject {

    // MARK: - Singleton
    static let shared = FocusTimerViewModel()

    // MARK: - Published Properties
    @Published var isTimerSheetPresented: Bool = false
    @Published var timerState: TimerState = .idle
    @Published var remainingSeconds: Int = 25 * 60 // 25 minutes default
    @Published var currentTask: TaskEntity?
    @Published var isBreak: Bool = false
    @Published var currentSessionNumber: Int = 1
    @Published var targetSessionCount: Int = 4
    @Published var showStopConfirmation: Bool = false
    @Published var dailyStreak: Int = 0

    // MARK: - Properties
    private let dataService: DataService
    private let liveActivityManager = LiveActivityManager.shared
    private var timerCancellable: AnyCancellable?
    private var sessionStartTime: Date?
    private var focusDuration: Int = 25 * 60  // 25 minutes
    private var breakDuration: Int = 5 * 60   // 5 minutes
    private var hasPlayedFiveMinWarning = false
    private var hasPlayedOneMinWarning = false

    // MARK: - Settings
    @UserDefault(key: "focusDuration", defaultValue: 25)
    private var focusDurationMinutes: Int

    @UserDefault(key: "breakDuration", defaultValue: 5)
    private var breakDurationMinutes: Int

    @UserDefault(key: "timerSoundEnabled", defaultValue: true)
    private var soundEnabled: Bool

    @UserDefault(key: "targetSessions", defaultValue: 4)
    private var storedTargetSessions: Int

    @UserDefault(key: "lastFocusDate", defaultValue: "")
    private var lastFocusDateString: String

    @UserDefault(key: "currentStreak", defaultValue: 0)
    private var storedStreak: Int

    // MARK: - Timer States
    enum TimerState {
        case idle
        case running
        case paused
        case completed
    }

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
        self.focusDuration = focusDurationMinutes * 60
        self.breakDuration = breakDurationMinutes * 60
        self.remainingSeconds = focusDuration
        self.targetSessionCount = storedTargetSessions
        loadStreak()
    }

    // MARK: - Streak Management

    private func loadStreak() {
        let today = formatDate(Date())
        let yesterday = formatDate(Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date())

        if lastFocusDateString == today {
            // Already focused today, keep streak
            dailyStreak = storedStreak
        } else if lastFocusDateString == yesterday {
            // Focused yesterday, streak continues
            dailyStreak = storedStreak
        } else {
            // Streak broken
            dailyStreak = 0
            storedStreak = 0
        }
    }

    private func updateStreak() {
        let today = formatDate(Date())

        if lastFocusDateString != today {
            // First session of the day
            dailyStreak += 1
            storedStreak = dailyStreak
            lastFocusDateString = today
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Timer Control

    /// Start timer for a specific task
    func startTimer(for task: TaskEntity) {
        guard timerState == .idle || timerState == .completed else { return }

        currentTask = task
        isBreak = false
        remainingSeconds = focusDuration
        sessionStartTime = Date()
        timerState = .running
        hasPlayedFiveMinWarning = false
        hasPlayedOneMinWarning = false

        startTimerPublisher()
        HapticManager.shared.mediumImpact()

        // Start ambient sound
        AudioManager.shared.startForSession()

        // Start Live Activity (Dynamic Island) and schedule notification
        Task { @MainActor in
            await liveActivityManager.startActivity(
                taskTitle: task.title,
                totalDuration: focusDuration,
                isBreak: false,
                currentSession: currentSessionNumber,
                targetSessions: targetSessionCount
            )

            try? await NotificationManager.shared.scheduleTimerNotification(
                sessionType: "Focus",
                duration: TimeInterval(focusDuration)
            )
        }
    }

    /// Start break timer
    func startBreak() {
        isBreak = true
        remainingSeconds = breakDuration
        sessionStartTime = Date()
        timerState = .running

        startTimerPublisher()
        HapticManager.shared.lightImpact()

        // Continue ambient sound during break
        AudioManager.shared.resumeForSession()

        // Update Live Activity for break (Dynamic Island) and schedule notification
        Task { @MainActor in
            await liveActivityManager.startActivity(
                taskTitle: currentTask?.title ?? "Break Time",
                totalDuration: breakDuration,
                isBreak: true,
                currentSession: currentSessionNumber,
                targetSessions: targetSessionCount
            )

            try? await NotificationManager.shared.scheduleTimerNotification(
                sessionType: "Break",
                duration: TimeInterval(breakDuration)
            )
        }
    }

    /// Pause the timer
    func pauseTimer() {
        guard timerState == .running else { return }

        timerState = .paused
        timerCancellable?.cancel()
        HapticManager.shared.lightImpact()

        // Pause ambient sound
        AudioManager.shared.pauseForSession()

        // Update Live Activity to show paused state
        updateLiveActivity(isPaused: true)
    }

    /// Resume the timer
    func resumeTimer() {
        guard timerState == .paused else { return }

        timerState = .running
        startTimerPublisher()
        HapticManager.shared.lightImpact()

        // Resume ambient sound
        AudioManager.shared.resumeForSession()

        // Update Live Activity to show running state
        updateLiveActivity(isPaused: false)
    }

    /// Stop the timer and save session
    func stopTimer() {
        guard timerState == .running || timerState == .paused else { return }

        // Calculate elapsed time
        let elapsed = (isBreak ? breakDuration : focusDuration) - remainingSeconds

        // Save focus session if it was a focus period (not break)
        if !isBreak, let task = currentTask, elapsed > 60 {
            Task {
                await saveFocusSession(task: task, duration: elapsed)
            }
        }

        // Cancel timer notifications
        Task { @MainActor in
            await NotificationManager.shared.cancelAllTimerNotifications()
        }

        // End Live Activity (Dynamic Island) - immediate dismissal
        Task { @MainActor in
            await liveActivityManager.endActivity(dismissed: true)
        }

        // Stop ambient sound
        AudioManager.shared.stopForSession()

        resetTimer()
        HapticManager.shared.mediumImpact()
    }

    /// Reset timer to initial state
    func resetTimer() {
        timerCancellable?.cancel()
        timerState = .idle
        remainingSeconds = focusDuration
        currentTask = nil
        isBreak = false
        sessionStartTime = nil

        // Stop ambient sound
        AudioManager.shared.stopForSession()

        // End Live Activity (Dynamic Island) - immediate dismissal
        Task { @MainActor in
            await liveActivityManager.endActivity(dismissed: true)
        }

        // Cancel timer notifications on reset
        Task { @MainActor in
            await NotificationManager.shared.cancelAllTimerNotifications()
        }
    }

    // MARK: - Private Methods

    private func startTimerPublisher() {
        timerCancellable?.cancel()

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }

                Task { @MainActor in
                    if self.remainingSeconds > 0 {
                        self.remainingSeconds -= 1
                        self.checkForWarningHaptics()

                        // Update Live Activity every second for real-time display
                        self.updateLiveActivity(isPaused: false)
                    } else {
                        await self.completeTimer()
                    }
                }
            }
    }

    /// Update Live Activity with current state
    private func updateLiveActivity(isPaused: Bool) {
        let totalDuration = isBreak ? breakDuration : focusDuration
        liveActivityManager.updateActivity(
            remainingSeconds: remainingSeconds,
            isBreak: isBreak,
            isPaused: isPaused,
            currentSession: currentSessionNumber,
            targetSessions: targetSessionCount,
            totalDuration: totalDuration
        )
    }

    private func checkForWarningHaptics() {
        // 5-minute warning (only for focus sessions, not breaks)
        if !isBreak && remainingSeconds == 5 * 60 && !hasPlayedFiveMinWarning {
            hasPlayedFiveMinWarning = true
            HapticManager.shared.lightImpact()
        }

        // 1-minute warning
        if remainingSeconds == 60 && !hasPlayedOneMinWarning {
            hasPlayedOneMinWarning = true
            HapticManager.shared.mediumImpact()
        }

        // 10-second countdown haptics
        if remainingSeconds <= 10 && remainingSeconds > 0 {
            HapticManager.shared.selectionChanged()
        }
    }

    private func completeTimer() async {
        timerCancellable?.cancel()
        timerState = .completed

        // Haptic and sound feedback
        HapticManager.shared.success()
        if soundEnabled {
            playCompletionSound()
        }

        // Save focus session if it was a focus period
        if !isBreak, let task = currentTask {
            let duration = focusDuration
            await saveFocusSession(task: task, duration: duration)

            // Update streak on completed focus session
            updateStreak()
        }

        // Auto-transition to break or reset
        if !isBreak {
            // Completed focus - offer break
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if timerState == .completed {
                // Increment session counter after break transition
                if currentSessionNumber < targetSessionCount {
                    currentSessionNumber += 1
                }
                startBreak()
            }
        } else {
            // Completed break - check if more sessions needed
            if currentSessionNumber >= targetSessionCount {
                // All sessions complete
                currentSessionNumber = 1
            }
            resetTimer()
        }
    }

    private func saveFocusSession(task: TaskEntity, duration: Int) async {
        guard let context = task.managedObjectContext else { return }

        // Use objectID pattern for thread safety
        let taskID = task.objectID
        let sessionStart = self.sessionStartTime ?? Date()

        await context.perform {
            guard let task = try? context.existingObject(with: taskID) as? TaskEntity else {
                return
            }

            // Create focus session
            let session = FocusSessionEntity(context: context)
            session.id = UUID()
            session.startTime = sessionStart
            session.duration = Int32(duration)
            session.completed = true
            session.task = task

            // Update task's total focus time
            task.focusTimeSeconds += Int32(duration)

            do {
                try context.save()
            } catch {
                print("Error saving focus session: \(error)")
            }
        }
    }

    private func playCompletionSound() {
        // Play system sound
        #if os(iOS)
        AudioServicesPlaySystemSound(1005) // Tock sound
        #endif
    }

    // MARK: - Computed Properties

    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var progress: Double {
        let total = isBreak ? Double(breakDuration) : Double(focusDuration)
        return 1.0 - (Double(remainingSeconds) / total)
    }

    var sessionType: String {
        isBreak ? "Break" : "Focus"
    }

    /// Total duration in MM:SS format
    var totalDurationFormatted: String {
        let total = isBreak ? breakDuration : focusDuration
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    /// Session progress text (e.g., "Session 2 of 4")
    var sessionProgressText: String {
        "Session \(currentSessionNumber) of \(targetSessionCount)"
    }

    /// Current focus duration in minutes
    var currentFocusDurationMinutes: Int {
        focusDuration / 60
    }

    /// Current break duration in minutes
    var currentBreakDurationMinutes: Int {
        breakDuration / 60
    }

    /// Check if sound is enabled
    var isSoundEnabled: Bool {
        soundEnabled
    }

    // MARK: - Extend Time

    /// Extend the current timer by a specified number of minutes
    func extendTime(by minutes: Int) {
        guard timerState == .running || timerState == .paused else { return }

        let additionalSeconds = minutes * 60
        remainingSeconds += additionalSeconds

        // Also extend the total duration for accurate progress calculation
        if isBreak {
            breakDuration += additionalSeconds
        } else {
            focusDuration += additionalSeconds
        }

        HapticManager.shared.lightImpact()

        // Update Live Activity with new duration
        updateLiveActivity(isPaused: timerState == .paused)

        // Reschedule notification with extended time
        Task { @MainActor in
            await NotificationManager.shared.cancelAllTimerNotifications()
            try? await NotificationManager.shared.scheduleTimerNotification(
                sessionType: sessionType,
                duration: TimeInterval(remainingSeconds)
            )
        }
    }

    // MARK: - Session Target

    /// Update the target number of sessions
    func updateTargetSessions(_ count: Int) {
        let validCount = max(1, min(count, 12))
        targetSessionCount = validCount
        storedTargetSessions = validCount
    }

    // MARK: - Duration Presets

    /// Available focus duration presets in minutes
    static let focusDurationPresets = [15, 25, 30, 45, 50, 60, 90]

    /// Available break duration presets in minutes
    static let breakDurationPresets = [5, 10, 15, 20]

    // MARK: - Settings

    func updateFocusDuration(minutes: Int) {
        focusDurationMinutes = minutes
        focusDuration = minutes * 60
        if timerState == .idle {
            remainingSeconds = focusDuration
        }
    }

    func updateBreakDuration(minutes: Int) {
        breakDurationMinutes = minutes
        breakDuration = minutes * 60
    }

    func toggleSound() {
        soundEnabled.toggle()
    }

    /// Request stop confirmation
    func requestStop() {
        showStopConfirmation = true
        HapticManager.shared.lightImpact()
    }

    /// Confirm and execute stop
    func confirmStop() {
        showStopConfirmation = false
        stopTimer()
    }

    /// Cancel stop request
    func cancelStop() {
        showStopConfirmation = false
    }
}
