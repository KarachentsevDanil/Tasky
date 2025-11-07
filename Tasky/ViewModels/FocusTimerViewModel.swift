//
//  FocusTimerViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
import Combine
import AudioToolbox
internal import CoreData

/// ViewModel for managing focus timer (Pomodoro technique)
@MainActor
class FocusTimerViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var timerState: TimerState = .idle
    @Published var remainingSeconds: Int = 25 * 60 // 25 minutes default
    @Published var currentTask: TaskEntity?
    @Published var isBreak: Bool = false

    // MARK: - Properties
    private let dataService: DataService
    private var timerCancellable: AnyCancellable?
    private var sessionStartTime: Date?
    private var focusDuration: Int = 25 * 60  // 25 minutes
    private var breakDuration: Int = 5 * 60   // 5 minutes

    // MARK: - Settings
    @UserDefault(key: "focusDuration", defaultValue: 25)
    private var focusDurationMinutes: Int

    @UserDefault(key: "breakDuration", defaultValue: 5)
    private var breakDurationMinutes: Int

    @UserDefault(key: "timerSoundEnabled", defaultValue: true)
    private var soundEnabled: Bool

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

        startTimerPublisher()
        HapticManager.shared.mediumImpact()

        // Schedule notification for timer completion
        Task { @MainActor in
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

        // Schedule notification for break completion
        Task { @MainActor in
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
    }

    /// Resume the timer
    func resumeTimer() {
        guard timerState == .paused else { return }

        timerState = .running
        startTimerPublisher()
        HapticManager.shared.lightImpact()
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
                    } else {
                        await self.completeTimer()
                    }
                }
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
        }

        // Auto-transition to break or reset
        if !isBreak {
            // Completed focus - offer break
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            if timerState == .completed {
                startBreak()
            }
        } else {
            // Completed break - reset
            resetTimer()
        }
    }

    private func saveFocusSession(task: TaskEntity, duration: Int) async {
        guard let context = task.managedObjectContext else { return }

        await context.perform {
            // Create focus session
            let session = FocusSessionEntity(context: context)
            session.id = UUID()
            session.startTime = self.sessionStartTime ?? Date()
            session.duration = Int32(duration)
            session.completed = true
            session.task = task

            // Update task's total focus time
            task.focusTimeSeconds += Int32(duration)

            try? context.save()
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
}
