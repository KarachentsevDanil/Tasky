//
//  UpcomingView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Unified view with Today/Week/Month modes
struct UpcomingView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @StateObject private var dayCalendarViewModel: DayCalendarViewModel
    @State private var selectedDate = Date()
    @State private var selectedDateForFiltering: Date?
    @State private var showingAddTask = false
    @State private var selectedView: ViewMode = .day

    // MARK: - Initialization
    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _dayCalendarViewModel = StateObject(wrappedValue: DayCalendarViewModel(dataService: viewModel.dataService))
    }

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case upcoming = "Upcoming"
    }

    // MARK: - Computed Properties
    private var groupedTasks: [(date: Date, tasks: [TaskEntity])] {
        let calendar = Calendar.current
        let now = Date()

        // Determine filtering logic based on selected date
        let filteredTasks: [TaskEntity]

        if let filterDate = selectedDateForFiltering {
            let isToday = calendar.isDateInToday(filterDate)
            let isPast = filterDate < calendar.startOfDay(for: now)

            if isToday {
                // If today is selected, show all tasks >= today
                filteredTasks = viewModel.tasks.filter { task in
                    if let dueDate = task.dueDate {
                        return calendar.isDateInToday(dueDate) || dueDate > now
                    }
                    if let scheduledTime = task.scheduledTime {
                        return calendar.isDateInToday(scheduledTime) || scheduledTime > now
                    }
                    return task.dueDate == nil && task.scheduledTime == nil && !task.isCompleted
                }
            } else if isPast {
                // If past date is selected, show only tasks for that specific date
                filteredTasks = viewModel.tasks.filter { task in
                    if let dueDate = task.dueDate {
                        return calendar.isDate(dueDate, inSameDayAs: filterDate)
                    }
                    if let scheduledTime = task.scheduledTime {
                        return calendar.isDate(scheduledTime, inSameDayAs: filterDate)
                    }
                    return false
                }
            } else {
                // If future date is selected, show only tasks for that specific date
                filteredTasks = viewModel.tasks.filter { task in
                    if let dueDate = task.dueDate {
                        return calendar.isDate(dueDate, inSameDayAs: filterDate)
                    }
                    if let scheduledTime = task.scheduledTime {
                        return calendar.isDate(scheduledTime, inSameDayAs: filterDate)
                    }
                    return false
                }
            }
        } else {
            // No date selected, show all upcoming tasks (today and future)
            filteredTasks = viewModel.tasks.filter { task in
                if let dueDate = task.dueDate {
                    return calendar.isDateInToday(dueDate) || dueDate > now
                }
                if let scheduledTime = task.scheduledTime {
                    return calendar.isDateInToday(scheduledTime) || scheduledTime > now
                }
                return task.dueDate == nil && task.scheduledTime == nil && !task.isCompleted
            }
        }

        // Group tasks by date
        let grouped = Dictionary(grouping: filteredTasks) { task -> Date in
            if let dueDate = task.dueDate {
                return calendar.startOfDay(for: dueDate)
            }
            if let scheduledTime = task.scheduledTime {
                return calendar.startOfDay(for: scheduledTime)
            }
            return calendar.startOfDay(for: now)
        }

        // Sort by date and return as array of tuples
        return grouped.map { (date: $0.key, tasks: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // Month view properties (used by mini calendar)
    private var monthDates: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else {
            return []
        }

        var dates: [Date?] = []

        for weekOffset in 0..<6 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: monthFirstWeek.start) else {
                continue
            }

            for dayOffset in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    dates.append(date)
                }
            }
        }

        return dates
    }

    private var weekdaySymbols: [String] {
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker
                Picker("View", selection: $selectedView) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Divider()

                // Content based on selected view
                Group {
                    switch selectedView {
                    case .day:
                        dayView
                    case .upcoming:
                        upcomingView
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .task {
                viewModel.currentFilter = .all
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Day View
    private var dayView: some View {
        DayCalendarView(
            viewModel: dayCalendarViewModel,
            taskListViewModel: viewModel,
            timerViewModel: timerViewModel
        )
    }

    // MARK: - Upcoming View
    private var upcomingView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Mini Calendar
                miniCalendar

                Divider()

                // Upcoming Tasks List
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedTasks, id: \.date) { group in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(group.tasks) { task in
                                    NavigationLink {
                                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                                    } label: {
                                        UpcomingTaskRow(task: task, timerViewModel: timerViewModel) {
                                            Task {
                                                await viewModel.toggleTaskCompletion(task)
                                                HapticManager.shared.success()
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        } header: {
                            upcomingDateHeader(for: group.date)
                        }
                    }

                    if groupedTasks.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    }
                }
                .padding(.vertical)
            }
        }
    }

    // MARK: - Mini Calendar
    private var miniCalendar: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }

                Spacer()

                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
            }
            .padding(.horizontal)

            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDates, id: \.self) { date in
                    if let date = date {
                        miniCalendarDayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
    }

    private func miniCalendarDayCell(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)

        let incompleteTasks = tasksForDate.filter { !$0.isCompleted }
        let incompleteCount = incompleteTasks.count
        let hasCompletedAllTasks = !tasksForDate.isEmpty && incompleteTasks.isEmpty

        return Button {
            withAnimation {
                selectedDate = date
                selectedDateForFiltering = date
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 2) {
                Text(date, format: .dateTime.day())
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                    )

                // Task indicators
                if hasCompletedAllTasks {
                    // Green checkmark for all tasks completed
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                } else if incompleteCount > 0 {
                    // Orange circle with task count
                    Text("\(incompleteCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color.orange)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .id(date)
    }

    private func upcomingDateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)

        let dateText: String = {
            if isToday {
                return "Today"
            } else if isTomorrow {
                return "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE MMM d"
                return formatter.string(from: date)
            }
        }()

        let fullDateText: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM d"
            return formatter.string(from: date)
        }()

        return HStack(spacing: 8) {
            Text(dateText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if isToday || isTomorrow {
                Text("· \(fullDateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    private func dateSection(for date: Date, tasks: [TaskEntity]) -> some View {
        Section {
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    NavigationLink {
                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                    } label: {
                        UpcomingTaskRow(task: task, timerViewModel: timerViewModel) {
                            Task {
                                await viewModel.toggleTaskCompletion(task)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            dateHeader(for: date)
        }
    }

    // MARK: - Date Header
    private func dateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)

        let dateText: String = {
            if isToday {
                return "Today"
            } else if isTomorrow {
                return "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE MMM d"
                return formatter.string(from: date)
            }
        }()

        let fullDateText: String = {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE MMM d"
            return formatter.string(from: date)
        }()

        return HStack(spacing: 8) {
            Text(dateText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if isToday || isTomorrow {
                Text("· \(fullDateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)

            Text("All Caught Up!")
                .font(.title2.weight(.bold))

            Text("You don't have any upcoming tasks.\nTap + to add a new task.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Helper Methods
    private func scrollToDate(_ date: Date) {
        // This will scroll to the selected date's section
        // For now, we'll just update the selected date
        // You can enhance this with ScrollViewReader if needed
        selectedDate = date
    }

    private func tasksForDate(_ date: Date) -> [TaskEntity] {
        viewModel.tasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: date)
            }
            if let scheduledTime = task.scheduledTime {
                return Calendar.current.isDate(scheduledTime, inSameDayAs: date)
            }
            return false
        }
    }
}

// MARK: - Compact Task Card
struct CompactTaskCard: View {
    let task: TaskEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(task.title)
                .font(.caption.weight(.medium))
                .lineLimit(2)

            if let list = task.taskList {
                Label(list.name, systemImage: list.iconName ?? "list.bullet")
                    .font(.caption2)
                    .foregroundStyle(list.color)
            }
        }
        .padding(8)
        .frame(width: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Compact Week Task Row
struct CompactWeekTaskRow: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel

    var body: some View {
        HStack(spacing: 0) {
            // Priority Accent Bar
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 3)
                    .opacity(task.isCompleted ? 0.4 : 1.0)
            }

            HStack(spacing: 12) {
                // Completion indicator
                Circle()
                    .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)

                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    // Title with timer indicator
                    HStack(alignment: .center, spacing: 6) {
                        Text(task.title)
                            .font(.subheadline)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .lineLimit(1)

                        Spacer(minLength: 4)

                        // Small timer icon indicator (only when timer is active for this task)
                        if isTimerActive {
                            Image(systemName: "timer")
                                .font(.system(size: 10))
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    // Metadata Pills
                    HStack(spacing: 6) {
                        // Scheduled Time - Prominent
                        if let formattedTime = task.formattedScheduledTime {
                            HStack(spacing: 3) {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 9))
                                Text(formattedTime)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(Capsule().stroke(Color.blue.opacity(0.3), lineWidth: 0.8))
                            )
                        }

                        // Priority
                        if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                            HStack(spacing: 2) {
                                Image(systemName: "flag.fill")
                                    .font(.system(size: 8))
                                Text(priority.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundStyle(priority.color)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(priority.color.opacity(0.15))
                                    .overlay(Capsule().stroke(priority.color.opacity(0.4), lineWidth: 1))
                            )
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, task.priority > 0 ? 8 : 0)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

// MARK: - Upcoming Task Row
struct UpcomingTaskRow: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Completion Button
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Task Content
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(2)

                // Scheduled Time
                if let formattedTime = task.formattedScheduledTime {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                        Text(formattedTime)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.12))
                    )
                    .opacity(task.isCompleted ? 0.5 : 1.0)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var isTimerActive: Bool {
        guard let currentTask = timerViewModel.currentTask else { return false }
        return currentTask.id == task.id &&
               (timerViewModel.timerState == .running || timerViewModel.timerState == .paused)
    }
}

// MARK: - Schedule Task Sheet
struct ScheduleTaskSheet: View {
    @StateObject var viewModel: TaskListViewModel
    let selectedTime: Date
    let selectedEndTime: Date?
    let selectedTimeRange: String?
    let unscheduledTasks: [TaskEntity]
    let onDismiss: () -> Void

    @State private var showingCreateNew = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected time header
                VStack(spacing: 8) {
                    Text("Schedule for")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let timeRange = selectedTimeRange {
                        // Show time range if selected
                        Text(timeRange)
                            .font(.title2.weight(.bold))
                    } else {
                        // Show single time
                        Text(selectedTime, style: .time)
                            .font(.title.weight(.bold))
                    }

                    Text(selectedTime, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))

                // Create new task button
                Button {
                    showingCreateNew = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text("Create new task")
                            .font(.body.weight(.medium))

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)

                Divider()

                // Unscheduled tasks list
                if unscheduledTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)

                        Text("No unscheduled tasks")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or schedule existing task")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(unscheduledTasks) { task in
                                    Button {
                                        Task {
                                            await scheduleTask(task)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "circle")
                                                .font(.title3)
                                                .foregroundStyle(.gray)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(task.title)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)

                                                if let list = task.taskList {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: list.iconName ?? "list.bullet")
                                                            .font(.caption2)
                                                        Text(list.name)
                                                            .font(.caption2.weight(.medium))
                                                    }
                                                    .foregroundStyle(list.color)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(list.color.opacity(0.15))
                                                    )
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()
            }
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
                AddTaskView(viewModel: viewModel, preselectedScheduledTime: selectedTime, preselectedScheduledEndTime: selectedEndTime)
            }
        }
    }

    private func scheduleTask(_ task: TaskEntity) async {
        task.scheduledTime = selectedTime
        task.scheduledEndTime = selectedEndTime
        await viewModel.updateTask(task)
        HapticManager.shared.success()
        onDismiss()
    }
}

// MARK: - Preview
#Preview {
    UpcomingView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
