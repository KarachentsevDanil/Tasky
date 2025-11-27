//
//  DayCalendarViewModel.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import Foundation
import SwiftUI
import Combine

/// ViewModel for day calendar view with event creation and editing logic
@MainActor
final class DayCalendarViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var selectedDate: Date
    @Published var selectedTask: TaskEntity?
    @Published var isDraggingNewEvent = false
    @Published var dragStartTime: Date?
    @Published var dragEndTime: Date?
    @Published var isResizingEvent = false
    @Published var resizingTask: TaskEntity?
    @Published var temporaryStartTime: Date?
    @Published var temporaryEndTime: Date?
    @Published var showingScheduleSheet = false
    @Published var scheduleSheetStartTime: Date?
    @Published var scheduleSheetEndTime: Date?
    @Published var allTasks: [TaskEntity] = []
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Dependencies
    private let dataService: DataService
    private let layoutEngine = EventLayoutEngine()

    // MARK: - Constants
    let hourHeight: CGFloat = 60
    let startHour = 6
    let endHour = 24

    // MARK: - Computed Properties
    var scheduledTasks: [TaskEntity] {
        allTasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            return Calendar.current.isDate(scheduledTime, inSameDayAs: selectedDate)
        }
    }

    var unscheduledTasks: [TaskEntity] {
        allTasks.filter { $0.scheduledTime == nil && !$0.isCompleted }
    }

    // MARK: - Initialization
    init(dataService: DataService, selectedDate: Date = Date()) {
        self.dataService = dataService
        self.selectedDate = selectedDate
    }

    // MARK: - Event Layout
    func layoutEvents(in width: CGFloat) -> [TaskLayout] {
        let config = EventLayoutEngine.LayoutConfig(
            containerWidth: width,
            hourHeight: hourHeight,
            startHour: startHour
        )
        return layoutEngine.layoutTasks(scheduledTasks, config: config)
    }

    // MARK: - Time Calculations

    /// Convert global Y position to time
    /// - Parameter y: Y position from top of time grid (0 = startHour)
    func timeFromGlobalY(_ y: CGFloat) -> Date {
        let minutesPerPixel = 60.0 / hourHeight
        let totalMinutesFromStart = Int(y * minutesPerPixel)
        let totalMinutes = (startHour * 60) + totalMinutesFromStart

        // Clamp to valid range
        let clampedMinutes = max(startHour * 60, min((endHour - 1) * 60 + 59, totalMinutes))
        let hours = clampedMinutes / 60
        let minutes = clampedMinutes % 60

        return selectedDate.setting(hour: hours, minute: minutes) ?? selectedDate
    }

    func timeFromYPosition(_ y: CGFloat) -> Date {
        return timeFromGlobalY(y)
    }

    func yPositionFromTime(_ time: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let totalMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let minutesFromStart = totalMinutes - (startHour * 60)

        return CGFloat(minutesFromStart) * (hourHeight / 60)
    }

    // MARK: - Quick Event Creation

    /// Handle tap on time slot using global Y position
    func handleTimeSlotTap(at globalY: CGFloat) {
        let time = timeFromGlobalY(globalY)
        let roundedTime = time.rounded(toNearest: 15)

        // Set up schedule sheet with default 1-hour duration
        scheduleSheetStartTime = roundedTime
        scheduleSheetEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: roundedTime)
        showingScheduleSheet = true

        HapticManager.shared.lightImpact()
    }

    // MARK: - Drag to Create Event

    /// Track the last time we triggered haptic feedback (for 15-min boundary crossing)
    private var lastHapticTime: Date?

    /// Start dragging to create a new event at the given global Y position
    func startDraggingNewEvent(at globalY: CGFloat) {
        let time = timeFromGlobalY(globalY)
        let roundedTime = time.rounded(toNearest: 15)

        isDraggingNewEvent = true
        dragStartTime = roundedTime
        dragEndTime = roundedTime.addingMinutes(15) // Minimum 15 min
        lastHapticTime = roundedTime

        HapticManager.shared.selectionChanged()
    }

    /// Update the dragged event as user drags to a new global Y position
    func updateDraggedEvent(to globalY: CGFloat) {
        guard let originalStartTime = dragStartTime else { return }

        let currentTime = timeFromGlobalY(globalY)
        let roundedTime = currentTime.rounded(toNearest: 15)

        // Haptic feedback when crossing 15-minute boundaries
        if roundedTime != lastHapticTime {
            HapticManager.shared.selectionChanged()
            lastHapticTime = roundedTime
        }

        // Ensure minimum 15 minute duration
        if roundedTime > originalStartTime {
            // Dragging downward - extend end time
            dragEndTime = roundedTime
        } else if roundedTime < originalStartTime {
            // Dragging upward - adjust start time, keep original as end
            dragStartTime = roundedTime
            dragEndTime = originalStartTime.addingMinutes(15)
        }
    }

    func finishDraggingNewEvent() {
        guard let dragStartTime, let dragEndTime else {
            isDraggingNewEvent = false
            return
        }

        // Open schedule sheet with the dragged time range
        scheduleSheetStartTime = dragStartTime
        scheduleSheetEndTime = dragEndTime
        showingScheduleSheet = true

        // Reset drag state
        isDraggingNewEvent = false
        self.dragStartTime = nil
        self.dragEndTime = nil
        lastHapticTime = nil

        HapticManager.shared.lightImpact()
    }

    func cancelDraggedEvent() {
        isDraggingNewEvent = false
        dragStartTime = nil
        dragEndTime = nil
        lastHapticTime = nil
    }

    // MARK: - Event Resize
    func startResizingEvent(_ task: TaskEntity, edge: CalendarEventView.ResizeEdge) {
        isResizingEvent = true
        resizingTask = task
        selectedTask = task
        // Initialize temporary state with current task times
        temporaryStartTime = task.scheduledTime
        temporaryEndTime = task.scheduledEndTime

        HapticManager.shared.selectionChanged()
    }

    func updateEventResize(_ task: TaskEntity, edge: CalendarEventView.ResizeEdge, yPosition: CGFloat) {
        guard isResizingEvent, resizingTask?.id == task.id else { return }

        let newTime = timeFromYPosition(yPosition).rounded(toNearest: 15)

        switch edge {
        case .top:
            // Update start time in temporary state
            if let endTime = temporaryEndTime ?? task.scheduledEndTime ?? task.scheduledTime?.addingMinutes(60),
               newTime < endTime {
                temporaryStartTime = newTime
            }
        case .bottom:
            // Update end time in temporary state
            if let startTime = temporaryStartTime ?? task.scheduledTime,
               newTime > startTime {
                temporaryEndTime = newTime
            }
        }
    }

    func finishResizingEvent() {
        guard let task = resizingTask else {
            isResizingEvent = false
            temporaryStartTime = nil
            temporaryEndTime = nil
            return
        }

        // Save changes using temporary state
        Task {
            await scheduleTask(
                task,
                startTime: temporaryStartTime ?? task.scheduledTime ?? Date(),
                endTime: temporaryEndTime ?? task.scheduledEndTime
            )
        }

        isResizingEvent = false
        resizingTask = nil
        temporaryStartTime = nil
        temporaryEndTime = nil

        HapticManager.shared.success()
    }

    // MARK: - Event Selection
    func selectEvent(_ task: TaskEntity) {
        if selectedTask?.id == task.id {
            selectedTask = nil // Deselect if already selected
        } else {
            selectedTask = task
        }

        HapticManager.shared.lightImpact()
    }

    func deselectEvent() {
        selectedTask = nil
    }

    // MARK: - Data Operations
    func createQuickEvent(at time: Date, title: String = "New Event") async {
        let roundedTime = time.rounded(toNearest: 15)
        let endTime = Calendar.current.date(byAdding: .hour, value: 1, to: roundedTime)

        do {
            let task = try dataService.createTask(
                title: title,
                scheduledTime: roundedTime,
                scheduledEndTime: endTime
            )

            selectedTask = task
            HapticManager.shared.success()
        } catch {
            handleError(error)
        }
    }

    func updateTask(_ task: TaskEntity) async {
        do {
            try dataService.updateTask(task)
            HapticManager.shared.success()
        } catch {
            handleError(error)
        }
    }

    func deleteTask(_ task: TaskEntity) async {
        do {
            try dataService.deleteTask(task)
            if selectedTask?.id == task.id {
                selectedTask = nil
            }
            HapticManager.shared.success()
        } catch {
            handleError(error)
        }
    }

    func scheduleTask(_ task: TaskEntity, startTime: Date, endTime: Date?) async {
        do {
            try dataService.updateTask(
                task,
                scheduledTime: startTime,
                scheduledEndTime: endTime
            )
            HapticManager.shared.success()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Date Navigation
    func goToPreviousDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) else { return }
        selectedDate = newDate
        deselectEvent()

        HapticManager.shared.lightImpact()
    }

    func goToNextDay() {
        guard let newDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else { return }
        selectedDate = newDate
        deselectEvent()

        HapticManager.shared.lightImpact()
    }

    func goToToday() {
        selectedDate = Date()
        deselectEvent()

        HapticManager.shared.lightImpact()
    }

    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        HapticManager.shared.error()
        print("Error: \(error.localizedDescription)")
    }
}
