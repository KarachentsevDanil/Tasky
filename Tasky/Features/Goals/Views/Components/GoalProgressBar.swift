//
//  GoalProgressBar.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Visual progress bar for goals
struct GoalProgressBar: View {

    // MARK: - Properties
    let progress: Double
    let color: Color
    var height: CGFloat = 8
    var showLabel: Bool = false

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body
    var body: some View {
        VStack(alignment: .trailing, spacing: Constants.Spacing.xs) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(.systemGray5))
                        .frame(height: height)

                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(color)
                        .frame(width: progressWidth(in: geometry), height: height)
                        .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: height)

            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }

    // MARK: - Helpers
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        max(0, min(geometry.size.width * progress, geometry.size.width))
    }
}

/// Circular progress indicator for goals
struct GoalProgressRing: View {

    // MARK: - Properties
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 8
    var size: CGFloat = 100
    var showPercentage: Bool = true

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7), value: progress)

            // Percentage text
            if showPercentage {
                VStack(spacing: 2) {
                    Text("\(Int(progress * 100))")
                        .font(.system(size: size / 3, weight: .bold, design: .rounded))
                    Text("%")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}

// MARK: - Preview
#Preview("Progress Bar") {
    VStack(spacing: 20) {
        GoalProgressBar(progress: 0.0, color: .blue)
        GoalProgressBar(progress: 0.25, color: .green)
        GoalProgressBar(progress: 0.5, color: .orange, showLabel: true)
        GoalProgressBar(progress: 0.75, color: .purple, height: 12)
        GoalProgressBar(progress: 1.0, color: .green)
    }
    .padding()
}

#Preview("Progress Ring") {
    HStack(spacing: 20) {
        GoalProgressRing(progress: 0.25, color: .blue)
        GoalProgressRing(progress: 0.65, color: .green, size: 80)
        GoalProgressRing(progress: 1.0, color: .purple, size: 60)
    }
}
