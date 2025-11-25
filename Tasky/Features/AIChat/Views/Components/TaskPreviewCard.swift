//
//  TaskPreviewCard.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// Preview card shown after AI creates a task (when setting is enabled)
struct TaskPreviewCard: View {

    // MARK: - Properties
    let createdTasks: [CreatedTaskInfo]
    let onEdit: (CreatedTaskInfo) -> Void
    let onUndo: () -> Void
    let onDone: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.system(size: 20))

                Text(createdTasks.count == 1 ? "Task Created" : "\(createdTasks.count) Tasks Created")
                    .font(.headline)

                Spacer()

                Button {
                    HapticManager.shared.lightImpact()
                    onDone()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
                .accessibilityHint("Double tap to dismiss the preview")
            }
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.top, Constants.Spacing.md)
            .padding(.bottom, Constants.Spacing.sm)

            Divider()
                .padding(.horizontal, Constants.Spacing.md)

            // Task list
            VStack(spacing: 8) {
                ForEach(createdTasks) { task in
                    taskRow(task)
                }
            }
            .padding(Constants.Spacing.md)

            Divider()
                .padding(.horizontal, Constants.Spacing.md)

            // Action buttons
            HStack(spacing: 12) {
                // Undo button
                Button {
                    HapticManager.shared.lightImpact()
                    onUndo()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo")
                .accessibilityHint("Double tap to delete the created tasks")

                // Edit button (only for single task)
                if createdTasks.count == 1, let task = createdTasks.first {
                    Button {
                        HapticManager.shared.lightImpact()
                        onEdit(task)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Edit")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit task")
                    .accessibilityHint("Double tap to edit task details")
                }
            }
            .padding(Constants.Spacing.md)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.vertical, Constants.Spacing.sm)
    }

    // MARK: - Task Row
    @ViewBuilder
    private func taskRow(_ task: CreatedTaskInfo) -> some View {
        HStack(spacing: 12) {
            // Priority indicator
            Circle()
                .fill(priorityColor(task.priority))
                .frame(width: 8, height: 8)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Due date
                    if let dueDate = task.dueDate {
                        Label(formatDate(dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // List name
                    if let listName = task.listName {
                        Label(listName, systemImage: "folder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // Duration
                    if task.estimatedMinutes > 0 {
                        Label("\(task.estimatedMinutes)m", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    private func priorityColor(_ priority: Int) -> Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return Color(.systemGray4)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Created Task Info Model
struct CreatedTaskInfo: Identifiable, Equatable {
    let id: UUID
    let title: String
    let dueDate: Date?
    let priority: Int
    let listName: String?
    let estimatedMinutes: Int
    let taskEntityId: UUID? // Reference to actual TaskEntity for editing/undoing

    init(
        id: UUID = UUID(),
        title: String,
        dueDate: Date? = nil,
        priority: Int = 0,
        listName: String? = nil,
        estimatedMinutes: Int = 0,
        taskEntityId: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.priority = priority
        self.listName = listName
        self.estimatedMinutes = estimatedMinutes
        self.taskEntityId = taskEntityId
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()

        TaskPreviewCard(
            createdTasks: [
                CreatedTaskInfo(
                    title: "Buy groceries for the week",
                    dueDate: Date(),
                    priority: 2,
                    listName: "Personal",
                    estimatedMinutes: 30
                )
            ],
            onEdit: { _ in },
            onUndo: { },
            onDone: { }
        )

        TaskPreviewCard(
            createdTasks: [
                CreatedTaskInfo(
                    title: "Review PR",
                    dueDate: Date(),
                    priority: 3,
                    listName: "Work",
                    estimatedMinutes: 15
                ),
                CreatedTaskInfo(
                    title: "Update documentation",
                    dueDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()),
                    priority: 1,
                    estimatedMinutes: 45
                )
            ],
            onEdit: { _ in },
            onUndo: { },
            onDone: { }
        )

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
