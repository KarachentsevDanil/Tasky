//
//  ModernTaskCardView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Modern card-based task row component with priority indicators and metadata
struct ModernTaskCardView: View {
    let task: TaskEntity
    let onToggleCompletion: () -> Void
    var showDoThisFirstBadge: Bool = false
    var useHumanReadableLabels: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar (hidden for AI priority task with gradient)
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority), !showDoThisFirstBadge {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priority.color)
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            HStack(spacing: Constants.Spacing.sm) {
                // Checkbox
                Button(action: onToggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? .green : showDoThisFirstBadge && !task.isCompleted ? Color.white.opacity(0.8) : Color(.systemGray3))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Completed" : "Not completed")
                .accessibilityHint(task.isCompleted ? "Tap to mark as incomplete" : "Tap to mark as complete")
                .accessibilityValue(task.title)

                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    // Task title with overdue indicator
                    HStack(spacing: 6) {
                        // Orange dot for overdue tasks (not shown on gradient background)
                        if task.isOverdue && !task.isCompleted && !showDoThisFirstBadge {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 6, height: 6)
                        }

                        Text(task.title)
                            .font(task.isCompleted ? .footnote : .subheadline)
                            .fontWeight(showDoThisFirstBadge && !task.isCompleted ? .semibold : .regular)
                            .foregroundStyle(task.isCompleted ? .secondary : showDoThisFirstBadge && !task.isCompleted ? Color.white : .primary)
                            .strikethrough(task.isCompleted)
                    }

                    // Human-readable time label or metadata pills
                    if !task.isCompleted {
                        if useHumanReadableLabels, let timeLabel = task.humanReadableTimeLabel {
                            Text(timeLabel)
                                .font(.caption)
                                .foregroundStyle(showDoThisFirstBadge ? Color.white.opacity(0.8) : .secondary)
                        } else if hasMetadata {
                            metadataPills
                        }
                    }
                }

                Spacer()

                // Right side content
                HStack(spacing: Constants.Spacing.xs) {
                    // "Do this first" badge - moved to right side
                    if showDoThisFirstBadge && !task.isCompleted {
                        DoThisFirstBadge()
                    }

                    // Notes indicator (green dot)
                    if let notes = task.notes, !notes.isEmpty {
                        Circle()
                            .fill(showDoThisFirstBadge && !task.isCompleted ? Color.white.opacity(0.6) : .green)
                            .frame(width: 5, height: 5)
                    }
                }
            }
            .padding(.leading, task.priority > 0 && !showDoThisFirstBadge ? Constants.Spacing.sm : Constants.Spacing.md)
            .padding(.trailing, Constants.Spacing.md)
            .padding(.vertical, task.isCompleted ? Constants.Spacing.xs : Constants.Spacing.md)
        }
        .background(
            showDoThisFirstBadge && !task.isCompleted
                ? AnyView(
                    LinearGradient(
                        colors: [Color(red: 0.4, green: 0.5, blue: 0.95), Color(red: 0.5, green: 0.4, blue: 0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                : AnyView(Color(.systemBackground))
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
        .shadow(color: .black.opacity(showDoThisFirstBadge && !task.isCompleted ? 0.1 : 0.02), radius: showDoThisFirstBadge && !task.isCompleted ? 4 : 2, y: showDoThisFirstBadge && !task.isCompleted ? 2 : 0.5)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTaskLabel)
        .accessibilityHint("Double tap to view task details")
    }

    // MARK: - Subviews

    @ViewBuilder
    private var metadataPills: some View {
        HStack(spacing: 5) {
            // Priority pill
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                HStack(spacing: 2) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 8))
                    Text(priority.displayName)
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(priority.color)
                )
            }

            // Recurring pill
            if task.isRecurring {
                HStack(spacing: 2) {
                    Image(systemName: "repeat")
                        .font(.system(size: 8))
                    Text("Daily")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.purple)
                )
            }

            // Scheduled time
            if let formattedTime = task.formattedScheduledTime {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(formattedTime)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.blue)
            }

            // Due date (if different from scheduled)
            if task.scheduledTime == nil, let dueDate = task.dueDate {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                    Text(formatDueDate(dueDate))
                        .font(.system(size: 10))
                }
                .foregroundStyle(.blue)
            }
        }
    }

    // MARK: - Computed Properties

    private var hasMetadata: Bool {
        task.priority > 0 || task.isRecurring || task.scheduledTime != nil || task.dueDate != nil
    }

    private var accessibilityTaskLabel: String {
        var label = task.title

        if task.isCompleted {
            label += ", completed"
        }

        if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
            label += ", \(priority.displayName) priority"
        }

        if task.isRecurring {
            label += ", recurring daily"
        }

        if let scheduledTime = task.scheduledTime {
            label += ", scheduled at \(AppDateFormatters.timeFormatter.string(from: scheduledTime))"
        } else if let dueDate = task.dueDate {
            label += ", due \(formatDueDate(dueDate))"
        }

        if let notes = task.notes, !notes.isEmpty {
            label += ", has notes"
        }

        return label
    }

    // MARK: - Helper Methods

    private func formatTime(_ date: Date) -> String {
        AppDateFormatters.timeFormatter.string(from: date)
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current

        // Check if time is midnight (00:00) - indicates it's just a date, not a specific time
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let isMidnight = components.hour == 0 && components.minute == 0

        if isMidnight {
            // Just show "Today", "Tomorrow", or the date
            return AppDateFormatters.formatShortRelativeDate(date)
        } else {
            // Show "Due HH:mm" for tasks with specific times
            return "Due \(formatTime(date))"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Constants.Spacing.md) {
        Text("Task Cards Preview")
            .font(.headline)

        ModernTaskCardView(
            task: makePreviewTask(title: "Review PR", isOverdue: false),
            onToggleCompletion: {}
        )

        ModernTaskCardView(
            task: makePreviewTask(title: "Finish report", isOverdue: false),
            onToggleCompletion: {},
            showDoThisFirstBadge: true,
            useHumanReadableLabels: true
        )

        ModernTaskCardView(
            task: makePreviewTask(title: "Submit expenses", isOverdue: true),
            onToggleCompletion: {},
            useHumanReadableLabels: true
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

private func makePreviewTask(title: String, isOverdue: Bool) -> TaskEntity {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = title
    task.isCompleted = false
    task.priority = 2
    task.dueDate = isOverdue ? Calendar.current.date(byAdding: .day, value: -2, to: Date()) : Date()
    task.createdAt = Date()
    task.aiPriorityScore = 100
    return task
}
