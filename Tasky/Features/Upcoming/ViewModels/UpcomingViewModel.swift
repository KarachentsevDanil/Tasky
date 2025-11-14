//
//  UpcomingViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation
import Combine

/// ViewModel for managing upcoming tasks logic
@MainActor
final class UpcomingViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var groupedTasks: [(date: Date, tasks: [TaskEntity])] = []
    @Published var tasksByDate: [Date: [TaskEntity]] = [:]
    @Published var selectedDateForFiltering: Date?

    // MARK: - Private Properties
    private let taskListViewModel: TaskListViewModel
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current

    // MARK: - Initialization
    init(taskListViewModel: TaskListViewModel) {
        self.taskListViewModel = taskListViewModel
        setupBindings()
    }

    // MARK: - Setup
    private func setupBindings() {
        // Observe changes to tasks and selected date filter
        taskListViewModel.$tasks
            .combineLatest($selectedDateForFiltering)
            .map { [weak self] tasks, filterDate in
                self?.computeGroupedTasks(tasks: tasks, filterDate: filterDate) ?? []
            }
            .assign(to: &$groupedTasks)

        // Compute tasks by date for calendar indicators
        taskListViewModel.$tasks
            .map { [weak self] tasks in
                self?.computeTasksByDate(tasks: tasks) ?? [:]
            }
            .assign(to: &$tasksByDate)
    }

    // MARK: - Business Logic
    private func computeGroupedTasks(tasks: [TaskEntity], filterDate: Date?) -> [(date: Date, tasks: [TaskEntity])] {
        let now = Date()

        // Determine filtering logic based on selected date
        let filteredTasks: [TaskEntity]

        if let filterDate = filterDate {
            let isToday = calendar.isDateInToday(filterDate)
            let isPast = filterDate < calendar.startOfDay(for: now)

            if isToday {
                // If today is selected, show all tasks >= today
                filteredTasks = tasks.filter { task in
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
                filteredTasks = tasks.filter { task in
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
                filteredTasks = tasks.filter { task in
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
            filteredTasks = tasks.filter { task in
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

    private func computeTasksByDate(tasks: [TaskEntity]) -> [Date: [TaskEntity]] {
        var tasksByDate: [Date: [TaskEntity]] = [:]

        for task in tasks {
            if let dueDate = task.dueDate {
                let dayStart = calendar.startOfDay(for: dueDate)
                tasksByDate[dayStart, default: []].append(task)
            }
            if let scheduledTime = task.scheduledTime {
                let dayStart = calendar.startOfDay(for: scheduledTime)
                if !tasksByDate[dayStart, default: []].contains(where: { $0.id == task.id }) {
                    tasksByDate[dayStart, default: []].append(task)
                }
            }
        }

        return tasksByDate
    }

    // MARK: - Public Methods
    func tasksForDate(_ date: Date) -> [TaskEntity] {
        let dayStart = calendar.startOfDay(for: date)
        return tasksByDate[dayStart] ?? []
    }

    func clearDateFilter() {
        selectedDateForFiltering = nil
    }

    func setDateFilter(_ date: Date) {
        selectedDateForFiltering = date
    }
}
