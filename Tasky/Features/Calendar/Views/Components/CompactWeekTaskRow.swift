//
//  CompactWeekTaskRow.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Compact task row for week calendar view
struct CompactWeekTaskRow: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Priority Accent Bar
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 3)
                    .opacity(task.isCompleted ? 0.4 : 1.0)
            }

            HStack(spacing: 12) {
                // Completion indicator
                Circle()
                    .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)

                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    // Title with timer indicator
                    HStack(alignment: .center, spacing: 6) {
                        Text(task.title)
                            .font(.subheadline)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Small timer icon indicator (only when timer is active for this task)
                        if isTimerActive {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    // Metadata Pills
                    HStack(spacing: 6) {
                        // Scheduled Time - Prominent
                        if let formattedTime = task.formattedScheduledTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                Text(formattedTime)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 0.8))
                            )
                        }

                        // Priority
                        if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                            HStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                Text(priority.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(priority.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(priority.color.opacity(0.15))
                                    .overlay(Capsule().stroke(priority.color.opacity(0.4), lineWidth: 1))
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, task.priority > 0 ? 8 : 0)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

#Preview {
    CompactWeekTaskRow(
        task: {
            let controller = PersistenceController.preview
            let task = TaskEntity(context: controller.container.viewContext)
            task.title = "Sample Task"
            task.priority = 2
            task.scheduledTime = Date()
            return task
        }(),
        timerViewModel: FocusTimerViewModel()
    )
    .padding()
}
