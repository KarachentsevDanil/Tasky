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
    @State private var selectedEndTimeSlot: Date?
    @State private var showingScheduleTask = false

    // Time range selection
    @State private var selectedStartHour: Int?
    @State private var selectedEndHour: Int?
    @State private var isDraggingSelection = false

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case upcoming = "Upcoming"
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
                        selectedEndTime: selectedEndTimeSlot,
                        selectedTimeRange: selectedTimeRange,
                        unscheduledTasks: unscheduledTasks,
                        onDismiss: {
                            showingScheduleTask = false
                            selectedTimeSlot = nil
                            selectedEndTimeSlot = nil
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
                .overlay(alignment: .topLeading) {
                    // Tasks overlay - renders all scheduled tasks with absolute positioning
                    tasksOverlay()

                    // Time range selection overlay
                    if let startHour = selectedStartHour, let endHour = selectedEndHour {
                        timeRangeSelectionOverlay(startHour: startHour, endHour: endHour)
                    }

                    // Current time indicator (only show for today)
                    if Calendar.current.isDateInToday(selectedDate) {
                        currentTimeIndicator
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

    // MARK: - Current Time Indicator
    private var currentTimeIndicator: some View {
        // Use TimelineView for real-time updates (updates every minute)
        TimelineView(.everyMinute) { context in
            let yPosition = calculateTimeIndicatorPosition(for: context.date)

            HStack(spacing: 0) {
                // Match the time slot layout spacing
                Color.clear.frame(width: TimelineConstants.timeLabelWidth)
                Color.clear.frame(width: TimelineConstants.spacing)
                Color.clear.frame(width: TimelineConstants.dividerWidth)
                Color.clear.frame(width: TimelineConstants.spacing)

                // Red dot
                Circle()
                    .fill(Color.red)
                    .frame(width: TimelineConstants.indicatorDotSize, height: TimelineConstants.indicatorDotSize)

                // Red line
                Rectangle()
                    .fill(Color.red)
                    .frame(height: TimelineConstants.indicatorLineHeight)
            }
            .padding(.horizontal, TimelineConstants.horizontalPadding)
            .offset(y: yPosition)
            .zIndex(3) // Always on top
            .allowsHitTesting(false)
        }
    }

    // MARK: - Time Range Selection Overlay
    private func timeRangeSelectionOverlay(startHour: Int, endHour: Int) -> some View {
        let minHour = min(startHour, endHour)
        let maxHour = max(startHour, endHour)

        // Calculate position and height
        let yPosition = CGFloat(minHour - 6) * TimelineConstants.hourHeight
        let numberOfHours = CGFloat(maxHour - minHour + 1)
        let height = numberOfHours * TimelineConstants.hourHeight

        return HStack(spacing: 0) {
            // Match the time slot layout spacing
            Color.clear.frame(width: TimelineConstants.timeLabelWidth)
            Color.clear.frame(width: TimelineConstants.spacing)
            Color.clear.frame(width: TimelineConstants.dividerWidth)
            Color.clear.frame(width: TimelineConstants.spacing)

            // Selection block - single continuous element
            VStack(spacing: 0) {
                // Top drag handle
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .padding(.top, -6)
                    Spacer()
                }

                // Main selection block
                ZStack(alignment: .topLeading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.15))

                    // Border
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 2)

                    // Time range text
                    if let timeRange = selectedTimeRange {
                        Text(timeRange)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.blue)
                            .padding(.leading, 12)
                            .padding(.top, 8)
                    }
                }
                .frame(height: height)

                // Bottom drag handle
                HStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 12, height: 12)
                        .padding(.bottom, -6)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, TimelineConstants.horizontalPadding)
        .offset(y: yPosition)
        .zIndex(1) // Selection behind tasks
        .allowsHitTesting(true)
        .onTapGesture {
            if !isDraggingSelection {
                openScheduleSheet()
            }
        }
    }

    // MARK: - Tasks Overlay
    private func tasksOverlay() -> some View {
        // Allow hit testing to pass through except on tasks themselves
        ZStack(alignment: .topLeading) {
            ForEach(scheduledTasks) { task in
                taskOverlayBlock(for: task)
            }
        }
        .allowsHitTesting(false) // This makes gestures work on hour slots below
    }

    @ViewBuilder
    private func taskOverlayBlock(for task: TaskEntity) -> some View {
        if let scheduledTime = task.scheduledTime {
            let calendar = Calendar.current
            let startHour = calendar.component(.hour, from: scheduledTime)
            let startMinute = calendar.component(.minute, from: scheduledTime)

            // Calculate Y position from timeline start (6am)
            let hoursFromStart = CGFloat(startHour - 6) + (CGFloat(startMinute) / 60.0)
            let yPosition = hoursFromStart * TimelineConstants.hourHeight

            // Calculate height based on duration
            let endTime = task.scheduledEndTime ?? calendar.date(byAdding: .hour, value: 1, to: scheduledTime)!
            let durationInSeconds = endTime.timeIntervalSince(scheduledTime)
            let durationInHours = durationInSeconds / 3600.0
            let height = max(52, TimelineConstants.hourHeight * CGFloat(durationInHours) - 8)

            ZStack(alignment: .topLeading) {
                // Invisible spacer to maintain layout structure
                HStack(spacing: 0) {
                    Color.clear.frame(width: TimelineConstants.timeLabelWidth)
                    Color.clear.frame(width: TimelineConstants.spacing)
                    Color.clear.frame(width: TimelineConstants.dividerWidth)
                    Color.clear.frame(width: TimelineConstants.spacing)
                    Color.clear.frame(maxWidth: .infinity)
                }
                .allowsHitTesting(false)

                // Task block positioned absolutely
                NavigationLink {
                    TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                } label: {
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

                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .frame(minHeight: height, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                .allowsHitTesting(true) // Enable tapping on tasks
                .padding(.leading, TimelineConstants.timeLabelWidth + TimelineConstants.spacing + TimelineConstants.dividerWidth + TimelineConstants.spacing)
                .padding(.trailing, TimelineConstants.horizontalPadding)
            }
            .padding(.horizontal, TimelineConstants.horizontalPadding)
            .offset(y: yPosition)
            .zIndex(2) // Tasks on top of selection
        }
    }

    // MARK: - Helper Methods
    private func calculateTimeIndicatorPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)

        let hoursFromStart = CGFloat(currentHour) - TimelineConstants.startHour + (CGFloat(currentMinute) / 60.0)
        return hoursFromStart * TimelineConstants.hourHeight
    }

    // MARK: - Constants
    private enum TimelineConstants {
        static let startHour: CGFloat = 6
        static let hourHeight: CGFloat = 60
        static let timeLabelWidth: CGFloat = 60
        static let spacing: CGFloat = 12
        static let dividerWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 16
        static let indicatorDotSize: CGFloat = 10
        static let indicatorLineHeight: CGFloat = 2
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
        // Check if any tasks start in this hour (for drag gesture blocking)
        let tasksInHour = scheduledTasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            let taskHour = Calendar.current.component(.hour, from: scheduledTime)
            return taskHour == hour
        }

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

            // Empty space for gestures
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(hour: hour, location: value.location, tasksInHour: tasksInHour)
                        }
                        .onEnded { _ in
                            handleDragEnded()
                        }
                )
        }
        .padding(.horizontal)
    }

    // MARK: - Task Block
    private func taskBlock(for task: TaskEntity) -> some View {
        let blockHeight = calculateTaskBlockHeight(for: task)

        return VStack(alignment: .leading, spacing: 4) {
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

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: blockHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 2)
        )
    }

    /// Calculate the height for a task block based on its duration
    private func calculateTaskBlockHeight(for task: TaskEntity) -> CGFloat {
        guard let startTime = task.scheduledTime else { return 56 }

        let endTime = task.scheduledEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startTime)!
        let durationInSeconds = endTime.timeIntervalSince(startTime)
        let durationInHours = durationInSeconds / 3600.0

        // Each hour slot is 60 points, so scale accordingly
        let hourHeight: CGFloat = 60
        let calculatedHeight = hourHeight * CGFloat(durationInHours)

        // Subtract small margin for visual clarity (4pt at top + 4pt at bottom = 8pt total per hour span)
        let margin: CGFloat = 8
        return max(52, calculatedHeight - margin)
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
    private func handleDragChanged(hour: Int, location: CGPoint, tasksInHour: [TaskEntity]) {
        // Don't allow creating selection in hours with tasks
        guard tasksInHour.isEmpty else { return }

        if selectedStartHour == nil {
            // First touch - set start hour
            selectedStartHour = hour
            selectedEndHour = hour
            isDraggingSelection = true
            HapticManager.shared.selectionChanged()
        } else {
            // Calculate which hour we're dragging over based on location
            // Each hour slot is 60pt tall
            let hourOffset = Int(location.y / 60)
            let targetHour = hour + hourOffset

            // Clamp to valid hour range (6 AM to 11 PM)
            let clampedHour = max(6, min(23, targetHour))

            // Update end hour based on drag position
            if selectedEndHour != clampedHour {
                selectedEndHour = clampedHour
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
            let maxHour = max(startHour, endHour)
            selectedTimeSlot = calendar.date(bySettingHour: minHour, minute: 0, second: 0, of: selectedDate)
            selectedEndTimeSlot = calendar.date(bySettingHour: maxHour + 1, minute: 0, second: 0, of: selectedDate)
            showingScheduleTask = true
            HapticManager.shared.lightImpact()
        }
    }

    private func clearSelection() {
        selectedStartHour = nil
        selectedEndHour = nil
        selectedEndTimeSlot = nil
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


    // MARK: - Date Section
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
        HStack(spacing: 0) {
            // Priority Accent Bar (left edge)
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                Rectangle()
                    .fill(priority.color)
                    .frame(width: 4)
                    .opacity(task.isCompleted ? 0.4 : 1.0)
            }

            HStack(spacing: 10) {
                // Completion Button
                Button(action: onToggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(task.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)

                // Task Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title Row with timer indicator
                    HStack(alignment: .center, spacing: 8) {
                        Text(task.title)
                            .font(.body)
                            .strikethrough(task.isCompleted)
                            .foregroundStyle(task.isCompleted ? .secondary : .primary)
                            .lineLimit(2)

                        Spacer(minLength: 4)

                        // Small timer icon indicator (only when timer is active for this task)
                        if isTimerActive {
                            Image(systemName: "timer")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .symbolEffect(.pulse, options: .repeating)
                        }
                    }

                    // Metadata Pills - Prioritize time information
                    HStack(spacing: 6) {
                        // Scheduled Time/Due Date - MOST PROMINENT
                        if let formattedTime = task.formattedScheduledTime {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                    .font(.caption)
                                Text(formattedTime)
                                    .font(.caption.weight(.semibold))
                            }
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.blue.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                        }

                        // Priority Pill - With icon for better visibility
                        if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                            HStack(spacing: 3) {
                                Image(systemName: "flag.fill")
                                    .font(.caption2)
                                Text(priority.displayName)
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(priority.color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(priority.color.opacity(0.15))
                                    .overlay(
                                        Capsule()
                                            .stroke(priority.color.opacity(0.4), lineWidth: 1.5)
                                    )
                            )
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                        }

                        // Recurrence Pill
                        if task.isRecurring, let recurrenceDesc = task.recurrenceDescription {
                            HStack(spacing: 3) {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                Text(recurrenceDesc)
                                    .font(.caption2)
                            }
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Color.purple.opacity(0.15)))
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                        }

                        // List Pill
                        if let list = task.taskList {
                            HStack(spacing: 3) {
                                Image(systemName: list.iconName ?? "list.bullet")
                                    .font(.caption2)
                                Text(list.name)
                                    .font(.caption2)
                            }
                            .foregroundStyle(list.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(list.color.opacity(0.15)))
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, task.priority > 0 ? 10 : 0)
            .padding(.trailing, 10)
            .padding(.vertical, 12)
        }
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
