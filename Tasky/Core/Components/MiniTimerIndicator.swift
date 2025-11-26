//
//  MiniTimerIndicator.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI
internal import CoreData

/// Floating pill indicator showing active focus timer, visible from any screen
struct MiniTimerIndicator: View {

    // MARK: - Properties
    @ObservedObject var viewModel: FocusTimerViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body
    var body: some View {
        Button {
            viewModel.isTimerSheetPresented = true
            HapticManager.shared.lightImpact()
        } label: {
            HStack(spacing: 10) {
                // Status indicator dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .fill(statusColor.opacity(0.4))
                            .frame(width: 16, height: 16)
                            .opacity(viewModel.timerState == .running ? 1 : 0)
                            .scaleEffect(viewModel.timerState == .running ? 1.5 : 1)
                            .animation(
                                reduceMotion ? .none : .easeInOut(duration: 1).repeatForever(autoreverses: true),
                                value: viewModel.timerState
                            )
                    )

                // Task name (truncated)
                if let taskTitle = viewModel.currentTask?.title {
                    Text(taskTitle)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }

                // Time remaining
                Text(viewModel.formattedTime)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(statusColor)

                // Play/Pause button
                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: playPauseIcon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            )
            .overlay(
                Capsule()
                    .stroke(statusColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to open full timer")
    }

    // MARK: - Computed Properties

    private var statusColor: Color {
        switch viewModel.timerState {
        case .running:
            return viewModel.isBreak ? .green : .orange
        case .paused:
            return .yellow
        case .idle, .completed:
            return .blue
        }
    }

    private var playPauseIcon: String {
        viewModel.timerState == .running ? "pause.fill" : "play.fill"
    }

    private var accessibilityDescription: String {
        let taskName = viewModel.currentTask?.title ?? "Focus"
        let state = viewModel.timerState == .running ? "Running" : "Paused"
        return "\(taskName), \(viewModel.formattedTime) remaining, \(state)"
    }

    // MARK: - Actions

    private func togglePlayPause() {
        if viewModel.timerState == .running {
            viewModel.pauseTimer()
        } else if viewModel.timerState == .paused {
            viewModel.resumeTimer()
        }
        HapticManager.shared.lightImpact()
    }
}

// MARK: - Preview

#Preview("Running Timer") {
    let vm = FocusTimerViewModel.shared
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation for the new feature"
    vm.startTimer(for: task)

    return VStack {
        MiniTimerIndicator(viewModel: vm)
        Spacer()
    }
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}

#Preview("Paused Timer") {
    let vm = FocusTimerViewModel.shared
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Review pull requests"
    vm.startTimer(for: task)
    vm.pauseTimer()

    return VStack {
        MiniTimerIndicator(viewModel: vm)
        Spacer()
    }
    .padding(.top, 60)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemBackground))
}
