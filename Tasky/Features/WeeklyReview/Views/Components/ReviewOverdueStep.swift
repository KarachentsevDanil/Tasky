//
//  ReviewOverdueStep.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Step 3: Triage overdue tasks
struct ReviewOverdueStep: View {

    // MARK: - Properties
    let tasks: [TaskEntity]
    let onAction: (TaskEntity, TaskReviewAction) -> Void
    let onSkip: () -> Void
    let onContinue: () -> Void

    // MARK: - State
    @State private var currentTaskIndex = 0

    // MARK: - Computed Properties
    private var currentTask: TaskEntity? {
        guard currentTaskIndex < tasks.count else { return nil }
        return tasks[currentTaskIndex]
    }

    private var hasMoreTasks: Bool {
        currentTaskIndex < tasks.count
    }

    private var progress: String {
        "\(min(currentTaskIndex + 1, tasks.count)) of \(tasks.count)"
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.Spacing.lg) {
            // Header
            headerView

            if tasks.isEmpty {
                emptyStateView
            } else if let task = currentTask {
                // Current task card
                overdueTaskCardView(task)
                    .id(task.id)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                // Action buttons
                overdueActionButtonsView(task)

                Spacer()

                // Skip button
                Button {
                    onSkip()
                } label: {
                    Text("Skip Remaining (Move All to Today)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, Constants.Spacing.lg)
            } else {
                // All tasks processed
                allDoneView
            }
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: currentTaskIndex)
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: Constants.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Overdue Tasks")
                .font(.title2.weight(.bold))

            if !tasks.isEmpty && hasMoreTasks {
                Text(progress)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Constants.Spacing.md)
                    .padding(.vertical, Constants.Spacing.xs)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
        .padding(.top, Constants.Spacing.xl)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("No Overdue Tasks!")
                .font(.title3.weight(.semibold))

            Text("You're all caught up on your deadlines.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, Constants.Spacing.xl)
        }
    }

    // MARK: - All Done View
    private var allDoneView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Overdue Tasks Handled!")
                .font(.title3.weight(.semibold))

            Text("You've triaged all overdue tasks.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .padding(.bottom, Constants.Spacing.xl)
        }
    }

    // MARK: - Overdue Task Card
    private func overdueTaskCardView(_ task: TaskEntity) -> some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Overdue badge
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                Text(overdueText(for: task))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
            }

            // Title
            Text(task.title)
                .font(.headline)
                .lineLimit(3)

            // Original due date
            if let dueDate = task.dueDate {
                HStack(spacing: Constants.Spacing.xs) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.caption)
                    Text("Was due: \(dueDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }

            // List if exists
            if let listName = task.taskList?.name {
                HStack(spacing: Constants.Spacing.xs) {
                    Circle()
                        .fill(Color(hex: task.taskList?.colorHex ?? "007AFF") ?? .blue)
                        .frame(width: 8, height: 8)
                    Text(listName)
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Constants.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }

    // MARK: - Action Buttons
    private func overdueActionButtonsView(_ task: TaskEntity) -> some View {
        VStack(spacing: Constants.Spacing.md) {
            Text("What would you like to do?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Spacing.md) {
                // Delete
                OverdueActionButton(
                    title: "Delete",
                    iconName: "trash",
                    color: .red
                ) {
                    onAction(task, .delete)
                    advanceToNextTask()
                }

                // Tomorrow
                OverdueActionButton(
                    title: "Tomorrow",
                    iconName: "sun.max",
                    color: .orange
                ) {
                    onAction(task, .rescheduleToTomorrow)
                    advanceToNextTask()
                }

                // Today
                OverdueActionButton(
                    title: "Today",
                    iconName: "calendar",
                    color: .green
                ) {
                    onAction(task, .keep)
                    advanceToNextTask()
                }
            }
        }
    }

    // MARK: - Helpers
    private func overdueText(for task: TaskEntity) -> String {
        guard let dueDate = task.dueDate else { return "Overdue" }
        let days = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
        if days == 1 {
            return "1 day overdue"
        } else if days < 7 {
            return "\(days) days overdue"
        } else if days < 14 {
            return "1 week overdue"
        } else {
            return "\(days / 7) weeks overdue"
        }
    }

    private func advanceToNextTask() {
        withAnimation {
            currentTaskIndex += 1
        }

        // Auto-continue when all tasks are processed
        if !hasMoreTasks {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onContinue()
            }
        }
    }
}

// MARK: - Overdue Action Button
private struct OverdueActionButton: View {
    let title: String
    let iconName: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: Constants.Spacing.xs) {
                Image(systemName: iconName)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.md)
            .foregroundStyle(color)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
        }
        .accessibilityLabel("\(title) task")
    }
}

// MARK: - Preview
#Preview {
    ReviewOverdueStep(
        tasks: [],
        onAction: { _, _ in },
        onSkip: {},
        onContinue: {}
    )
}
