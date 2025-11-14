//
//  TaskDetailSchedulingSection.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Scheduling section combining due date, priority, and list assignment
struct TaskDetailSchedulingSection: View {
    let task: TaskEntity
    let isEditing: Bool
    let taskLists: [TaskListEntity]

    @Binding var hasDueDate: Bool
    @Binding var dueDate: Date
    @Binding var priority: Constants.TaskPriority
    @Binding var selectedList: TaskListEntity?

    var body: some View {
        // Due Date Section
        Section {
            if isEditing {
                Toggle("Set due date", isOn: $hasDueDate)
                    .onChange(of: hasDueDate) { _ in
                        HapticManager.shared.selectionChanged()
                    }
                    .accessibilityLabel("Set due date")
                    .accessibilityHint("Enable to add a due date to this task")

                if hasDueDate {
                    DatePicker(
                        "Due date",
                        selection: $dueDate,
                        displayedComponents: [.date]
                    )
                    .accessibilityLabel("Due date")
                    .accessibilityHint("Select when this task is due")
                }
            } else {
                HStack {
                    Text("Due date")
                    Spacer()
                    if let formattedDate = task.formattedDueDate {
                        Text(formattedDate)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    } else {
                        Text("Not set")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }

        // Priority Section
        Section {
            if isEditing {
                Picker("Priority", selection: $priority) {
                    ForEach(Constants.TaskPriority.allCases, id: \.self) { priority in
                        HStack {
                            if priority != .none {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(priority.color)
                            }
                            Text(priority.displayName)
                        }
                        .tag(priority)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: priority) { _ in
                    HapticManager.shared.selectionChanged()
                }
                .accessibilityLabel("Task priority")
                .accessibilityHint("Select the priority level for this task")
            } else {
                HStack {
                    Text("Priority")
                    Spacer()
                    Label(
                        priority.displayName,
                        systemImage: priority == .none ? "" : "flag.fill"
                    )
                    .foregroundStyle(priority.color)
                }
            }
        }

        // List Section
        Section {
            if isEditing {
                Picker("List", selection: $selectedList) {
                    Text("None").tag(nil as TaskListEntity?)
                    ForEach(taskLists, id: \.id) { list in
                        HStack {
                            if let iconName = list.iconName {
                                Image(systemName: iconName)
                                    .foregroundStyle(list.color)
                            }
                            Text(list.name)
                        }
                        .tag(list as TaskListEntity?)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedList) { _ in
                    HapticManager.shared.selectionChanged()
                }
                .accessibilityLabel("Task list")
                .accessibilityHint("Assign this task to a specific list")
            } else {
                HStack {
                    Text("List")
                    Spacer()
                    if let list = task.taskList {
                        Label(list.name, systemImage: list.iconName ?? Constants.Icons.list)
                            .foregroundStyle(list.color)
                    } else {
                        Text("None")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview("Editing Mode") {
    @Previewable @State var hasDueDate = true
    @Previewable @State var dueDate = Date()
    @Previewable @State var priority = Constants.TaskPriority.high
    @Previewable @State var selectedList: TaskListEntity? = nil

    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Review code"
    task.dueDate = Date()
    task.priority = 2

    return Form {
        TaskDetailSchedulingSection(
            task: task,
            isEditing: true,
            taskLists: [],
            hasDueDate: $hasDueDate,
            dueDate: $dueDate,
            priority: $priority,
            selectedList: $selectedList
        )
    }
}

#Preview("View Mode") {
    @Previewable @State var hasDueDate = true
    @Previewable @State var dueDate = Date()
    @Previewable @State var priority = Constants.TaskPriority.high
    @Previewable @State var selectedList: TaskListEntity? = nil

    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Review code"
    task.dueDate = Date()
    task.priority = 2

    return Form {
        TaskDetailSchedulingSection(
            task: task,
            isEditing: false,
            taskLists: [],
            hasDueDate: $hasDueDate,
            dueDate: $dueDate,
            priority: $priority,
            selectedList: $selectedList
        )
    }
}
