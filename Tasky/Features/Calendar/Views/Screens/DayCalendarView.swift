//
//  DayCalendarView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Clean, production-ready day calendar view following MVVM and iOS best practices
struct DayCalendarView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: DayCalendarViewModel
    @ObservedObject var taskListViewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel

    // MARK: - State
    @State private var containerWidth: CGFloat = 0
    @State private var showingAddTask = false

    // MARK: - Constants
    private enum Layout {
        static let timeLabelWidth: CGFloat = 40
        static let spacing: CGFloat = 8
        static let dividerWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 12
    }

    // MARK: - Computed Properties

    /// Current hour for scrolling (clamped to valid range)
    private var currentHourForScroll: Int {
        let hour = Calendar.current.component(.hour, from: Date())
        // Clamp to valid hour range and scroll to 1 hour before for context
        let targetHour = max(viewModel.startHour, hour - 1)
        return min(viewModel.endHour - 1, targetHour)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Date picker header
            datePickerHeader

            Divider()

            // Main calendar content
            GeometryReader { geometry in
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        ZStack(alignment: .topLeading) {
                            // Time grid background with global drag gesture
                            TimeGridView(
                                startHour: viewModel.startHour,
                                endHour: viewModel.endHour,
                                hourHeight: viewModel.hourHeight,
                                onSlotTap: { globalY in
                                    viewModel.handleTimeSlotTap(at: globalY)
                                },
                                onDragChanged: { globalY in
                                    viewModel.updateDraggedEvent(to: globalY)
                                },
                                onDragStarted: { globalY in
                                    viewModel.startDraggingNewEvent(at: globalY)
                                },
                                onDragEnded: {
                                    viewModel.finishDraggingNewEvent()
                                }
                            )

                            // External calendar events (background layer)
                            externalEventsOverlay(containerWidth: geometry.size.width)

                            // Task events overlay (foreground layer)
                            eventsOverlay(containerWidth: geometry.size.width)

                            // Current time indicator (only for today)
                            if Calendar.current.isDateInToday(viewModel.selectedDate) {
                                CurrentTimeIndicator(
                                    startHour: viewModel.startHour,
                                    hourHeight: viewModel.hourHeight,
                                    containerWidth: geometry.size.width
                                )
                            }

                            // Drag preview overlay
                            if viewModel.isDraggingNewEvent {
                                dragPreviewOverlay(containerWidth: geometry.size.width)
                            }
                        }
                        .frame(
                            height: CGFloat(viewModel.endHour - viewModel.startHour) * viewModel.hourHeight
                        )
                    }
                    .onAppear {
                        containerWidth = geometry.size.width
                        // Scroll to current time immediately on appear (only for today)
                        if Calendar.current.isDateInToday(viewModel.selectedDate) {
                            scrollProxy.scrollTo("hour_\(currentHourForScroll)", anchor: .top)
                        }
                    }
                    .onChange(of: viewModel.selectedDate) { _, newDate in
                        // Scroll to current time when switching to today
                        if Calendar.current.isDateInToday(newDate) {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    scrollProxy.scrollTo("hour_\(currentHourForScroll)", anchor: .top)
                                }
                            }
                        }
                    }
                }
            }

            Divider()

            // Unscheduled events bar
            if !viewModel.unscheduledTasks.isEmpty {
                UnscheduledEventsBar(
                    tasks: viewModel.unscheduledTasks,
                    onTaskTap: handleUnscheduledTaskTap
                )
            }
        }
        .sheet(isPresented: $viewModel.showingScheduleSheet) {
            if let startTime = viewModel.scheduleSheetStartTime {
                ScheduleTaskSheet(
                    viewModel: taskListViewModel,
                    selectedTime: startTime,
                    selectedEndTime: viewModel.scheduleSheetEndTime,
                    selectedTimeRange: formatTimeRange(
                        start: startTime,
                        end: viewModel.scheduleSheetEndTime ?? startTime.addingMinutes(60)
                    ),
                    unscheduledTasks: viewModel.unscheduledTasks,
                    onDismiss: {
                        viewModel.showingScheduleSheet = false
                        viewModel.scheduleSheetStartTime = nil
                        viewModel.scheduleSheetEndTime = nil
                    }
                )
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("OK") {
                viewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .onChange(of: taskListViewModel.tasks) { _, newTasks in
            viewModel.allTasks = newTasks
        }
        .onChange(of: viewModel.selectedDate) { _, _ in
            Task {
                await viewModel.loadExternalEvents()
            }
        }
        .task {
            viewModel.allTasks = taskListViewModel.tasks
            await viewModel.loadExternalEvents()
        }
    }

    // MARK: - Date Picker Header
    private var datePickerHeader: some View {
        HStack {
            Button(action: viewModel.goToPreviousDay) {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }
            .accessibilityLabel("Previous day")

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.selectedDate, style: .date)
                    .font(.headline)

                if Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
            .accessibilityElement(children: .combine)

            Spacer()

            Button(action: viewModel.goToNextDay) {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
            .accessibilityLabel("Next day")
        }
        .padding()
    }

    // MARK: - External Events Overlay
    @ViewBuilder
    private func externalEventsOverlay(containerWidth: CGFloat) -> some View {
        let availableWidth = containerWidth - Layout.timeLabelWidth - Layout.spacing - Layout.dividerWidth - Layout.spacing - (Layout.horizontalPadding * 2)
        let layouts = viewModel.layoutExternalEvents(in: availableWidth)

        ZStack(alignment: .topLeading) {
            ForEach(layouts) { layout in
                ExternalEventView(event: layout.event, layout: layout)
                    .offset(
                        x: Layout.timeLabelWidth + Layout.spacing + Layout.dividerWidth + Layout.spacing + Layout.horizontalPadding,
                        y: layout.frame.minY
                    )
            }
        }
        .zIndex(1) // Below task events
    }

    // MARK: - Events Overlay
    @ViewBuilder
    private func eventsOverlay(containerWidth: CGFloat) -> some View {
        let availableWidth = containerWidth - Layout.timeLabelWidth - Layout.spacing - Layout.dividerWidth - Layout.spacing - (Layout.horizontalPadding * 2)
        let layouts = viewModel.layoutEvents(in: availableWidth)

        ZStack(alignment: .topLeading) {
            ForEach(layouts, id: \.task.id) { layout in
                CalendarEventView(
                    task: layout.task,
                    layout: layout,
                    isSelected: viewModel.selectedTask?.id == layout.task.id,
                    onTap: {
                        viewModel.selectEvent(layout.task)
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteTask(layout.task)
                        }
                    },
                    onResizeStart: { edge, location in
                        viewModel.startResizingEvent(layout.task, edge: edge)
                    },
                    onResizeChanged: { edge, location in
                        let globalY = location.y + layout.frame.minY
                        viewModel.updateEventResize(layout.task, edge: edge, yPosition: globalY)
                    },
                    onResizeEnded: {
                        viewModel.finishResizingEvent()
                    }
                )
                .offset(
                    x: Layout.timeLabelWidth + Layout.spacing + Layout.dividerWidth + Layout.spacing + Layout.horizontalPadding + layout.frame.minX,
                    y: layout.frame.minY
                )
                .onTapGesture {
                    // Navigate to detail view
                    // This will be handled by parent
                }
            }
        }
        .zIndex(2) // Events on top of grid
    }

    // MARK: - Drag Preview Overlay
    @ViewBuilder
    private func dragPreviewOverlay(containerWidth: CGFloat) -> some View {
        if let startTime = viewModel.dragStartTime,
           let endTime = viewModel.dragEndTime {

            let yPosition = viewModel.yPositionFromTime(startTime)
            let durationMinutes = Int(endTime.timeIntervalSince(startTime) / 60)
            let height = CGFloat(durationMinutes) * (viewModel.hourHeight / 60)

            let availableWidth = containerWidth - Layout.timeLabelWidth - Layout.spacing - Layout.dividerWidth - Layout.spacing - (Layout.horizontalPadding * 2)

            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.15))

                // Border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text("New Event")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.blue)

                    Text(formatTimeRange(start: startTime, end: endTime))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    // Duration badge at bottom
                    if height > 60 {
                        Text(formatDuration(minutes: durationMinutes))
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.blue)
                    }
                }
                .padding(8)

                // Top resize handle indicator
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 40, height: 4)
                        .padding(.top, 4)

                    Spacer()

                    // Bottom resize handle indicator
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: 40, height: 4)
                        .padding(.bottom, 4)
                }
                .frame(maxWidth: .infinity)
            }
            .frame(width: availableWidth - 10, height: max(40, height))
            .offset(
                x: Layout.timeLabelWidth + Layout.spacing + Layout.dividerWidth + Layout.spacing + Layout.horizontalPadding,
                y: yPosition
            )
            .zIndex(1)
            .allowsHitTesting(false)
            .animation(.spring(response: 0.2, dampingFraction: 0.8), value: height)
        }
    }

    // MARK: - Duration Formatting
    private func formatDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)h \(mins)m"
        }
    }

    // MARK: - Gesture Handlers
    private func handleUnscheduledTaskTap(_ task: TaskEntity) {
        // Open schedule sheet for this specific task
        let now = Date()
        viewModel.scheduleSheetStartTime = now.rounded(toNearest: 15)
        viewModel.scheduleSheetEndTime = viewModel.scheduleSheetStartTime?.addingMinutes(60)
        viewModel.showingScheduleSheet = true
    }

    // MARK: - Helper Methods
    private func formatTimeRange(start: Date, end: Date) -> String {
        AppDateFormatters.formatTimeRange(start: start, end: end)
    }
}

// MARK: - Preview
#Preview {
    let controller = PersistenceController.preview
    let dataService = DataService(persistenceController: controller)
    let dayViewModel = DayCalendarViewModel(dataService: dataService)
    let taskListViewModel = TaskListViewModel(dataService: dataService)
    let timerViewModel = FocusTimerViewModel()

    return NavigationStack {
        DayCalendarView(
            viewModel: dayViewModel,
            taskListViewModel: taskListViewModel,
            timerViewModel: timerViewModel
        )
        .navigationTitle("Day View")
        .navigationBarTitleDisplayMode(.inline)
    }
}
