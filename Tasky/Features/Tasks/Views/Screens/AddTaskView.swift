//
//  AddTaskView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// View for adding a new task
struct AddTaskView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel

    // MARK: - Properties
    let preselectedScheduledTime: Date?
    let preselectedScheduledEndTime: Date?

    // MARK: - State
    @State private var title = ""
    @State private var notes = ""
    @State private var hasDueDate = true  // Default to today for easier task creation
    @State private var dueDate = Date()
    @State private var hasScheduledTime = false
    @State private var scheduledTime = Date()
    @State private var scheduledEndTime = Date()
    @State private var priority: Constants.TaskPriority = .none
    @State private var selectedList: TaskListEntity?
    @State private var isRecurring = false
    @State private var selectedDays: Set<Int> = []

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, preselectedScheduledTime: Date? = nil, preselectedScheduledEndTime: Date? = nil) {
        self.viewModel = viewModel
        self.preselectedScheduledTime = preselectedScheduledTime
        self.preselectedScheduledEndTime = preselectedScheduledEndTime
        _hasScheduledTime = State(initialValue: preselectedScheduledTime != nil)
        if let preselectedTime = preselectedScheduledTime {
            _scheduledTime = State(initialValue: preselectedTime)
            // Set dueDate to match the scheduled time's date
            let calendar = Calendar.current
            _dueDate = State(initialValue: calendar.startOfDay(for: preselectedTime))
            // Use preselected end time if provided, otherwise default to 1 hour after start time
            if let preselectedEnd = preselectedScheduledEndTime {
                _scheduledEndTime = State(initialValue: preselectedEnd)
            } else {
                _scheduledEndTime = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: preselectedTime) ?? preselectedTime)
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // Title Section
                Section {
                    TextField("Task title", text: $title)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                } header: {
                    Text("Title")
                }

                // Notes Section
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                } header: {
                    Text("Notes")
                } footer: {
                    Text("Optional additional details")
                        .font(.caption)
                }

                // Due Date Section
                Section {
                    Toggle("Set due date", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _ in
                            HapticManager.shared.selectionChanged()
                        }

                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $dueDate,
                            displayedComponents: [.date]
                        )
                    }
                } header: {
                    Text("Due Date")
                }

                // Scheduled Time Section
                Section {
                    Toggle("Schedule time", isOn: $hasScheduledTime)
                        .onChange(of: hasScheduledTime) { _ in
                            HapticManager.shared.selectionChanged()
                        }

                    if hasScheduledTime {
                        DatePicker(
                            "Start time",
                            selection: $scheduledTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )

                        DatePicker(
                            "End time",
                            selection: $scheduledEndTime,
                            displayedComponents: [.hourAndMinute]
                        )
                    }
                } header: {
                    Text("Scheduled Time")
                } footer: {
                    if preselectedScheduledTime != nil {
                        Text("Pre-selected from calendar")
                            .font(.caption)
                    } else if hasScheduledTime {
                        Text("Schedule a specific time block for this task")
                            .font(.caption)
                    }
                }

                // Recurrence Section
                Section {
                    Toggle("Recurring task", isOn: $isRecurring)
                        .onChange(of: isRecurring) { _ in
                            HapticManager.shared.selectionChanged()
                        }

                    if isRecurring {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Repeat on:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                ForEach(Array(zip([1, 2, 3, 4, 5, 6, 7], ["M", "T", "W", "T", "F", "S", "S"])), id: \.0) { day, label in
                                    Button {
                                        if selectedDays.contains(day) {
                                            selectedDays.remove(day)
                                        } else {
                                            selectedDays.insert(day)
                                        }
                                        HapticManager.shared.selectionChanged()
                                    } label: {
                                        Text(label)
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 36, height: 36)
                                            .background(
                                                Circle()
                                                    .fill(selectedDays.contains(day) ? Color.blue : Color(.tertiarySystemFill))
                                            )
                                            .foregroundStyle(selectedDays.contains(day) ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Recurrence")
                } footer: {
                    if isRecurring {
                        Text(selectedDays.isEmpty ? "Select at least one day for recurrence" : "Task will repeat on selected days")
                            .font(.caption)
                    }
                }

                // Priority Section
                Section {
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
                } header: {
                    Text("Priority")
                }

                // List Section
                Section {
                    Picker("List", selection: $selectedList) {
                        Text("None").tag(nil as TaskListEntity?)
                        ForEach(viewModel.taskLists) { list in
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
                } header: {
                    Text("List")
                } footer: {
                    Text("Organize task into a specific list")
                        .font(.caption)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Methods

    private func addTask() {
        Task {
            await viewModel.createTask(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: hasDueDate ? dueDate : nil,
                scheduledTime: hasScheduledTime ? scheduledTime : nil,
                scheduledEndTime: hasScheduledTime ? scheduledEndTime : nil,
                priority: priority.rawValue,
                list: selectedList,
                isRecurring: isRecurring,
                recurrenceDays: isRecurring && !selectedDays.isEmpty ? Array(selectedDays).sorted() : nil
            )
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    AddTaskView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
