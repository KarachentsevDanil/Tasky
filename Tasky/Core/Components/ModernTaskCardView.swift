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

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priority.color)
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                // Checkbox
                Button(action: onToggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.body)
                        .foregroundStyle(task.isCompleted ? .green : Color(.systemGray3))
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(task.isCompleted ? "Completed" : "Not completed")
                .accessibilityHint(task.isCompleted ? "Tap to mark as incomplete" : "Tap to mark as complete")
                .accessibilityValue(task.title)

                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(task.isCompleted ? .footnote : .subheadline.weight(.medium))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)

                    // Metadata pills (hide for completed tasks to reduce visual weight)
                    if hasMetadata && !task.isCompleted {
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
                }

                Spacer()

                // Notes indicator (green dot)
                if task.notes != nil && !task.notes!.isEmpty {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.leading, task.priority > 0 ? 8 : 10)
            .padding(.trailing, 10)
            .padding(.vertical, task.isCompleted ? 4 : 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTaskLabel)
        .accessibilityHint("Double tap to view task details")
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

        if task.notes != nil && !task.notes!.isEmpty {
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
#Preview("Incomplete Task") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Review pull request"
    task.isCompleted = false
    task.priority = 2
    task.dueDate = Date()
    task.notes = "Check for security issues"

    return ModernTaskCardView(task: task) {
        print("Toggle completion")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Completed Task") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.isCompleted = true
    task.priority = 1

    return ModernTaskCardView(task: task) {
        print("Toggle completion")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Task with Scheduled Time") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Team meeting"
    task.isCompleted = false
    task.priority = 0
    task.scheduledTime = Date()
    task.isRecurring = true

    return ModernTaskCardView(task: task) {
        print("Toggle completion")
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
