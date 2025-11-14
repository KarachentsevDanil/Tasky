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
    @Published var showingScheduleSheet = false
    @Published var scheduleSheetStartTime: Date?
    @Published var scheduleSheetEndTime: Date?
    @Published var allTasks: [TaskEntity] = []

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
    func timeFromYPosition(_ y: CGFloat) -> Date {
        let minutesFromStart = Int(y / (hourHeight / 60))
        let totalMinutes = (startHour * 60) + minutesFromStart
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        return selectedDate.setting(hour: hours, minute: minutes) ?? selectedDate
    }

    func yPositionFromTime(_ time: Date) -> CGFloat {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        let totalMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let minutesFromStart = totalMinutes - (startHour * 60)

        return CGFloat(minutesFromStart) * (hourHeight / 60)
    }

    func timeFromHourAndLocation(hour: Int, location: CGPoint) -> Date {
        // Calculate minutes based on vertical position within the hour
        let minutesIntoHour = Int((location.y / hourHeight) * 60)
        let clampedMinutes = max(0, min(59, minutesIntoHour))

        return selectedDate.setting(hour: hour, minute: clampedMinutes) ?? selectedDate
    }

    // MARK: - Quick Event Creation
    func handleTimeSlotTap(hour: Int, location: CGPoint) {
        let time = timeFromHourAndLocation(hour: hour, location: location)
        let roundedTime = time.rounded(toNearest: 15)

        // Set up schedule sheet with default 1-hour duration
        scheduleSheetStartTime = roundedTime
        scheduleSheetEndTime = Calendar.current.date(byAdding: .hour, value: 1, to: roundedTime)
        showingScheduleSheet = true

        HapticManager.shared.lightImpact()
    }

    // MARK: - Drag to Create Event
    func startDraggingNewEvent(hour: Int, location: CGPoint) {
        let time = timeFromHourAndLocation(hour: hour, location: location)
        isDraggingNewEvent = true
        dragStartTime = time.rounded(toNearest: 15)
        dragEndTime = dragStartTime?.addingMinutes(30) // Default 30 min

        HapticManager.shared.selectionChanged()
    }

    func updateDraggedEvent(hour: Int, location: CGPoint) {
        guard let dragStartTime else { return }

        let currentTime = timeFromHourAndLocation(hour: hour, location: location)
        let roundedTime = currentTime.rounded(toNearest: 15)

        // Ensure minimum 15 minute duration
        if roundedTime > dragStartTime {
            dragEndTime = roundedTime
        } else if roundedTime < dragStartTime {
            // Dragging upward - adjust start time
            self.dragStartTime = roundedTime
            dragEndTime = dragStartTime.addingMinutes(15)
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

        HapticManager.shared.lightImpact()
    }

    func cancelDraggedEvent() {
        isDraggingNewEvent = false
        dragStartTime = nil
        dragEndTime = nil
    }

    // MARK: - Event Resize
    func startResizingEvent(_ task: TaskEntity, edge: CalendarEventView.ResizeEdge) {
        isResizingEvent = true
        resizingTask = task
        selectedTask = task

        HapticManager.shared.selectionChanged()
    }

    func updateEventResize(_ task: TaskEntity, edge: CalendarEventView.ResizeEdge, yPosition: CGFloat) {
        guard isResizingEvent, resizingTask?.id == task.id else { return }

        let newTime = timeFromYPosition(yPosition).rounded(toNearest: 15)

        switch edge {
        case .top:
            // Update start time
            if let endTime = task.scheduledEndTime ?? task.scheduledTime?.addingMinutes(60),
               newTime < endTime {
                task.scheduledTime = newTime
            }
        case .bottom:
            // Update end time
            if let startTime = task.scheduledTime,
               newTime > startTime {
                task.scheduledEndTime = newTime
            }
        }
    }

    func finishResizingEvent() {
        guard let task = resizingTask else {
            isResizingEvent = false
            return
        }

        // Save changes
        Task {
            await updateTask(task)
        }

        isResizingEvent = false
        resizingTask = nil

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
            print("Error creating quick event: \(error)")
        }
    }

    func updateTask(_ task: TaskEntity) async {
        do {
            try dataService.updateTask(task)
            HapticManager.shared.success()
        } catch {
            print("Error updating task: \(error)")
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
            print("Error deleting task: \(error)")
        }
    }

    func scheduleTask(_ task: TaskEntity, startTime: Date, endTime: Date?) async {
        task.scheduledTime = startTime
        task.scheduledEndTime = endTime

        await updateTask(task)
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
}
