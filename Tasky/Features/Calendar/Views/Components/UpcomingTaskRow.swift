//
//  UpcomingTaskRow.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Task row for upcoming list view
struct UpcomingTaskRow: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.isCompleted ? "Completed" : "Not completed")
            .accessibilityHint(task.isCompleted ? "Tap to mark as incomplete" : "Tap to mark as complete")

            // Task Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                // Scheduled Time
                if let formattedTime = task.formattedScheduledTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(formattedTime)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.12))
                    )
                    .opacity(task.isCompleted ? 0.5 : 1.0)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

#Preview {
    UpcomingTaskRow(
        task: {
            let controller = PersistenceController.preview
            let task = TaskEntity(context: controller.container.viewContext)
            task.title = "Sample Task"
            task.scheduledTime = Date()
            return task
        }(),
        timerViewModel: FocusTimerViewModel(),
        onToggleCompletion: {}
    )
    .padding()
}
