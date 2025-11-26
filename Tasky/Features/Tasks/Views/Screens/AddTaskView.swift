//
//  AddTaskView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//  Redesigned with Things 3 style on 26.11.2025.
//

import SwiftUI

/// Things 3 inspired task creation view with inline expandable options
struct AddTaskView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var viewModel: TaskListViewModel

    // MARK: - Properties
    let preselectedScheduledTime: Date?
    let preselectedScheduledEndTime: Date?

    // MARK: - State - Core
    @State private var title = ""
    @State private var notes = ""
    @FocusState private var isTitleFocused: Bool
    @FocusState private var isNotesFocused: Bool

    // MARK: - State - Date & Time
    @State private var dueDate: Date? = Date()
    @State private var scheduledStartTime: Date?
    @State private var scheduledEndTime: Date?

    // MARK: - State - Options
    @State private var priority: Constants.TaskPriority = .none
    @State private var selectedList: TaskListEntity?
    @State private var isRecurring = false
    @State private var selectedDays: Set<Int> = []
    @State private var recurrenceFrequency: WeekdaySelector.RecurrenceFrequency = .weekly

    // MARK: - State - Expansion
    @State private var isNotesExpanded = false
    @State private var isDateExpanded = false
    @State private var isTimeExpanded = false
    @State private var isRepeatExpanded = false
    @State private var isPriorityExpanded = false
    @State private var isListExpanded = false
    @State private var showDateCalendar = false

    // MARK: - Computed Properties
    private var canAdd: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, preselectedScheduledTime: Date? = nil, preselectedScheduledEndTime: Date? = nil) {
        self.viewModel = viewModel
        self.preselectedScheduledTime = preselectedScheduledTime
        self.preselectedScheduledEndTime = preselectedScheduledEndTime

        if let preselectedTime = preselectedScheduledTime {
            _scheduledStartTime = State(initialValue: preselectedTime)
            let calendar = Calendar.current
            _dueDate = State(initialValue: calendar.startOfDay(for: preselectedTime))
            if let preselectedEnd = preselectedScheduledEndTime {
                _scheduledEndTime = State(initialValue: preselectedEnd)
            } else {
                _scheduledEndTime = State(initialValue: calendar.date(byAdding: .hour, value: 1, to: preselectedTime))
            }
            _isTimeExpanded = State(initialValue: true)
        }
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(spacing: Constants.Spacing.sm) {
                // Title Input
                titleSection

                // Notes Row
                notesRow

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
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.top, Constants.Spacing.md)
            .padding(.bottom, Constants.Spacing.xxxl)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("New Task")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
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
                .fontWeight(.semibold)
                .disabled(!canAdd)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
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

    // MARK: - Title Section
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("What do you want to do?", text: $title, axis: .vertical)
                .font(.title3)
                .textInputAutocapitalization(.sentences)
                .focused($isTitleFocused)
                .submitLabel(.done)
                .lineLimit(1...3)
                .padding(.horizontal, Constants.Spacing.lg)
                .padding(.vertical, Constants.Spacing.md)
        }
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
                .padding(.horizontal, -4) // Align with row padding
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isNotesFocused = true
                    }
                }
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
                // Inbox option
                listOption(nil, name: "Inbox", icon: "tray.fill", color: .gray)

                // Custom lists
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

    // MARK: - Add Task
    private func addTask() {
        Task {
            // Convert recurrence days to array
            let recurrenceDays: [Int]? = isRecurring && !selectedDays.isEmpty
                ? Array(selectedDays).sorted()
                : nil

            await viewModel.createTask(
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

            HapticManager.shared.success()
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("Empty") {
    NavigationStack {
        AddTaskView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
    }
}

#Preview("With Preselected Time") {
    NavigationStack {
        AddTaskView(
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            preselectedScheduledTime: Date(),
            preselectedScheduledEndTime: Date().addingTimeInterval(3600)
        )
    }
}
