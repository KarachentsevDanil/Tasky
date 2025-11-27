//
//  FocusTimerSheet.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI
internal import CoreData

/// Full-screen focus timer view with polished Pomodoro UI
struct FocusTimerSheet: View {

    // MARK: - Properties
    @ObservedObject var viewModel: FocusTimerViewModel
    @StateObject private var audioManager = AudioManager.shared
    let task: TaskEntity
    @State private var showSettings = false
    @State private var showStatistics = false
    @State private var showSoundPicker = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body
    var body: some View {
        ZStack {
            // Warm gradient background
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom toolbar
                customToolbar
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Task info section
                        taskInfoSection
                            .padding(.top, 16)

                        // Progress ring
                        FocusTimerProgressRing(
                            viewModel: viewModel,
                            timerColor: timerColor
                        )

                        // Controls
                        controlsSection
                            .padding(.top, 8)

                        // Extend time option
                        if viewModel.timerState == .running || viewModel.timerState == .paused {
                            extendTimeButton
                                .padding(.top, 4)
                        }

                        // Streak Badge (only when streak exists)
                        if viewModel.dailyStreak > 0 {
                            streakBadge
                                .padding(.top, 16)
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            FocusTimerSettings(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showSoundPicker) {
            AmbientSoundPicker(audioManager: audioManager)
        }
        .sheet(isPresented: $showStatistics) {
            FocusStatisticsView()
        }
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        let isRunning = viewModel.timerState == .running

        return LinearGradient(
            colors: colorScheme == .dark ? [
                timerColor.opacity(isRunning ? 0.12 : 0.08),
                Color(.systemBackground)
            ] : [
                Color(red: 0.98, green: 0.96, blue: 0.93), // Warm cream
                timerColor.opacity(isRunning ? 0.08 : 0.04),
                Color(.systemBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .animation(reduceMotion ? .none : .easeInOut(duration: 0.8), value: viewModel.timerState)
    }

    // MARK: - Custom Toolbar

    private var customToolbar: some View {
        HStack {
            // Left toolbar group (pill shape)
            HStack(spacing: 16) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Settings")

                Button {
                    showSoundPicker = true
                } label: {
                    Image(systemName: soundButtonIcon)
                        .font(.body.weight(.medium))
                        .foregroundColor(audioManager.selectedSound != .none ? .orange : Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ambient Sound")

                Button {
                    showStatistics = true
                } label: {
                    Image(systemName: "chart.bar.fill")
                        .font(.body.weight(.medium))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Statistics")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )

            Spacer()

            // Close button
            Button {
                dismiss()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    Image(systemName: "xmark")
                        .font(.body.weight(.bold))
                        .foregroundColor(Color(.secondaryLabel))
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("Close")
        }
    }

    // MARK: - Task Info Section

    private var taskInfoSection: some View {
        VStack(spacing: 12) {
            // Task title
            Text(task.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(.primary)

            // Session counter
            Text(viewModel.sessionProgressText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Session type badge
            sessionTypeBadge
        }
    }

    private var sessionTypeBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: viewModel.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.caption.weight(.semibold))

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
                        .stroke(timerColor.opacity(0.25), lineWidth: 1)
                )
        )
    }

    // MARK: - Controls Section

    private var controlsSection: some View {
        HStack(spacing: 24) {
            // Stop Button (secondary)
            if viewModel.timerState != .idle {
                stopButton
            }

            // Play/Pause Button (primary)
            playPauseButton

            // Skip Break Button
            if viewModel.isBreak {
                skipButton
            }
        }
        .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.timerState)
        .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.isBreak)
    }

    private var stopButton: some View {
        Button {
            viewModel.requestStop()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.red)
                }

                Text("Stop")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
        .confirmationDialog(
            "Stop Session?",
            isPresented: $viewModel.showStopConfirmation,
            titleVisibility: .visible
        ) {
            Button("Stop & Save Progress", role: .destructive) {
                viewModel.confirmStop()
                dismiss()
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancelStop()
            }
        } message: {
            Text("Your progress will be saved. You can always start a new session.")
        }
    }

    private var playPauseButton: some View {
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
                        .opacity(viewModel.timerState == .running ? 0.6 : 0.4)
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
                        .shadow(color: timerColor.opacity(0.35), radius: 16, y: 8)

                    // Icon
                    Image(systemName: playPauseIcon)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white)
                        .scaleEffect(viewModel.timerState == .running ? 1.0 : 1.05)
                        .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.timerState)
                }

                Text(playPauseLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(timerColor)
            }
        }
        .buttonStyle(.plain)
    }

    private var skipButton: some View {
        Button {
            viewModel.resetTimer()
            dismiss()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 64, height: 64)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemGray4), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)

                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.orange)
                }

                Text("Skip")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Extend Time Button

    private var extendTimeButton: some View {
        Button {
            viewModel.extendTime(by: 5)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.subheadline)

                Text("Add 5 min")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(timerColor)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(timerColor.opacity(0.12))
            )
        }
        .buttonStyle(.plain)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    // MARK: - Streak Badge

    private var streakBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "flame.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.orange, .red],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Text("\(viewModel.dailyStreak) day streak")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    Capsule()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Computed Properties

    private var soundButtonIcon: String {
        if audioManager.isPlaying {
            return "speaker.wave.2.fill"
        } else if audioManager.selectedSound != .none {
            return "speaker.fill"
        } else {
            return "speaker.slash.fill"
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

    private var timerColor: Color {
        if viewModel.isBreak {
            return .green
        }
        switch viewModel.timerState {
        case .idle: return .orange
        case .running: return .orange
        case .paused: return .yellow
        case .completed: return .green
        }
    }
}

// MARK: - Preview

#Preview("Running Timer") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.isCompleted = false
    task.createdAt = Date()
    task.focusTimeSeconds = 1800

    let vm = FocusTimerViewModel.shared
    vm.startTimer(for: task)

    return FocusTimerSheet(viewModel: vm, task: task)
}

#Preview("Idle Timer") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Plan project roadmap"
    task.isCompleted = false
    task.createdAt = Date()

    return FocusTimerSheet(viewModel: FocusTimerViewModel(), task: task)
}
