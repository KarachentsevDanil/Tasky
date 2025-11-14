//
//  UnscheduledEventsBar.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Collapsible bar showing unscheduled tasks that can be scheduled
struct UnscheduledEventsBar: View {

    // MARK: - Properties
    let tasks: [TaskEntity]
    let onTaskTap: (TaskEntity) -> Void

    // MARK: - State
    @State private var isExpanded = true
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            header

            // Tasks list (when expanded)
            if isExpanded && !tasks.isEmpty {
                tasksList
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Text("Unscheduled")
                .font(.headline)
                .foregroundColor(.secondary)

            Spacer()

            // Task count badge
            Text("\(tasks.count)")
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())

            // Expand/collapse button
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
                HapticManager.shared.lightImpact()
            }) {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.secondary)
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityLabel(isExpanded ? "Collapse unscheduled tasks" : "Expand unscheduled tasks")
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Tasks List
    private var tasksList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tasks) { task in
                    UnscheduledTaskCard(task: task)
                        .onTapGesture {
                            HapticManager.shared.lightImpact()
                            onTaskTap(task)
                        }
                }
            }
        }
        .frame(height: 80)
    }
}

// MARK: - Unscheduled Task Card
struct UnscheduledTaskCard: View {

    // MARK: - Properties
    let task: TaskEntity

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(task.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)
                .foregroundColor(.primary)

            // Metadata
            if let list = task.taskList {
                HStack(spacing: 4) {
                    Image(systemName: list.iconName ?? "list.bullet")
                        .font(.caption2)
                    Text(list.name)
                        .font(.caption2)
                }
                .foregroundStyle(list.color)
            }

            // Priority indicator
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 8))
                    Text(priority.displayName)
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(priority.color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(priority.color.opacity(0.15))
                )
            }
        }
        .padding(8)
        .frame(width: 140, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(task.title), unscheduled task")
        .accessibilityHint("Tap to schedule this task")
    }
}

// MARK: - Preview
#Preview("With Tasks") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    let tasks = (1...5).map { i in
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Unscheduled Task \(i)"
        task.isCompleted = false
        task.priority = Int16(i % 4)
        return task
    }

    return UnscheduledEventsBar(
        tasks: tasks,
        onTaskTap: { task in
            print("Tapped task: \(task.title)")
        }
    )
}

#Preview("Empty") {
    UnscheduledEventsBar(
        tasks: [],
        onTaskTap: { _ in }
    )
}
