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
                Section {
                    // Timer Stats
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Total Focus Time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(task.formattedFocusTime)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                        }
                        Spacer()
                        Image(systemName: "flame.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 4)

                    // Timer Controls
                    if isTimerActive {
                        // Active timer - show current state
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(timerViewModel.sessionType)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Text(timerViewModel.formattedTime)
                                        .font(.system(.title, design: .rounded).weight(.bold))
                                        .monospacedDigit()
                                        .foregroundStyle(timerViewModel.timerState == .running ? .orange : .yellow)
                                }
                                Spacer()
                                if timerViewModel.timerState == .paused {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Color.yellow)
                                            .frame(width: 8, height: 8)
                                        Text("Paused")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            // Timer buttons
                            HStack(spacing: 12) {
                                Button {
                                    timerViewModel.stopTimer()
                                } label: {
                                    HStack {
                                        Image(systemName: "stop.fill")
                                        Text("Stop")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)

                                Button {
                                    switch timerViewModel.timerState {
                                    case .running:
                                        timerViewModel.pauseTimer()
                                    case .paused:
                                        timerViewModel.resumeTimer()
                                    default:
                                        break
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: timerViewModel.timerState == .running ? "pause.fill" : "play.fill")
                                        Text(timerViewModel.timerState == .running ? "Pause" : "Resume")
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }

                            // View full timer button
                            Button {
                                showFullTimer = true
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    Text("Full Screen")
                                }
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.secondary)
                        }
                        .padding(.vertical, 4)
                    } else {
                        // No active timer - show start button
                        Button {
                            timerViewModel.startTimer(for: task)
                        } label: {
                            HStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                Text("Start Focus Session")
                                    .font(.body.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                } header: {
                    Text("Focus Timer")
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

    // MARK: - Computed Properties

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
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
