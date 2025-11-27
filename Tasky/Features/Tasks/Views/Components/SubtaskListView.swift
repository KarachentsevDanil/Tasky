//
//  SubtaskListView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI
internal import CoreData

/// List of subtasks with add functionality
struct SubtaskListView: View {

    @ObservedObject var viewModel: TaskListViewModel
    let task: TaskEntity

    @State private var newSubtaskTitle = ""
    @State private var isAddingSubtask = false
    @FocusState private var isNewSubtaskFocused: Bool

    private var subtasks: [SubtaskEntity] {
        task.subtasksArray
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Subtask list
            ForEach(subtasks) { subtask in
                SubtaskRowView(
                    subtask: subtask,
                    onToggle: {
                        Task {
                            await viewModel.toggleSubtaskCompletion(subtask)
                        }
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteSubtask(subtask)
                        }
                    },
                    onConvertToTask: {
                        Task {
                            await viewModel.convertSubtaskToTask(subtask)
                        }
                    }
                )

                if subtask.id != subtasks.last?.id {
                    Divider()
                        .padding(.leading, 36)
                }
            }
            .onMove(perform: moveSubtasks)

            // Add subtask row
            addSubtaskRow
        }
    }

    // MARK: - Add Subtask Row

    private var addSubtaskRow: some View {
        HStack(spacing: Constants.Spacing.md) {
            if isAddingSubtask {
                // Circle placeholder
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(.secondary)

                // Text field
                TextField("Add subtask", text: $newSubtaskTitle)
                    .font(.subheadline)
                    .focused($isNewSubtaskFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        addSubtask()
                    }

                // Cancel button
                Button {
                    cancelAddSubtask()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startAddingSubtask()
                } label: {
                    HStack(spacing: Constants.Spacing.md) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 20))
                        Text("Add subtask")
                            .font(.subheadline)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Constants.Spacing.sm)
        .padding(.top, subtasks.isEmpty ? 0 : Constants.Spacing.sm)
    }

    // MARK: - Methods

    private func startAddingSubtask() {
        isAddingSubtask = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isNewSubtaskFocused = true
        }
    }

    private func cancelAddSubtask() {
        newSubtaskTitle = ""
        isAddingSubtask = false
        isNewSubtaskFocused = false
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            cancelAddSubtask()
            return
        }

        Task {
            await viewModel.createSubtask(title: title, for: task)
            newSubtaskTitle = ""
            // Keep input open for adding more
            isNewSubtaskFocused = true
        }
        HapticManager.shared.lightImpact()
    }

    private func moveSubtasks(from source: IndexSet, to destination: Int) {
        var reorderedSubtasks = subtasks
        reorderedSubtasks.move(fromOffsets: source, toOffset: destination)

        Task {
            await viewModel.reorderSubtasks(reorderedSubtasks)
        }
    }
}

/// Expandable subtask section for task detail view
struct SubtaskSection: View {

    @ObservedObject var viewModel: TaskListViewModel
    let task: TaskEntity
    @Binding var isExpanded: Bool

    var body: some View {
        ExpandableOptionRow(
            icon: "checklist",
            iconColor: .blue,
            label: "Subtasks",
            value: task.subtasksProgressString,
            isExpanded: $isExpanded,
            canClear: false
        ) {
            SubtaskListView(viewModel: viewModel, task: task)
        }
    }
}

// MARK: - Preview
#Preview("Subtask List") {
    let context = PersistenceController.preview.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Complete Project"
    task.createdAt = Date()

    // Add some subtasks
    for (index, title) in ["Research", "Design", "Implement", "Test"].enumerated() {
        let subtask = SubtaskEntity(context: context)
        subtask.id = UUID()
        subtask.title = title
        subtask.isCompleted = index < 2
        subtask.sortOrder = Int16(index)
        subtask.createdAt = Date()
        subtask.parentTask = task
        if index < 2 {
            subtask.completedAt = Date()
        }
    }

    return SubtaskListView(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        task: task
    )
    .padding()
}

#Preview("Empty Subtasks") {
    let context = PersistenceController.preview.viewContext

    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "New Task"
    task.createdAt = Date()

    return SubtaskListView(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        task: task
    )
    .padding()
}
