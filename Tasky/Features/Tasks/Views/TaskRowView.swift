//
//  TaskRowView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI
internal import CoreData

/// Reusable row view for displaying a task
struct TaskRowView: View {

    // MARK: - Properties
    let task: TaskEntity
    let onToggleCompletion: () -> Void

    // MARK: - Body
    var body: some View {
        HStack(spacing: Constants.UI.padding) {
            // Completion button
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                // Task metadata
                HStack(spacing: Constants.UI.smallPadding) {
                    // Due date
                    if let formattedDate = task.formattedDueDate {
                        Label(formattedDate, systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    // List name
                    if let list = task.taskList {
                        Label(list.name, systemImage: list.iconName ?? Constants.Icons.list)
                            .font(.caption)
                            .foregroundStyle(list.color)
                    }

                    // Priority indicator
                    if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                        HStack(spacing: 2) {
                            Image(systemName: "flag.fill")
                            Text(priority.displayName)
                        }
                        .font(.caption)
                        .foregroundStyle(priority.color)
                    }
                }
            }

            Spacer()

            // Chevron for navigation
            Image(systemName: Constants.Icons.chevronRight)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Constants.UI.smallPadding)
    }
}

// MARK: - Preview
#Preview("Regular Task") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Complete project documentation"
    task.notes = "Add comprehensive README"
    task.isCompleted = false
    task.dueDate = Date()
    task.createdAt = Date()
    task.priority = 2

    return TaskRowView(task: task, onToggleCompletion: {})
        .padding()
}

#Preview("Completed Task") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Review pull request"
    task.isCompleted = true
    task.completedAt = Date()
    task.createdAt = Date()
    task.priority = 1

    return TaskRowView(task: task, onToggleCompletion: {})
        .padding()
}

#Preview("Overdue Task") {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Fix critical bug"
    task.isCompleted = false
    task.dueDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())
    task.createdAt = Date()
    task.priority = 3

    return TaskRowView(task: task, onToggleCompletion: {})
        .padding()
}
