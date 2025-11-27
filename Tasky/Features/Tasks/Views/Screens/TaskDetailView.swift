//
//  TaskDetailView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//  Redesigned with Things 3 style on 26.11.2025.
//

import SwiftUI
internal import CoreData

/// Things 3 inspired editable task detail view
struct TaskDetailView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let task: TaskEntity

    // MARK: - State - Core
    @State private var title: String
    @State private var notes: String
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool

    // MARK: - State - Date & Time
    @State private var dueDate: Date?
    @State private var scheduledStartTime: Date?
    @State private var scheduledEndTime: Date?

    // MARK: - State - Options
    @State private var priority: Constants.TaskPriority
    @State private var selectedList: TaskListEntity?
    @State private var isRecurring: Bool
    @State private var selectedDays: Set<Int>
    @State private var recurrenceFrequency: WeekdaySelector.RecurrenceFrequency

    // MARK: - State - Tags & Subtasks
    @State private var selectedTags: Set<TagEntity>
    @State private var isSubtasksExpanded = false
    @State private var isTagsExpanded = false

    // MARK: - State - Expansion
    @State private var isNotesExpanded: Bool
    @State private var isDateExpanded = false
    @State private var isTimeExpanded = false
    @State private var isRepeatExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isListExpanded = false
    @State private var showDateCalendar = false

    // MARK: - State - UI
    @State private var showDeleteConfirmation = false
    @State private var showFullTimer = false
    @State private var hasChanges = false

    // MARK: - Computed Properties
    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    /// Timer is active for THIS task (used for FAB visibility)
    private var isTimerActiveForThisTask: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }

    /// Check if task is scheduled for today (can be focused)
    private var isTaskScheduledForToday: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today

        // Check due date
        if let dueDate = task.dueDate {
            let dueDateStart = calendar.startOfDay(for: dueDate)
            if dueDateStart >= today && dueDateStart < tomorrow {
                return true
            }
            // Also include overdue tasks
            if dueDateStart < today {
                return true
            }
        }

        // Check scheduled time
        if let scheduledTime = task.scheduledTime {
            let scheduledStart = calendar.startOfDay(for: scheduledTime)
            if scheduledStart >= today && scheduledStart < tomorrow {
                return true
            }
        }

        return false
    }

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, timerViewModel: FocusTimerViewModel, task: TaskEntity) {
        self.viewModel = viewModel
        self.timerViewModel = timerViewModel
        self.task = task

        // Initialize state from task
        _title = State(initialValue: task.title)
        _notes = State(initialValue: task.notes ?? "")
        _dueDate = State(initialValue: task.dueDate)
        _scheduledStartTime = State(initialValue: task.scheduledTime)
        _scheduledEndTime = State(initialValue: task.scheduledEndTime)
        _priority = State(initialValue: Constants.TaskPriority(rawValue: task.priority) ?? .none)
        _selectedList = State(initialValue: task.taskList)
        _isRecurring = State(initialValue: task.isRecurring)

        // Parse recurrence days from stored string
        _selectedDays = State(initialValue: Set(task.recurrenceDayNumbers))
        _recurrenceFrequency = State(initialValue: task.isRecurring ? .weekly : .weekly)
        _isNotesExpanded = State(initialValue: !(task.notes ?? "").isEmpty)

        // Initialize tags
        _selectedTags = State(initialValue: Set(task.tagsArray))
        _isSubtasksExpanded = State(initialValue: task.hasSubtasks)
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: Constants.Spacing.sm) {
                    // Title Input
                    titleSection

                    // Notes Row
                    notesRow

                    // Subtasks Section
                    subtasksRow

                    // Date Row
                    dateRow

                    // Time Row
                    timeRow

                    // Repeat Row
                    repeatRow

                    // Priority Row
                    priorityRow

                    // List Row
                    listRow

                    // Tags Row
                    tagsRow

                    // Footer info
                    footerSection
                }
                .padding(.horizontal, Constants.Spacing.lg)
                .padding(.top, Constants.Spacing.md)
                .padding(.bottom, Constants.Spacing.xl)
            }
            .background(Color(.systemGroupedBackground))

            // Focus FAB (only for incomplete tasks scheduled for today)
            if !task.isCompleted && (isTaskScheduledForToday || isTimerActiveForThisTask) {
                FocusFABView(
                    timerViewModel: timerViewModel,
                    task: task,
                    showFullTimer: $showFullTimer
                )
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: Constants.Spacing.md) {
                    // More menu (native iOS pattern)
                    Menu {
                        Button {
                            HapticManager.shared.lightImpact()
                            Task {
                                await viewModel.toggleTaskCompletion(task)
                            }
                        } label: {
                            Label(
                                task.isCompleted ? "Mark Incomplete" : "Mark Complete",
                                systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle"
                            )
                        }

                        Divider()

                        Button(role: .destructive) {
                            HapticManager.shared.lightImpact()
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 17))
                            .foregroundStyle(.secondary)
                    }

                    // Save button
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $showFullTimer) {
            // Show timer for the task that's actually being focused, not the task being viewed
            if let focusedTask = timerViewModel.currentTask {
                FocusTimerSheet(viewModel: timerViewModel, task: focusedTask)
            } else {
                FocusTimerSheet(viewModel: timerViewModel, task: task)
            }
        }
        .alert("Delete Task", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteTask()
            }
        } message: {
            Text("Are you sure you want to delete \"\(task.title)\"?")
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Title Section
    private var titleSection: some View {
        TextField("Task title", text: $title, axis: .vertical)
            .font(.title3)
            .textInputAutocapitalization(.sentences)
            .focused($isTitleFocused)
            .submitLabel(.done)
            .lineLimit(1...5)
            .strikethrough(task.isCompleted, color: .secondary)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.vertical, Constants.Spacing.md)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }

    // MARK: - Notes Row
    private var notesRow: some View {
        ExpandableOptionRow(
            icon: "note.text",
            iconColor: .orange,
            label: "Add notes",
            value: notes.isEmpty ? nil : truncatedNotes,
            isExpanded: $isNotesExpanded,
            canClear: true,
            onClear: {
                notes = ""
                isNotesExpanded = false
            }
        ) {
            TextEditor(text: $notes)
                .font(.body)
                .frame(minHeight: 80, maxHeight: 150)
                .focused($isNotesFocused)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, -4)
        }
    }

    private var truncatedNotes: String {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 30 {
            return String(trimmed.prefix(30)) + "..."
        }
        return trimmed
    }

    // MARK: - Date Row
    private var dateRow: some View {
        ExpandableOptionRow(
            icon: "calendar",
            iconColor: .blue,
            label: "No date",
            value: QuickDateSelector.formatDate(dueDate),
            isExpanded: $isDateExpanded,
            canClear: true,
            onClear: {
                dueDate = nil
                isDateExpanded = false
            }
        ) {
            QuickDateSelector(
                selectedDate: $dueDate,
                showCalendar: $showDateCalendar
            )
        }
    }

    // MARK: - Time Row
    private var timeRow: some View {
        ExpandableOptionRow(
            icon: "clock",
            iconColor: .orange,
            label: "Add time",
            value: DurationSelector.formatTimeRange(start: scheduledStartTime, end: scheduledEndTime),
            isExpanded: $isTimeExpanded,
            canClear: true,
            onClear: {
                scheduledStartTime = nil
                scheduledEndTime = nil
                isTimeExpanded = false
            }
        ) {
            DurationSelector(
                startTime: $scheduledStartTime,
                endTime: $scheduledEndTime,
                referenceDate: dueDate ?? Date()
            )
        }
    }

    // MARK: - Repeat Row
    private var repeatRow: some View {
        ExpandableOptionRow(
            icon: "repeat",
            iconColor: .purple,
            label: "No repeat",
            value: WeekdaySelector.formatRecurrence(
                isRecurring: isRecurring,
                frequency: recurrenceFrequency,
                days: selectedDays
            ),
            isExpanded: $isRepeatExpanded,
            canClear: true,
            onClear: {
                isRecurring = false
                selectedDays.removeAll()
                isRepeatExpanded = false
            }
        ) {
            WeekdaySelector(
                isRecurring: $isRecurring,
                selectedDays: $selectedDays,
                frequency: $recurrenceFrequency
            )
        }
    }

    // MARK: - Priority Row
    private var priorityRow: some View {
        ExpandableOptionRow(
            icon: "flag.fill",
            iconColor: priority.color,
            label: "No priority",
            value: priority == .none ? nil : priority.displayName,
            isExpanded: $isPriorityExpanded,
            canClear: true,
            onClear: {
                priority = .none
                isPriorityExpanded = false
            }
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.sm) {
                    ForEach(Constants.TaskPriority.allCases, id: \.rawValue) { p in
                        priorityChip(p)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func priorityChip(_ p: Constants.TaskPriority) -> some View {
        let isSelected = priority == p

        Button {
            withAnimation(animation) {
                priority = p
                if p != .none {
                    isPriorityExpanded = false
                }
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                if p != .none {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(p.color)
                }
                Text(p.displayName)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - List Row
    private var listRow: some View {
        ExpandableOptionRow(
            icon: selectedList?.iconName ?? "tray.fill",
            iconColor: selectedList?.color ?? .gray,
            label: "Inbox",
            value: selectedList?.name,
            isExpanded: $isListExpanded
        ) {
            VStack(spacing: 0) {
                listOption(nil, name: "Inbox", icon: "tray.fill", color: .gray)
                ForEach(viewModel.taskLists) { list in
                    listOption(list, name: list.name, icon: list.iconName ?? "list.bullet", color: list.color)
                }
            }
        }
    }

    @ViewBuilder
    private func listOption(_ list: TaskListEntity?, name: String, icon: String, color: Color) -> some View {
        let isSelected = (list == nil && selectedList == nil) || (list != nil && selectedList?.id == list?.id)

        Button {
            withAnimation(animation) {
                selectedList = list
                isListExpanded = false
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: Constants.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 24)

                Text(name)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.vertical, Constants.Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subtasks Row
    private var subtasksRow: some View {
        ExpandableOptionRow(
            icon: "checklist",
            iconColor: .blue,
            label: "Subtasks",
            value: task.subtasksProgressString,
            isExpanded: $isSubtasksExpanded,
            canClear: false
        ) {
            SubtaskListView(viewModel: viewModel, task: task)
        }
    }

    // MARK: - Tags Row
    private var tagsRow: some View {
        ExpandableOptionRow(
            icon: "tag",
            iconColor: .purple,
            label: "Tags",
            value: selectedTags.isEmpty ? nil : "\(selectedTags.count) tag\(selectedTags.count == 1 ? "" : "s")",
            isExpanded: $isTagsExpanded,
            canClear: true,
            onClear: {
                selectedTags.removeAll()
                isTagsExpanded = false
            }
        ) {
            TagPickerView(viewModel: viewModel, selectedTags: $selectedTags)
        }
    }

    // MARK: - Footer Section
    private var footerSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            // Created date
            Text("Created \(task.createdAt, style: .date)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            // Completed date
            if task.isCompleted, let completedAt = task.completedAt {
                Text("Completed \(completedAt, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.vertical, Constants.Spacing.md)
    }

    // MARK: - Methods
    private func saveChanges() {
        Task {
            let recurrenceDays: [Int]? = isRecurring && !selectedDays.isEmpty
                ? Array(selectedDays).sorted()
                : nil

            await viewModel.updateTask(
                task,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: notes.isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines),
                dueDate: dueDate,
                scheduledTime: scheduledStartTime,
                scheduledEndTime: scheduledEndTime,
                priority: priority.rawValue,
                list: selectedList,
                isRecurring: isRecurring,
                recurrenceDays: recurrenceDays
            )

            // Save tags
            await viewModel.setTags(Array(selectedTags), for: task)

            HapticManager.shared.success()
            dismiss()
        }
    }

    private func deleteTask() {
        Task {
            await viewModel.deleteTask(task)
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("Active Task") {
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
                task.focusTimeSeconds = 1800
                return task
            }()
        )
    }
}

#Preview("Completed Task") {
    NavigationStack {
        TaskDetailView(
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            timerViewModel: FocusTimerViewModel(),
            task: {
                let context = PersistenceController.preview.viewContext
                let task = TaskEntity(context: context)
                task.id = UUID()
                task.title = "Finished task"
                task.isCompleted = true
                task.completedAt = Date()
                task.createdAt = Date().addingTimeInterval(-86400)
                return task
            }()
        )
    }
}

#Preview("Minimal Task") {
    NavigationStack {
        TaskDetailView(
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            timerViewModel: FocusTimerViewModel(),
            task: {
                let context = PersistenceController.preview.viewContext
                let task = TaskEntity(context: context)
                task.id = UUID()
                task.title = "Simple task"
                task.isCompleted = false
                task.createdAt = Date()
                return task
            }()
        )
    }
}
