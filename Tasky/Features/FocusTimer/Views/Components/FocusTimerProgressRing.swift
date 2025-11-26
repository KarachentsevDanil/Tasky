//
//  FocusTimerProgressRing.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Circular progress ring with timer display
struct FocusTimerProgressRing: View {
    @ObservedObject var viewModel: FocusTimerViewModel
    let timerColor: Color
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let ringSize: CGFloat = 260
    private let ringWidth: CGFloat = 14

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    Color(.systemGray5),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )

            // Progress ring with gradient
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(
                    AngularGradient(
                        colors: [timerColor.opacity(0.7), timerColor],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(-90 + 360 * viewModel.progress)
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: timerColor.opacity(0.25), radius: 6, x: 0, y: 3)
                .animation(reduceMotion ? .none : .linear(duration: 1), value: viewModel.progress)

            // Inner content
            VStack(spacing: 8) {
                // Timer text
                Text(viewModel.formattedTime)
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(timerColor)

                // Total duration context
                Text("of \(viewModel.totalDurationFormatted)")
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(Color(.secondaryLabel))

                // State indicator
                if viewModel.timerState == .paused {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.yellow)
                            .frame(width: 8, height: 8)

                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(.secondaryLabel))
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .frame(width: ringSize, height: ringSize)
        .padding(.vertical, 20)
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
