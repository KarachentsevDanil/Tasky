//
//  FocusTimerProgressRing.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Circular progress ring with animated glow and timer display
struct FocusTimerProgressRing: View {
    @ObservedObject var viewModel: FocusTimerViewModel
    let timerColor: Color
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
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

            // Progress ring with enhanced shadow
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
                // Timer text with scale animation
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

    return FocusTimerProgressRing(
        viewModel: vm,
        timerColor: .orange
    )
    .padding()
    .background(Color(.systemBackground))
}

#Preview("Paused Timer") {
    let vm = FocusTimerViewModel()
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    vm.startTimer(for: task)
    vm.pauseTimer()

    return FocusTimerProgressRing(
        viewModel: vm,
        timerColor: .yellow
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

    return FocusTimerProgressRing(
        viewModel: vm,
        timerColor: .green
    )
    .padding()
    .background(Color(.systemBackground))
}
