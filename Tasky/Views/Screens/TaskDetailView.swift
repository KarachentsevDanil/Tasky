//
//  TaskDetailView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI
internal import CoreData

/// View for viewing and editing task details
struct TaskDetailView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel
    let task: TaskEntity

    // MARK: - State
    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: Constants.TaskPriority
    @State private var selectedList: TaskListEntity?
    @State private var isEditing = false

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, task: TaskEntity) {
        self.viewModel = viewModel
        self.task = task

        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _dueDate = State(initialValue: task.dueDate ?? Date())
        _priority = State(initialValue: Constants.TaskPriority(rawValue: task.priority) ?? .none)
        _selectedList = State(initialValue: task.taskList)
    }

    // MARK: - Body
    var body: some View {
        Form {
            // Title Section
            Section {
                if isEditing {
                    TextField("Task title", text: $title)
                        .textInputAutocapitalization(.sentences)
                } else {
                    Text(task.title)
                        .font(.headline)
                }
            } header: {
                Text("Title")
            }

            // Status Section
            Section {
                HStack {
                    Text("Status")
                    Spacer()
                    Button(action: {
                        Task {
                            await viewModel.toggleTaskCompletion(task)
                        }
                    }) {
                        Label(
                            task.isCompleted ? "Completed" : "Incomplete",
                            systemImage: task.isCompleted ? "checkmark.circle.fill" : "circle"
                        )
                        .foregroundStyle(task.isCompleted ? .green : .primary)
                    }
                }

                if task.isCompleted, let completedAt = task.completedAt {
                    HStack {
                        Text("Completed at")
                        Spacer()
                        Text(completedAt, style: .date)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Notes Section
            Section {
                if isEditing {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } else {
                    if !notes.isEmpty {
                        Text(notes)
                    } else {
                        Text("No notes")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Notes")
            }

            // Due Date Section
            Section {
                if isEditing {
                    Toggle("Set due date", isOn: $hasDueDate)

                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
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
                        ForEach(viewModel.taskLists, id: \.id) { list in
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

            // Metadata Section
            Section {
                HStack {
                    Text("Created")
                    Spacer()
                    Text(task.createdAt, style: .date)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Info")
            }

            // Delete Section
            if !isEditing {
                Section {
                    Button(role: .destructive) {
                        deleteTask()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Task", systemImage: Constants.Icons.delete)
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
            }

            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetChanges()
                        isEditing = false
                    }
                }
            }
        }
    }

    // MARK: - Methods

    private func saveChanges() {
        Task {
            await viewModel.updateTask(
                task,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: hasDueDate ? dueDate : nil,
                priority: priority.rawValue,
                list: selectedList
            )
        }
    }

    private func resetChanges() {
        title = task.title
        notes = task.notes ?? ""
        hasDueDate = task.dueDate != nil
        dueDate = task.dueDate ?? Date()
        priority = Constants.TaskPriority(rawValue: task.priority) ?? .none
        selectedList = task.taskList
    }

    private func deleteTask() {
        Task {
            await viewModel.deleteTask(task)
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        TaskDetailView(
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            task: {
                let context = PersistenceController.preview.viewContext
                let task = TaskEntity(context: context)
                task.id = UUID()
                task.title = "Review code changes"
                task.notes = "Check for edge cases and performance issues"
                task.isCompleted = false
                task.dueDate = Date()
                task.createdAt = Date()
                task.priority = 2
                return task
            }()
        )
    }
}
