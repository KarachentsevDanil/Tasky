//
//  ProactiveSuggestionBanner.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Banner view for displaying proactive AI suggestions
/// Appears at the top of the chat when AI has a suggestion
struct ProactiveSuggestionBanner: View {

    let suggestion: ProactiveSuggestion
    let onAction: () -> Void
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State
    @State private var isExpanded = false

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(spacing: 12) {
                // Icon
                iconView

                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(suggestion.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isExpanded ? nil : 2)
                }

                Spacer()

                // Expand/collapse
                Button {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(isExpanded ? "Collapse" : "Expand")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Expanded actions
            if isExpanded {
                Divider()
                    .padding(.horizontal, 16)

                actionButtons
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(suggestion.title): \(suggestion.message)")
    }

    // MARK: - Subviews

    private var iconView: some View {
        Image(systemName: suggestion.icon)
            .font(.title3.weight(.medium))
            .foregroundStyle(iconColor)
            .frame(width: 36, height: 36)
            .background(iconColor.opacity(0.15))
            .clipShape(Circle())
            .accessibilityHidden(true)
    }

    private var backgroundView: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(borderColor, lineWidth: 1)
            )
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Primary action button
            Button {
                HapticManager.shared.lightImpact()
                onAction()
            } label: {
                Text(actionButtonTitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(iconColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Take action: \(actionButtonTitle)")
            .accessibilityHint("Double tap to \(suggestion.suggestedAction)")

            // Secondary actions
            HStack(spacing: 8) {
                // Snooze button
                Button {
                    HapticManager.shared.lightImpact()
                    onSnooze()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Snooze")
                .accessibilityHint("Double tap to remind me later")

                // Dismiss button
                Button {
                    HapticManager.shared.lightImpact()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Dismiss")
                .accessibilityHint("Double tap to dismiss this suggestion")
            }
        }
    }

    // MARK: - Computed Properties

    private var iconColor: Color {
        switch suggestion.type {
        case .stuckTask, .overduePile:
            return .orange
        case .cleanSlate, .unusualProductivity:
            return .green
        case .neglectedGoal:
            return .purple
        case .birthdayReminder:
            return .pink
        case .streakMilestone:
            return .red
        case .weeklyReviewTime, .morningPlan, .eveningWrapup:
            return .blue
        }
    }

    private var borderColor: Color {
        iconColor.opacity(0.2)
    }

    private var actionButtonTitle: String {
        switch suggestion.type {
        case .stuckTask:
            return "Break it down"
        case .overduePile:
            return "Triage now"
        case .cleanSlate:
            return "Plan tomorrow"
        case .neglectedGoal:
            return "Add task"
        case .birthdayReminder:
            return "Set reminder"
        case .streakMilestone:
            return "Keep going!"
        case .weeklyReviewTime:
            return "Start review"
        case .unusualProductivity:
            return "View stats"
        case .morningPlan:
            return "Plan my day"
        case .eveningWrapup:
            return "Wrap up"
        }
    }
}

// MARK: - Compact Banner Variant

/// A more compact version for inline display
struct ProactiveSuggestionInline: View {

    let suggestion: ProactiveSuggestion
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Icon
            Image(systemName: suggestion.icon)
                .font(.body.weight(.medium))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            // Message
            Text(suggestion.message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)

            Spacer(minLength: 8)

            // Action
            Button {
                HapticManager.shared.lightImpact()
                onTap()
            } label: {
                Text("Go")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(iconColor)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("Take action")

            // Dismiss
            Button {
                HapticManager.shared.lightImpact()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .stuckTask, .overduePile: return .orange
        case .cleanSlate, .unusualProductivity: return .green
        case .neglectedGoal: return .purple
        case .birthdayReminder: return .pink
        case .streakMilestone: return .red
        default: return .blue
        }
    }
}

// MARK: - Preview

#Preview("Banner - Expanded") {
    VStack(spacing: 20) {
        ProactiveSuggestionBanner(
            suggestion: ProactiveSuggestion(
                id: UUID(),
                type: .overduePile,
                title: "Overdue Tasks Piling Up",
                message: "You have 7 overdue tasks. Let's triage them together.",
                suggestedAction: "Help me clean up my overdue tasks",
                icon: "exclamationmark.triangle.fill",
                priority: .urgent,
                createdAt: Date(),
                relatedTaskIds: [],
                metadata: ["overdueCount": "7"]
            ),
            onAction: {},
            onDismiss: {},
            onSnooze: {}
        )

        ProactiveSuggestionBanner(
            suggestion: ProactiveSuggestion(
                id: UUID(),
                type: .cleanSlate,
                title: "All Done!",
                message: "You've completed all 5 tasks for today. Great work!",
                suggestedAction: "Plan tomorrow",
                icon: "checkmark.circle.fill",
                priority: .medium,
                createdAt: Date(),
                relatedTaskIds: [],
                metadata: ["completedCount": "5"]
            ),
            onAction: {},
            onDismiss: {},
            onSnooze: {}
        )
    }
    .padding(.vertical)
}

#Preview("Inline") {
    ProactiveSuggestionInline(
        suggestion: ProactiveSuggestion(
            id: UUID(),
            type: .stuckTask,
            title: "Stuck Task",
            message: "'Review project proposal' has been rescheduled 4 times",
            suggestedAction: "Break it down",
            icon: "arrow.triangle.2.circlepath",
            priority: .high,
            createdAt: Date(),
            relatedTaskIds: [],
            metadata: [:]
        ),
        onTap: {},
        onDismiss: {}
    )
    .padding(.vertical)
}
