//
//  CalendarTabView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Calendar tab with day/week/month views
struct CalendarTabView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var selectedView: CalendarViewType = .day

    // MARK: - View Type
    enum CalendarViewType: String, CaseIterable {
        case day = "Day"
        case week = "Week"
        case month = "Month"
    }

    // MARK: - Computed Properties
    private var scheduledTasks: [TaskEntity] {
        viewModel.tasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            return Calendar.current.isDate(scheduledTime, inSameDayAs: selectedDate)
        }
    }

    private var unscheduledTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.scheduledTime == nil && !$0.isCompleted }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Picker
                Picker("View", selection: $selectedView) {
                    ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                        Text(viewType.rawValue).tag(viewType)
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
                    case .week:
                        weekView
                    case .month:
                        monthView
                    }
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Day View
    private var dayView: some View {
        VStack(spacing: 0) {
            // Date Picker
            datePicker

            Divider()

            // Timeline View
            ScrollView {
                VStack(spacing: 0) {
                    // Time slots (6 AM - 12 AM)
                    ForEach(6..<24) { hour in
                        timeSlot(for: hour)
                    }
                }
            }

            Divider()

            // Unscheduled Tasks Bottom Sheet
            if !unscheduledTasks.isEmpty {
                unscheduledTasksSheet
            }
        }
    }

    // MARK: - Week View
    private var weekView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Week Navigation
                weekNavigationHeader

                // Week Days Grid
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(weekDates, id: \.self) { date in
                        weekDayCard(for: date)
                    }
                }
                .padding()
            }
        }
    }

    private var weekNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekRangeText)
                    .font(.headline)

                if isCurrentWeek {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    private func weekDayCard(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)

        // Calculate task status
        let completedCount = tasksForDate.filter { $0.isCompleted }.count
        let totalCount = tasksForDate.count
        let allCompleted = completedCount == totalCount && totalCount > 0

        return VStack(alignment: .leading, spacing: 12) {
            // Date Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.headline)
                        .foregroundStyle(isToday ? .blue : .primary)

                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !tasksForDate.isEmpty {
                    ZStack {
                        Circle()
                            .fill(allCompleted ? Color.green : Color.orange)
                            .frame(width: 28, height: 28)

                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(totalCount - completedCount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            Divider()

            // Tasks for this day
            if tasksForDate.isEmpty {
                Text("No tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasksForDate.prefix(3)) { task in
                    NavigationLink {
                        TaskDetailView(viewModel: viewModel, task: task)
                    } label: {
                        CompactWeekTaskRow(task: task, timerViewModel: timerViewModel)
                    }
                    .buttonStyle(.plain)
                }

                if tasksForDate.count > 3 {
                    Text("+\(tasksForDate.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isToday ? Color.accentColor.opacity(0.05) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Month View
    private var monthView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Month Navigation
                monthNavigationHeader

                // Calendar Grid
                VStack(spacing: 16) {
                    // Weekday Headers
                    weekdayHeaders

                    // Calendar Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(monthDates, id: \.self) { date in
                            if let date = date {
                                monthDayCell(for: date)
                            } else {
                                Color.clear
                                    .frame(height: 80)
                            }
                        }
                    }
                }
                .padding()

                // Selected Day Tasks
                if !selectedDayTasks.isEmpty {
                    selectedDayTasksSection
                }
            }
        }
    }

    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)

                if isCurrentMonth {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    private var weekdayHeaders: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthDayCell(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)

        // Calculate task status for this date
        let completedCount = tasksForDate.filter { $0.isCompleted }.count
        let totalCount = tasksForDate.count
        let hasIncompleteTasks = completedCount < totalCount && totalCount > 0
        let allCompleted = completedCount == totalCount && totalCount > 0

        return Button {
            withAnimation {
                selectedDate = date
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 6) {
                Text(date, format: .dateTime.day())
                    .font(.body.weight(isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                    )

                // Task status indicator
                if totalCount > 0 {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(allCompleted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 20, height: 20)

                        // Count or checkmark
                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(totalCount - completedCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .id(date)
    }

    private var selectedDayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.title2.weight(.bold))

                Spacer()

                Text("\(selectedDayTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ForEach(selectedDayTasks) { task in
                NavigationLink {
                    TaskDetailView(viewModel: viewModel, task: task)
                } label: {
                    EnhancedTaskRowView(task: task, timerViewModel: timerViewModel) {
                        Task {
                            await viewModel.toggleTaskCompletion(task)
                            HapticManager.shared.success()
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
        )
        .padding()
    }

    // MARK: - Date Picker
    private var datePicker: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate, style: .date)
                    .font(.headline)

                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Time Slot
    private func timeSlot(for hour: Int) -> some View {
        let tasksInHour = scheduledTasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            let taskHour = Calendar.current.component(.hour, from: scheduledTime)
            return taskHour == hour
        }

        return HStack(alignment: .top, spacing: 12) {
            // Time Label
            Text(formatHour(hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Divider()

            // Tasks in this hour
            VStack(alignment: .leading, spacing: 8) {
                if tasksInHour.isEmpty {
                    Color.clear
                        .frame(height: 60)
                } else {
                    ForEach(tasksInHour) { task in
                        taskBlock(for: task)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Task Block
    private func taskBlock(for task: TaskEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(task.isCompleted ? Color.green : Color.blue)
                    .frame(width: 8, height: 8)

                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted)
            }

            if let time = task.formattedScheduledTime {
                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 2)
        )
    }

    // MARK: - Unscheduled Tasks Sheet
    private var unscheduledTasksSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unscheduled")
                    .font(.headline)

                Spacer()

                Text("\(unscheduledTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unscheduledTasks.prefix(5)) { task in
                        CompactTaskCard(task: task)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Helper Methods
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
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

    // MARK: - Week Computed Properties
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        guard let firstDay = weekDates.first,
              let lastDay = weekDates.last else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let firstString = formatter.string(from: firstDay)
        let lastString = formatter.string(from: lastDay)

        // Add year if different
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let firstYear = yearFormatter.string(from: firstDay)
        let lastYear = yearFormatter.string(from: lastDay)

        if firstYear != lastYear {
            return "\(firstString), \(firstYear) - \(lastString), \(lastYear)"
        } else {
            return "\(firstString) - \(lastString)"
        }
    }

    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    // MARK: - Month Computed Properties
    private var monthDates: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else {
            return []
        }

        let numberOfWeeks = calendar.range(of: .weekOfYear, in: .month, for: selectedDate)?.count ?? 5
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

    private var selectedDayTasks: [TaskEntity] {
        tasksForDate(selectedDate)
    }
}

// MARK: - Preview
#Preview {
    CalendarTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
