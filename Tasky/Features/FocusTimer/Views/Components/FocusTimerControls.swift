//
//  FocusTimerControls.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Timer control buttons (play/pause, stop, skip)
struct FocusTimerControls: View {
    let task: TaskEntity
    @ObservedObject var viewModel: FocusTimerViewModel
    let timerColor: Color
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack(spacing: 28) {
            // Stop Button (smaller, secondary)
            if viewModel.timerState != .idle {
                Button {
                    viewModel.stopTimer()
                    onDismiss()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )

                            Image(systemName: "stop.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.red)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                        Text("Stop")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }

            // Play/Pause Button (large, primary)
            Button {
                switch viewModel.timerState {
                case .idle, .completed:
                    viewModel.startTimer(for: task)
                case .running:
                    viewModel.pauseTimer()
                case .paused:
                    viewModel.resumeTimer()
                }
            } label: {
                VStack(spacing: 12) {
                    ZStack {
                        // Animated glow layer
                        Circle()
                            .fill(timerColor)
                            .frame(width: 96, height: 96)
                            .blur(radius: 24)
                            .opacity(viewModel.timerState == .running ? 0.7 : 0.5)
                            .scaleEffect(viewModel.timerState == .running ? 1.1 : 1.0)
                            .animation(
                                reduceMotion ? .none : (viewModel.timerState == .running ?
                                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true) :
                                    .easeInOut(duration: 0.3)),
                                value: viewModel.timerState
                            )

                        // Main button with gradient
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        timerColor,
                                        timerColor.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [
                                                .white.opacity(0.3),
                                                .clear
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: timerColor.opacity(0.4), radius: 16, y: 8)

                        // Icon with animation
                        Image(systemName: playPauseIcon)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(viewModel.timerState == .running ? 1.0 : 1.1)
                            .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.timerState)
                    }

                    Text(playPauseLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(timerColor)
                }
            }
            .buttonStyle(.plain)

            // Skip Break Button (smaller, secondary)
            if viewModel.isBreak {
                Button {
                    viewModel.resetTimer()
                    onDismiss()
                } label: {
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(Color(.systemGray6))
                                .frame(width: 64, height: 64)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.systemGray4), lineWidth: 1)
                                )

                            Image(systemName: "forward.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)

                        Text("Skip")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(
                    insertion: .scale.combined(with: .opacity),
                    removal: .scale.combined(with: .opacity)
                ))
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Computed Properties
    private var playPauseIcon: String {
        switch viewModel.timerState {
        case .idle, .completed:
            return "play.fill"
        case .running:
            return "pause.fill"
        case .paused:
            return "play.fill"
        }
    }

    private var playPauseLabel: String {
        switch viewModel.timerState {
        case .idle, .completed:
            return "Start"
        case .running:
            return "Pause"
        case .paused:
            return "Resume"
        }
    }
}

// MARK: - Preview
#Preview("Running Timer") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    vm.startTimer(for: task)

    return FocusTimerControls(
        task: task,
        viewModel: vm,
        timerColor: .orange,
        onDismiss: { print("Dismiss") }
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Idle Timer") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"

    return FocusTimerControls(
        task: task,
        viewModel: vm,
        timerColor: .blue,
        onDismiss: { print("Dismiss") }
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Break Time") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Take a break"
    vm.startTimer(for: task)

    return FocusTimerControls(
        task: task,
        viewModel: vm,
        timerColor: .green,
        onDismiss: { print("Dismiss") }
    )
    .padding()
    .background(Color(.systemBackground))
}
