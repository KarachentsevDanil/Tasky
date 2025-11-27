//
//  SubtaskRowView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI
internal import CoreData

/// A single subtask row with checkbox
struct SubtaskRowView: View {

    let subtask: SubtaskEntity
    let onToggle: () -> Void
    var onDelete: (() -> Void)?
    var onConvertToTask: (() -> Void)?

    @State private var isEditing = false
    @State private var editedTitle: String

    init(
        subtask: SubtaskEntity,
        onToggle: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        onConvertToTask: (() -> Void)? = nil
    ) {
        self.subtask = subtask
        self.onToggle = onToggle
        self.onDelete = onDelete
        self.onConvertToTask = onConvertToTask
        self._editedTitle = State(initialValue: subtask.title)
    }

    var body: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Checkbox
            Button {
                HapticManager.shared.lightImpact()
                onToggle()
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(subtask.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Title
            Text(subtask.title)
                .font(.subheadline)
                .strikethrough(subtask.isCompleted)
                .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                .lineLimit(2)

            Spacer()
        }
        .padding(.vertical, Constants.Spacing.xs)
        .contentShape(Rectangle())
        .contextMenu {
            if let onConvertToTask {
                Button {
                    onConvertToTask()
                } label: {
                    Label("Convert to Task", systemImage: "arrow.up.right.square")
                }
            }

            Divider()

            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}

/// Progress indicator for subtasks
struct SubtaskProgressView: View {

    let completed: Int
    let total: Int

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: Constants.Spacing.sm) {
            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 16, height: 16)

            // Count
            Text("\(completed)/\(total)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}

/// Compact subtask indicator for task rows
struct SubtaskIndicator: View {

    let task: TaskEntity

    var body: some View {
        if task.hasSubtasks {
            let progress = task.subtasksProgress
            SubtaskProgressView(completed: progress.completed, total: progress.total)
        }
    }
}

// MARK: - Preview
#Preview("Subtask Row") {
    let context = PersistenceController.preview.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Parent Task"
    task.createdAt = Date()

    let subtask = SubtaskEntity(context: context)
    subtask.id = UUID()
    subtask.title = "Complete the documentation"
    subtask.isCompleted = false
    subtask.createdAt = Date()
    subtask.parentTask = task

    return SubtaskRowView(
        subtask: subtask,
        onToggle: {},
        onDelete: {}
    )
    .padding()
}

#Preview("Completed Subtask") {
    let context = PersistenceController.preview.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Parent Task"
    task.createdAt = Date()

    let subtask = SubtaskEntity(context: context)
    subtask.id = UUID()
    subtask.title = "Review pull request"
    subtask.isCompleted = true
    subtask.completedAt = Date()
    subtask.createdAt = Date()
    subtask.parentTask = task

    return SubtaskRowView(
        subtask: subtask,
        onToggle: {},
        onDelete: {}
    )
    .padding()
}

#Preview("Progress View") {
    VStack(spacing: 20) {
        SubtaskProgressView(completed: 0, total: 5)
        SubtaskProgressView(completed: 2, total: 5)
        SubtaskProgressView(completed: 5, total: 5)
    }
    .padding()
}
