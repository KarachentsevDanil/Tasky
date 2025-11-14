//
//  FocusTimerFullView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 13.11.2025.
//

import SwiftUI
internal import CoreData

/// Full-screen focus timer view with Pomodoro functionality
struct FocusTimerFullView: View {
    @ObservedObject var viewModel: FocusTimerViewModel
    let task: TaskEntity
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                // Animated background gradient
                LinearGradient(
                    colors: [
                        timerColor.opacity(viewModel.timerState == .running ? 0.08 : 0.05),
                        Color(.systemBackground)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.8), value: viewModel.timerState)

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(height: 24)

                        // Task title and session type
                        VStack(spacing: 16) {
                            Text(task.title)
                                .font(.title2.weight(.bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .padding(.horizontal, 32)
                                .foregroundStyle(.primary)

                            // Session type badge
                            HStack(spacing: 8) {
                                Image(systemName: viewModel.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                                    .font(.caption)
                                Text(viewModel.sessionType)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(timerColor)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(timerColor.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(timerColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .shadow(color: timerColor.opacity(0.2), radius: 8, y: 4)
                        }

                        // Progress Ring with enhanced visuals
                        ZStack {
                            // Pulsing outer glow (only when running)
                            if viewModel.timerState == .running {
                                Circle()
                                    .stroke(timerColor.opacity(0.2), lineWidth: 24)
                                    .blur(radius: 12)
                                    .scaleEffect(1.05)
                                    .opacity(viewModel.timerState == .running ? 1 : 0)
                                    .animation(
                                        reduceMotion ? .none : .easeInOut(duration: 2)
                                            .repeatForever(autoreverses: true),
                                        value: viewModel.timerState
                                    )
                            }

                            // Background ring
                            Circle()
                                .stroke(
                                    Color(.systemGray5),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )

                            // Progress ring
                            Circle()
                                .trim(from: 0, to: viewModel.progress)
                                .stroke(
                                    LinearGradient(
                                        colors: [timerColor, timerColor.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 20, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .shadow(color: timerColor.opacity(0.4), radius: 10, x: 0, y: 6)
                                .animation(reduceMotion ? .none : .linear(duration: 1), value: viewModel.progress)

                            // Inner content
                            VStack(spacing: 12) {
                                // Timer text
                                Text(viewModel.formattedTime)
                                    .font(.system(size: 76, weight: .bold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [timerColor, timerColor.opacity(0.75)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .scaleEffect(viewModel.timerState == .running ? 1.0 : 0.95)
                                    .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.timerState)

                                // State indicator
                                if viewModel.timerState == .paused {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 8, height: 8)
                                        Text("Paused")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .transition(.opacity.combined(with: .scale))
                                }
                            }
                        }
                        .frame(width: 320, height: 320)
                        .padding(.vertical, 16)

                        // Controls
                        HStack(spacing: 28) {
                            // Stop Button
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

                            // Play/Pause Button
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
                                        // Animated glow
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

                                        // Main button
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [timerColor, timerColor.opacity(0.85)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 96, height: 96)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        LinearGradient(
                                                            colors: [.white.opacity(0.3), .clear],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        lineWidth: 2
                                                    )
                                            )
                                            .shadow(color: timerColor.opacity(0.4), radius: 16, y: 8)

                                        // Icon
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

                            // Skip Break Button
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

                        // Stats
                        if !viewModel.isBreak {
                            VStack(spacing: 20) {
                                Capsule()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 60, height: 4)
                                    .padding(.top, 8)

                                HStack(spacing: 24) {
                                    // Total Focus Time
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.blue.opacity(0.15), Color.blue.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)
                                                .overlay(Circle().stroke(Color.blue.opacity(0.2), lineWidth: 1))
                                            Image(systemName: "clock.fill")
                                                .font(.title2)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.blue, .blue.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        VStack(spacing: 4) {
                                            Text(task.formattedFocusTime)
                                                .font(.title2.weight(.bold))
                                                .monospacedDigit()
                                            Text("Total Focus")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.secondarySystemBackground))
                                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                    )

                                    // Sessions Completed
                                    VStack(spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [Color.green.opacity(0.15), Color.green.opacity(0.08)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 56, height: 56)
                                                .overlay(Circle().stroke(Color.green.opacity(0.2), lineWidth: 1))
                                            Image(systemName: "target")
                                                .font(.title2)
                                                .foregroundStyle(
                                                    LinearGradient(
                                                        colors: [.green, .green.opacity(0.8)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                        }
                                        VStack(spacing: 4) {
                                            if let sessions = task.focusSessions as? Set<FocusSessionEntity> {
                                                Text("\(sessions.filter { $0.completed }.count)")
                                                    .font(.title2.weight(.bold))
                                            } else {
                                                Text("0")
                                                    .font(.title2.weight(.bold))
                                            }
                                            Text("Sessions")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color(.secondarySystemBackground))
                                            .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                                    )
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 12)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var timerColor: Color {
        if viewModel.isBreak {
            return .green
        }
        switch viewModel.timerState {
        case .idle: return .blue
        case .running: return .orange
        case .paused: return .yellow
        case .completed: return .green
        }
    }

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
#Preview("Idle Timer") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.priority = 2

    return FocusTimerFullView(viewModel: vm, task: task, onDismiss: {})
}

#Preview("Running Timer") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Complete code review"
    task.priority = 1
    vm.startTimer(for: task)

    return FocusTimerFullView(viewModel: vm, task: task, onDismiss: {})
}

#Preview("Break Time") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Take a break"
    task.priority = 0

    return FocusTimerFullView(viewModel: vm, task: task, onDismiss: {})
}
