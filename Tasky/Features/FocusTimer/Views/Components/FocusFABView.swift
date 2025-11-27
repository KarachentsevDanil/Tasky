//
//  FocusFABView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI
internal import CoreData

/// Floating Action Button for Focus Timer
/// Displays different states: idle (play), active for this task (pause + time), active for other task (swap)
struct FocusFABView: View {

    // MARK: - Properties
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let task: TaskEntity
    @Binding var showFullTimer: Bool

    // MARK: - Private State
    @State private var showSwitchTaskConfirmation = false

    // MARK: - Constants
    private enum Layout {
        static let fabSize: CGFloat = 60
        static let iconSizeActive: CGFloat = 14
        static let iconSizeSwap: CGFloat = 20
        static let iconSizePlay: CGFloat = 22
        static let timerFontSize: CGFloat = 10
    }

    // MARK: - Computed Properties

    /// Timer is active for THIS task
    private var isTimerActiveForThisTask: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }

    /// Timer is active for a DIFFERENT task
    private var isTimerActiveForOtherTask: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id != task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }

    /// Name of the task currently being focused (for switch confirmation)
    private var currentFocusTaskName: String {
        timerViewModel.currentTask?.title ?? "another task"
    }

    private var fabBackgroundColor: Color {
        if isTimerActiveForThisTask {
            return .orange
        } else if isTimerActiveForOtherTask {
            return Color(.systemGray)
        } else {
            return .accentColor
        }
    }

    private var fabAccessibilityLabel: String {
        if isTimerActiveForThisTask {
            return "Focus timer active, \(timerViewModel.formattedTime) remaining"
        } else if isTimerActiveForOtherTask {
            return "Focus timer running for \(currentFocusTaskName)"
        } else {
            return "Start focus timer"
        }
    }

    private var fabAccessibilityHint: String {
        if isTimerActiveForThisTask {
            return "Double tap to view timer"
        } else if isTimerActiveForOtherTask {
            return "Double tap to switch focus to this task"
        } else {
            return "Double tap to start 25 minute focus session"
        }
    }

    // MARK: - Body
    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            if isTimerActiveForThisTask {
                // Show timer for this task
                showFullTimer = true
            } else if isTimerActiveForOtherTask {
                // Ask to switch tasks
                showSwitchTaskConfirmation = true
            } else {
                // Start fresh timer
                timerViewModel.startTimer(for: task)
                showFullTimer = true
            }
        } label: {
            ZStack {
                Circle()
                    .fill(fabBackgroundColor)
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)

                if isTimerActiveForThisTask {
                    // Timer running for this task
                    VStack(spacing: 0) {
                        Image(systemName: "pause.fill")
                            .font(.system(size: Layout.iconSizeActive, weight: .bold))
                        Text(timerViewModel.formattedTime)
                            .font(.system(size: Layout.timerFontSize, weight: .semibold).monospacedDigit())
                    }
                    .foregroundStyle(.white)
                } else if isTimerActiveForOtherTask {
                    // Timer running for another task - show swap icon
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: Layout.iconSizeSwap, weight: .semibold))
                        .foregroundStyle(.white)
                } else {
                    // Idle - show play
                    Image(systemName: "play.fill")
                        .font(.system(size: Layout.iconSizePlay, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: Layout.fabSize, height: Layout.fabSize)
        }
        .buttonStyle(.plain)
        .padding(.trailing, Constants.Spacing.lg)
        .padding(.bottom, Constants.Spacing.lg)
        .accessibilityLabel(fabAccessibilityLabel)
        .accessibilityHint(fabAccessibilityHint)
        .confirmationDialog(
            "Switch Focus?",
            isPresented: $showSwitchTaskConfirmation,
            titleVisibility: .visible
        ) {
            Button("Switch to \(task.title)") {
                timerViewModel.stopTimer()
                timerViewModel.startTimer(for: task)
                showFullTimer = true
            }

            Button("View Current Timer") {
                showFullTimer = true
            }

            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You're currently focusing on \"\(currentFocusTaskName)\". Do you want to switch?")
        }
    }
}

// MARK: - Preview

#Preview("Idle State") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()

        VStack {
            Spacer()
            HStack {
                Spacer()
                FocusFABView(
                    timerViewModel: FocusTimerViewModel(),
                    task: {
                        let context = PersistenceController.preview.viewContext
                        let task = TaskEntity(context: context)
                        task.id = UUID()
                        task.title = "Review code"
                        task.isCompleted = false
                        task.createdAt = Date()
                        return task
                    }(),
                    showFullTimer: .constant(false)
                )
            }
        }
    }
}
