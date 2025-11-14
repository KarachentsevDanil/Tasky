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
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let task: TaskEntity

    // MARK: - State
    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var priority: Constants.TaskPriority
    @State private var selectedList: TaskListEntity?
    @State private var isEditing = false
    @State private var showFullTimer = false

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, timerViewModel: FocusTimerViewModel, task: TaskEntity) {
        self.viewModel = viewModel
        self.timerViewModel = timerViewModel
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
                        .submitLabel(.done)
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
                    .accessibilityLabel(task.isCompleted ? "Mark as incomplete" : "Mark as complete")
                    .accessibilityHint("Toggle task completion status")
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

            // Focus Timer Section
            if !task.isCompleted {
                TaskDetailFocusTimerSection(
                    task: task,
                    timerViewModel: timerViewModel,
                    showFullTimer: $showFullTimer
                )
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

            // Scheduling Section (Due Date, Priority, List)
            TaskDetailSchedulingSection(
                task: task,
                isEditing: isEditing,
                taskLists: viewModel.taskLists,
                hasDueDate: $hasDueDate,
                dueDate: $dueDate,
                priority: $priority,
                selectedList: $selectedList
            )

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
                    .accessibilityLabel("Delete task")
                    .accessibilityHint("Permanently delete this task")
                }
            }
        }
        .navigationTitle("Task Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFullTimer) {
            FocusTimerFullView(viewModel: timerViewModel, task: task, onDismiss: {
                showFullTimer = false
            })
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing {
                        saveChanges()
                    }
                    isEditing.toggle()
                }
                .accessibilityLabel(isEditing ? "Save changes" : "Edit task")
                .accessibilityHint(isEditing ? "Save your edits and exit editing mode" : "Enter editing mode to modify task details")
            }

            if isEditing {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        resetChanges()
                        isEditing = false
                    }
                    .accessibilityLabel("Cancel editing")
                    .accessibilityHint("Discard changes and exit editing mode")
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
            timerViewModel: FocusTimerViewModel(),
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
