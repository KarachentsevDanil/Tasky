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
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var showingCalendarPicker = false
    @State private var showMiniCalendar = true
    @State private var selectedView: ViewMode = .day
    @State private var selectedTimeSlot: Date?
    @State private var showingScheduleTask = false

    // Time range selection
    @State private var selectedStartHour: Int?
    @State private var selectedEndHour: Int?
    @State private var isDraggingSelection = false

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case upcoming = "Upcoming"
        case week = "Week"
        case month = "Month"
    }

    // MARK: - Computed Properties
    private var groupedTasks: [(date: Date, tasks: [TaskEntity])] {
        let calendar = Calendar.current

        // Get all upcoming tasks (today and future)
        let upcomingTasks = viewModel.tasks.filter { task in
            if let dueDate = task.dueDate {
                return calendar.isDateInToday(dueDate) || dueDate > Date()
            }
            if let scheduledTime = task.scheduledTime {
                return calendar.isDateInToday(scheduledTime) || scheduledTime > Date()
            }
            return task.dueDate == nil && task.scheduledTime == nil && !task.isCompleted
        }

        // Group tasks by date
        let grouped = Dictionary(grouping: upcomingTasks) { task -> Date in
            if let dueDate = task.dueDate {
                return calendar.startOfDay(for: dueDate)
            }
            if let scheduledTime = task.scheduledTime {
                return calendar.startOfDay(for: scheduledTime)
            }
            return calendar.startOfDay(for: Date())
        }

        // Sort by date and return as array of tuples
        return grouped.map { (date: $0.key, tasks: $0.value) }
            .sorted { $0.date < $1.date }
    }

    // Week view properties
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

    // Month view properties
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

    private var selectedDayTasks: [TaskEntity] {
        tasksForDate(selectedDate)
    }

    // Day view properties
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
                    case .week:
                        weekView
                    case .month:
                        monthView
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
            .sheet(isPresented: $showingScheduleTask) {
                if let timeSlot = selectedTimeSlot {
                    ScheduleTaskSheet(
                        viewModel: viewModel,
                        selectedTime: timeSlot,
                        selectedTimeRange: selectedTimeRange,
                        unscheduledTasks: unscheduledTasks,
                        onDismiss: {
                            showingScheduleTask = false
                            selectedTimeSlot = nil
                            clearSelection()
                        }
                    )
                }
            }
            .task {
                viewModel.currentFilter = .all
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
                    // Time slots (6 AM - 11 PM)
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

    // MARK: - Upcoming View
    private var upcomingView: some View {
        VStack(spacing: 0) {
            // Mini Calendar
            miniCalendar

            Divider()

            // Upcoming Tasks List
            ScrollView {
                LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                    ForEach(groupedTasks, id: \.date) { group in
                        Section {
                            VStack(spacing: 8) {
                                ForEach(group.tasks) { task in
                                    NavigationLink {
                                        TaskDetailView(viewModel: viewModel, task: task)
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
        let hasIncompleteTasks = !tasksForDate.filter { !$0.isCompleted }.isEmpty

        return Button {
            withAnimation {
                selectedDate = date
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 4) {
                Text(date, format: .dateTime.day())
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                    )

                // Task indicator dot
                if hasIncompleteTasks {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36)
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

    // MARK: - Date Picker
    private var datePicker: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
                HapticManager.shared.lightImpact()
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
                HapticManager.shared.lightImpact()
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

        let minHour = selectedStartHour != nil && selectedEndHour != nil ? min(selectedStartHour!, selectedEndHour!) : nil
        let maxHour = selectedStartHour != nil && selectedEndHour != nil ? max(selectedStartHour!, selectedEndHour!) : nil
        let isSelectionStart = hour == minHour
        let isSelectionEnd = hour == maxHour
        let isInSelection = minHour != nil && maxHour != nil && hour >= minHour! && hour <= maxHour!

        return HStack(alignment: .top, spacing: 12) {
            // Time Label
            Text(formatHour(hour))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            // Divider line
            Rectangle()
                .fill(Color(.separator))
                .frame(width: 1)

            // Tasks or selection or empty space
            ZStack(alignment: .topLeading) {
                // Background - always present for gesture
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .contentShape(Rectangle())

                // Selection rendering (if this hour is in selection)
                if isInSelection && tasksInHour.isEmpty {
                    VStack(spacing: 0) {
                        // Top drag handle (only on first hour)
                        if isSelectionStart {
                            HStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                    .padding(.top, -6)
                                Spacer()
                            }
                        }

                        // Selection content
                        ZStack {
                            RoundedRectangle(cornerRadius: isSelectionStart && isSelectionEnd ? 8 : 0)
                                .fill(Color.blue.opacity(0.15))
                                .overlay(
                                    RoundedRectangle(cornerRadius: isSelectionStart && isSelectionEnd ? 8 : 0)
                                        .stroke(Color.blue, lineWidth: 2)
                                )

                            // Show time range only in the first hour and when not dragging
                            if isSelectionStart && !isDraggingSelection {
                                VStack(spacing: 4) {
                                    Text(selectedTimeRange ?? "")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.blue)
                                }
                                .padding(8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: isSelectionStart ? 54 : 60)

                        // Bottom drag handle (only on last hour)
                        if isSelectionEnd {
                            HStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 12, height: 12)
                                    .padding(.bottom, -6)
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .onTapGesture {
                        // Tap on selection to open schedule sheet
                        if !isDraggingSelection {
                            openScheduleSheet()
                        }
                    }
                }

                // Show tasks (if any)
                if !tasksInHour.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(tasksInHour) { task in
                            NavigationLink {
                                TaskDetailView(viewModel: viewModel, task: task)
                            } label: {
                                taskBlock(for: task)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if tasksInHour.isEmpty {
                            handleDragChanged(hour: hour, location: value.location)
                        }
                    }
                    .onEnded { _ in
                        if tasksInHour.isEmpty {
                            handleDragEnded()
                        }
                    }
            )
        }
        .frame(height: 60)
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

    // Helper method for formatting hour
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }

    // MARK: - Drag Selection Handlers
    private func handleDragChanged(hour: Int, location: CGPoint) {
        if selectedStartHour == nil {
            // First touch - set start hour
            selectedStartHour = hour
            selectedEndHour = hour
            isDraggingSelection = true
            HapticManager.shared.selectionChanged()
        } else {
            // Update end hour based on drag position
            if selectedEndHour != hour {
                selectedEndHour = hour
                HapticManager.shared.selectionChanged()
            }
        }
    }

    private func handleDragEnded() {
        isDraggingSelection = false
        HapticManager.shared.lightImpact()

        // Don't automatically open sheet - wait for user to tap on selection
        // The selection will remain visible and tappable
    }

    private func openScheduleSheet() {
        if let startHour = selectedStartHour, let endHour = selectedEndHour {
            let calendar = Calendar.current
            let minHour = min(startHour, endHour)
            selectedTimeSlot = calendar.date(bySettingHour: minHour, minute: 0, second: 0, of: selectedDate)
            showingScheduleTask = true
            HapticManager.shared.lightImpact()
        }
    }

    private func clearSelection() {
        selectedStartHour = nil
        selectedEndHour = nil
        isDraggingSelection = false
    }

    private var selectedTimeRange: String? {
        guard let startHour = selectedStartHour, let endHour = selectedEndHour else {
            return nil
        }

        let minHour = min(startHour, endHour)
        let maxHour = max(startHour, endHour)

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let calendar = Calendar.current
        let startTime = calendar.date(bySettingHour: minHour, minute: 0, second: 0, of: selectedDate) ?? Date()
        let endTime = calendar.date(bySettingHour: maxHour + 1, minute: 0, second: 0, of: selectedDate) ?? Date()

        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
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
                HapticManager.shared.lightImpact()
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
                HapticManager.shared.lightImpact()
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
                HapticManager.shared.lightImpact()
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
                HapticManager.shared.lightImpact()
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
                    UpcomingTaskRow(task: task, timerViewModel: timerViewModel) {
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

    // MARK: - Date Section
    private func dateSection(for date: Date, tasks: [TaskEntity]) -> some View {
        Section {
            VStack(spacing: 8) {
                ForEach(tasks) { task in
                    NavigationLink {
                        TaskDetailView(viewModel: viewModel, task: task)
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
        HStack(spacing: 12) {
            // Completion indicator
            Circle()
                .fill(task.isCompleted ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)

            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.subheadline)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    // Focus Timer Badge
                    if !task.isCompleted {
                        FocusTimerView(viewModel: timerViewModel, task: task)
                    }

                    if let formattedTime = task.formattedScheduledTime {
                        Label(formattedTime, systemImage: "clock")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                        Label(priority.displayName, systemImage: "flag.fill")
                            .font(.caption2)
                            .foregroundStyle(priority.color)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemBackground))
        )
    }
}

// MARK: - Upcoming Task Row
struct UpcomingTaskRow: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Completion Button
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Task Content
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.body)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                // Metadata Pills
                HStack(spacing: 8) {
                    // Focus Timer Pill
                    if !task.isCompleted {
                        FocusTimerView(viewModel: timerViewModel, task: task)
                    }

                    // Recurrence Pill
                    if task.isRecurring, let recurrenceDesc = task.recurrenceDescription {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                            Text(recurrenceDesc)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.15))
                        )
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // Priority Pill
                    if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                        Text(priority.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(priority.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(priority.color.opacity(0.15))
                            )
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // List Pill
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
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // Scheduled Time Pill
                    if let formattedTime = task.formattedScheduledTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formattedTime)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Schedule Task Sheet
struct ScheduleTaskSheet: View {
    @StateObject var viewModel: TaskListViewModel
    let selectedTime: Date
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
                AddTaskView(viewModel: viewModel, preselectedScheduledTime: selectedTime)
            }
        }
    }

    private func scheduleTask(_ task: TaskEntity) async {
        task.scheduledTime = selectedTime
        await viewModel.updateTask(task)
        HapticManager.shared.success()
        onDismiss()
    }
}

// MARK: - Preview
#Preview {
    UpcomingView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
