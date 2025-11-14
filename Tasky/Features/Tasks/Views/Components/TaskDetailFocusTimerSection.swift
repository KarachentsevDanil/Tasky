//
//  TaskDetailFocusTimerSection.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Focus timer section for task detail view
struct TaskDetailFocusTimerSection: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    @Binding var showFullTimer: Bool

    var body: some View {
        Section {
            // Timer Stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Focus Time")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(task.formattedFocusTime)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)

            // Timer Controls
            if isTimerActive {
                activeTimerView
            } else {
                startTimerButton
            }
        } header: {
            Text("Focus Timer")
        }
    }

    // MARK: - Active Timer View
    private var activeTimerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(timerViewModel.sessionType)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(timerViewModel.formattedTime)
                        .font(.system(.title, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(timerViewModel.timerState == .running ? .orange : .yellow)
                }
                Spacer()
                if timerViewModel.timerState == .paused {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Timer buttons
            HStack(spacing: 12) {
                Button {
                    timerViewModel.stopTimer()
                } label: {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)

                Button {
                    switch timerViewModel.timerState {
                    case .running:
                        timerViewModel.pauseTimer()
                    case .paused:
                        timerViewModel.resumeTimer()
                    default:
                        break
                    }
                } label: {
                    HStack {
                        Image(systemName: timerViewModel.timerState == .running ? "pause.fill" : "play.fill")
                        Text(timerViewModel.timerState == .running ? "Pause" : "Resume")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            // View full timer button
            Button {
                showFullTimer = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                    Text("Full Screen")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Start Timer Button
    private var startTimerButton: some View {
        Button {
            timerViewModel.startTimer(for: task)
        } label: {
            HStack {
                Image(systemName: "play.circle.fill")
                    .font(.title3)
                Text("Start Focus Session")
                    .font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
    }

    // MARK: - Computed Properties
    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

// MARK: - Preview
#Preview("Inactive Timer") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.focusTimeSeconds = 3600 // 1 hour

    return Form {
        TaskDetailFocusTimerSection(
            task: task,
            timerViewModel: FocusTimerViewModel(),
            showFullTimer: .constant(false)
        )
    }
}

#Preview("Active Timer") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.focusTimeSeconds = 3600

    let timerVM = FocusTimerViewModel()
    timerVM.startTimer(for: task)

    return Form {
        TaskDetailFocusTimerSection(
            task: task,
            timerViewModel: timerVM,
            showFullTimer: .constant(false)
        )
    }
}
