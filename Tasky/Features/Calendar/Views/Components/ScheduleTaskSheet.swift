//
//  ScheduleTaskSheet.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Enhanced sheet for scheduling tasks with editable time picker
struct ScheduleTaskSheet: View {
    @StateObject var viewModel: TaskListViewModel
    let initialStartTime: Date
    let initialEndTime: Date?
    let unscheduledTasks: [TaskEntity]
    let onDismiss: () -> Void

    // MARK: - State
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var showingCreateNew = false
    @State private var showTimePicker = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Duration Presets
    private let durationPresets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("45m", 45),
        ("1h", 60),
        ("1.5h", 90),
        ("2h", 120)
    ]

    // MARK: - Initialization
    init(
        viewModel: TaskListViewModel,
        selectedTime: Date,
        selectedEndTime: Date?,
        selectedTimeRange: String? = nil,
        unscheduledTasks: [TaskEntity],
        onDismiss: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.initialStartTime = selectedTime
        self.initialEndTime = selectedEndTime
        self.unscheduledTasks = unscheduledTasks
        self.onDismiss = onDismiss

        // Initialize state
        _startTime = State(initialValue: selectedTime.rounded(toNearest: 15))
        _endTime = State(initialValue: (selectedEndTime ?? selectedTime.addingTimeInterval(3600)).rounded(toNearest: 15))
    }

    // MARK: - Computed Properties
    private var formattedTimeRange: String {
        AppDateFormatters.formatTimeRange(start: startTime, end: endTime)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: startTime)
    }

    private var durationMinutes: Int {
        Int(endTime.timeIntervalSince(startTime) / 60)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Time header card
                    timeHeaderCard

                    // Duration presets
                    durationPresetsSection

                    // Divider
                    dividerSection

                    // Create new task button
                    createNewTaskButton

                    // Unscheduled tasks section
                    unscheduledTasksSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Schedule Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCreateNew) {
                AddTaskView(
                    viewModel: viewModel,
                    preselectedScheduledTime: startTime,
                    preselectedScheduledEndTime: endTime
                )
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Time Header Card
    private var timeHeaderCard: some View {
        VStack(spacing: Constants.Spacing.md) {
            // Date label
            Text(formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Editable time range
            Button {
                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                    showTimePicker.toggle()
                }
                HapticManager.shared.lightImpact()
            } label: {
                HStack(spacing: Constants.Spacing.sm) {
                    // Start time
                    VStack(spacing: 2) {
                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(startTime))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 80)

                    // Arrow
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)

                    // End time
                    VStack(spacing: 2) {
                        Text("End")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatTime(endTime))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .frame(minWidth: 80)
                }
                .padding(.vertical, Constants.Spacing.sm)
                .padding(.horizontal, Constants.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium)
                        .fill(Color(.tertiarySystemFill))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Time range: \(formattedTimeRange)")
            .accessibilityHint("Tap to edit times")

            // Inline time pickers (when expanded)
            if showTimePicker {
                timePickersSection
            }

            // Duration badge
            HStack(spacing: Constants.Spacing.xs) {
                Image(systemName: "clock")
                    .font(.caption)
                Text("\(durationMinutes) min")
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, Constants.Spacing.sm)
            .padding(.vertical, Constants.Spacing.xs)
            .background(
                Capsule()
                    .fill(Color(.quaternarySystemFill))
            )
        }
        .padding(Constants.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    // MARK: - Time Pickers Section
    private var timePickersSection: some View {
        VStack(spacing: Constants.Spacing.md) {
            // Start time picker
            HStack {
                Text("Start")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                DatePicker(
                    "",
                    selection: $startTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: startTime) { _, newValue in
                    // Ensure end time is after start time
                    if endTime <= newValue {
                        endTime = newValue.addingTimeInterval(1800) // +30 min
                    }
                    HapticManager.shared.selectionChanged()
                }

                Spacer()
            }

            // End time picker
            HStack {
                Text("End")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 50, alignment: .leading)

                DatePicker(
                    "",
                    selection: $endTime,
                    in: startTime.addingTimeInterval(900)..., // Min 15 min after start
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .onChange(of: endTime) { _, _ in
                    HapticManager.shared.selectionChanged()
                }

                Spacer()
            }
        }
        .padding(.horizontal, Constants.Spacing.md)
        .padding(.vertical, Constants.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium)
                .fill(Color(.secondarySystemBackground))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Duration Presets Section
    private var durationPresetsSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Quick duration")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Constants.Spacing.lg)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.sm) {
                    ForEach(durationPresets, id: \.minutes) { preset in
                        durationPresetButton(label: preset.label, minutes: preset.minutes)
                    }
                }
                .padding(.horizontal, Constants.Spacing.lg)
            }
        }
        .padding(.vertical, Constants.Spacing.sm)
    }

    // MARK: - Duration Preset Button
    private func durationPresetButton(label: String, minutes: Int) -> some View {
        let isSelected = durationMinutes == minutes

        return Button {
            withAnimation(reduceMotion ? .none : .spring(response: 0.25, dampingFraction: 0.7)) {
                endTime = startTime.addingTimeInterval(TimeInterval(minutes * 60))
            }
            HapticManager.shared.selectionChanged()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, Constants.Spacing.md)
                .padding(.vertical, Constants.Spacing.sm)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) duration")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Divider Section
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)

            Text("or")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, Constants.Spacing.sm)

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.vertical, Constants.Spacing.md)
    }

    // MARK: - Create New Task Button
    private var createNewTaskButton: some View {
        Button {
            showingCreateNew = true
            HapticManager.shared.lightImpact()
        } label: {
            HStack(spacing: Constants.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)

                Text("Create new task")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Constants.Spacing.md)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, Constants.Spacing.md)
        .accessibilityLabel("Create new task")
        .accessibilityHint("Create a new task for the selected time")
    }

    // MARK: - Unscheduled Tasks Section
    @ViewBuilder
    private var unscheduledTasksSection: some View {
        if unscheduledTasks.isEmpty {
            VStack(spacing: Constants.Spacing.md) {
                Image(systemName: "tray")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)

                Text("No unscheduled tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.xxxl)
        } else {
            VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
                Text("Schedule existing task")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Constants.Spacing.lg)
                    .padding(.top, Constants.Spacing.md)

                LazyVStack(spacing: Constants.Spacing.sm) {
                    ForEach(unscheduledTasks) { task in
                        unscheduledTaskRow(task)
                    }
                }
                .padding(.horizontal, Constants.Spacing.md)
            }
        }
    }

    // MARK: - Unscheduled Task Row
    private func unscheduledTaskRow(_ task: TaskEntity) -> some View {
        Button {
            Task {
                await scheduleTask(task)
            }
        } label: {
            HStack(spacing: Constants.Spacing.sm) {
                // Priority indicator
                Circle()
                    .fill(priorityColor(for: task.priority))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let list = task.taskList {
                        HStack(spacing: 4) {
                            Image(systemName: list.iconName ?? "list.bullet")
                                .font(.caption2)
                            Text(list.name)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(list.color)
                    }
                }

                Spacer()

                Image(systemName: "arrow.right.circle")
                    .font(.body)
                    .foregroundStyle(Color.accentColor)
            }
            .padding(Constants.Spacing.md)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Schedule \(task.title)")
        .accessibilityHint("Schedule this task for \(formattedTimeRange)")
    }

    // MARK: - Helper Methods
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func priorityColor(for priority: Int16) -> Color {
        switch priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .yellow
        default: return .gray.opacity(0.3)
        }
    }

    private func scheduleTask(_ task: TaskEntity) async {
        await viewModel.scheduleTask(
            task,
            startTime: startTime,
            endTime: endTime
        )
        HapticManager.shared.success()
        onDismiss()
    }
}


// MARK: - Preview
#Preview("With Tasks") {
    let controller = PersistenceController.preview
    let context = controller.viewContext

    let tasks = (1...3).map { i in
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Unscheduled Task \(i)"
        task.isCompleted = false
        task.priority = Int16(i % 4)
        return task
    }

    return ScheduleTaskSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: controller)),
        selectedTime: Date(),
        selectedEndTime: Date().addingTimeInterval(3600),
        unscheduledTasks: tasks,
        onDismiss: {}
    )
}

#Preview("Empty") {
    ScheduleTaskSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        selectedTime: Date(),
        selectedEndTime: nil,
        selectedTimeRange: nil,
        unscheduledTasks: [],
        onDismiss: {}
    )
}
