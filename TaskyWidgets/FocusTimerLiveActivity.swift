//
//  FocusTimerLiveActivity.swift
//  TaskyWidgets
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for Focus Timer - appears in Dynamic Island and Lock Screen
struct FocusTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusTimerActivityAttributes.self) { context in
            // Lock Screen / Banner UI
            LockScreenView(context: context)
                .activityBackgroundTint(context.state.isBreak ? .green.opacity(0.2) : .orange.opacity(0.2))
                .activitySystemActionForegroundColor(.primary)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI - Leading
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }

                // Expanded UI - Trailing
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }

                // Expanded UI - Bottom
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }

                // Expanded UI - Center
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
            } compactLeading: {
                // Compact Leading - Icon
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Compact Trailing - Time
                CompactTrailingView(context: context)
            } minimal: {
                // Minimal - Just progress
                MinimalView(context: context)
            }
            .keylineTint(context.state.isBreak ? .green : .orange)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    private var formattedTime: String {
        let minutes = context.state.remainingSeconds / 60
        let seconds = context.state.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var accessibilityLabel: String {
        let sessionType = context.state.isBreak ? "Break" : "Focus"
        let status = context.state.isPaused ? "Paused" : "Running"
        return "\(context.attributes.taskTitle), \(sessionType) session, \(formattedTime) remaining, \(status)"
    }

    var body: some View {
        HStack(spacing: 16) {
            // Progress circle with icon
            ZStack {
                Circle()
                    .stroke(timerColor.opacity(0.3), lineWidth: 4)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: context.state.progress)
                    .stroke(timerColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(-90))

                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(timerColor)
            }
            .accessibilityHidden(true)

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.taskTitle)
                    .font(.headline)
                    .lineLimit(1)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text(context.state.isBreak ? "Break" : "Focus")
                        .font(.subheadline)
                        .foregroundStyle(timerColor)

                    Text("•")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("Session \(context.state.currentSession)/\(context.state.targetSessions)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Timer display
            VStack(alignment: .trailing, spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(timerColor)
                    .monospacedDigit()

                if context.state.isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

// MARK: - Dynamic Island Expanded Views

private struct ExpandedLeadingView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(timerColor)

            Text(context.state.isBreak ? "Break" : "Focus")
                .font(.caption.weight(.semibold))
                .foregroundStyle(timerColor)
        }
    }
}

private struct ExpandedTrailingView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    var body: some View {
        Text("\(context.state.currentSession)/\(context.state.targetSessions)")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
    }
}

private struct ExpandedCenterView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    var body: some View {
        Text(context.attributes.taskTitle)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(.primary)
    }
}

private struct ExpandedBottomView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    private var formattedTime: String {
        let minutes = context.state.remainingSeconds / 60
        let seconds = context.state.remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(timerColor.opacity(0.3))
                        .frame(height: 6)

                    Capsule()
                        .fill(timerColor)
                        .frame(width: geometry.size.width * context.state.progress, height: 6)
                }
            }
            .frame(height: 6)

            // Time display
            HStack {
                Text(formattedTime)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(timerColor)
                    .monospacedDigit()

                if context.state.isPaused {
                    Image(systemName: "pause.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Dynamic Island Compact Views

private struct CompactLeadingView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    var body: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(timerColor.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Icon
            Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(timerColor)
        }
        .frame(width: 24, height: 24)
    }
}

private struct CompactTrailingView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    private var formattedTime: String {
        let minutes = context.state.remainingSeconds / 60
        let seconds = context.state.remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        Text(formattedTime)
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundStyle(timerColor)
            .monospacedDigit()
    }
}

// MARK: - Minimal View

private struct MinimalView: View {
    let context: ActivityViewContext<FocusTimerActivityAttributes>

    private var timerColor: Color {
        context.state.isBreak ? .green : .orange
    }

    var body: some View {
        ZStack {
            // Progress ring
            Circle()
                .stroke(timerColor.opacity(0.3), lineWidth: 2)

            Circle()
                .trim(from: 0, to: context.state.progress)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Icon
            Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(timerColor)
        }
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: FocusTimerActivityAttributes(
    taskTitle: "Write documentation",
    totalDuration: 25 * 60,
    startTime: Date()
)) {
    FocusTimerLiveActivity()
} contentStates: {
    FocusTimerActivityAttributes.ContentState(
        remainingSeconds: 1426,
        isBreak: false,
        isPaused: false,
        currentSession: 2,
        targetSessions: 4,
        progress: 0.65
    )
}

#Preview("Dynamic Island Compact", as: .dynamicIsland(.compact), using: FocusTimerActivityAttributes(
    taskTitle: "Write documentation",
    totalDuration: 25 * 60,
    startTime: Date()
)) {
    FocusTimerLiveActivity()
} contentStates: {
    FocusTimerActivityAttributes.ContentState(
        remainingSeconds: 1426,
        isBreak: false,
        isPaused: false,
        currentSession: 2,
        targetSessions: 4,
        progress: 0.65
    )
}

#Preview("Dynamic Island Expanded", as: .dynamicIsland(.expanded), using: FocusTimerActivityAttributes(
    taskTitle: "Write documentation",
    totalDuration: 25 * 60,
    startTime: Date()
)) {
    FocusTimerLiveActivity()
} contentStates: {
    FocusTimerActivityAttributes.ContentState(
        remainingSeconds: 1426,
        isBreak: false,
        isPaused: false,
        currentSession: 2,
        targetSessions: 4,
        progress: 0.65
    )
}

#Preview("Break Time", as: .dynamicIsland(.compact), using: FocusTimerActivityAttributes(
    taskTitle: "Taking a break",
    totalDuration: 5 * 60,
    startTime: Date()
)) {
    FocusTimerLiveActivity()
} contentStates: {
    FocusTimerActivityAttributes.ContentState(
        remainingSeconds: 180,
        isBreak: true,
        isPaused: false,
        currentSession: 2,
        targetSessions: 4,
        progress: 0.4
    )
}
