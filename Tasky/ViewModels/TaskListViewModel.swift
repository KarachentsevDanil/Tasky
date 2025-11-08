//
//  TaskListViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
import Combine
internal import CoreData

/// ViewModel for managing task lists and tasks
@MainActor
class TaskListViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var tasks: [TaskEntity] = []
    @Published var taskLists: [TaskListEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Properties
    let dataService: DataService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Filter Types
    enum FilterType {
        case all
        case today
        case upcoming
        case inbox
        case completed
        case list(TaskListEntity)
    }

    @Published var currentFilter: FilterType = .all

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
        setupInitialData()
    }

    // MARK: - Setup

    private func setupInitialData() {
        Task {
            do {
                try dataService.createDefaultInboxIfNeeded()
                await loadTaskLists()
                await loadTasks()
            } catch {
                handleError(error)
            }
        }
    }

    // MARK: - Load Data

    /// Load tasks based on current filter
    func loadTasks() async {
        isLoading = true
        defer { isLoading = false }

        do {
            switch currentFilter {
            case .all:
                tasks = try dataService.fetchAllTasks()
            case .today:
                tasks = try dataService.fetchTodayTasks()
            case .upcoming:
                tasks = try dataService.fetchUpcomingTasks()
            case .inbox:
                tasks = try dataService.fetchInboxTasks()
            case .completed:
                tasks = try dataService.fetchCompletedTasks()
            case .list(let list):
                tasks = try dataService.fetchTasks(for: list)
            }
        } catch {
            handleError(error)
        }
    }

    /// Load all task lists
    func loadTaskLists() async {
        do {
            taskLists = try dataService.fetchAllTaskLists()
        } catch {
            handleError(error)
        }
    }

    /// Refresh all data
    func refresh() async {
        await loadTaskLists()
        await loadTasks()
    }

    // MARK: - Task Operations

    /// Create a new task
    func createTask(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        scheduledTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        priority: Int16 = 0,
        list: TaskListEntity? = nil,
        isRecurring: Bool = false,
        recurrenceDays: [Int]? = nil
    ) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(ValidationError.emptyTitle)
            return
        }

        guard title.count <= Constants.Limits.maxTaskTitleLength else {
            handleError(ValidationError.titleTooLong)
            return
        }

        do {
            try dataService.createTask(
                title: title,
                notes: notes,
                dueDate: dueDate,
                scheduledTime: scheduledTime,
                scheduledEndTime: scheduledEndTime,
                priority: priority,
                list: list,
                isRecurring: isRecurring,
                recurrenceDays: recurrenceDays
            )
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Update a task
    func updateTask(
        _ task: TaskEntity,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        priority: Int16? = nil,
        list: TaskListEntity? = nil
    ) async {
        do {
            try dataService.updateTask(
                task,
                title: title,
                notes: notes,
                dueDate: dueDate,
                priority: priority,
                list: list
            )
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Toggle task completion
    func toggleTaskCompletion(_ task: TaskEntity) async {
        do {
            try dataService.toggleTaskCompletion(task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Delete a task
    func deleteTask(_ task: TaskEntity) async {
        do {
            try dataService.deleteTask(task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Delete tasks at offsets
    func deleteTasks(at offsets: IndexSet) async {
        for index in offsets {
            let task = tasks[index]
            await deleteTask(task)
        }
    }

    /// Reorder tasks with drag-and-drop
    func reorderTasks(_ reorderedTasks: [TaskEntity]) async {
        do {
            try dataService.reorderTasks(reorderedTasks)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Task List Operations

    /// Create a new task list
    func createTaskList(name: String, colorHex: String, iconName: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(ValidationError.emptyListName)
            return
        }

        guard name.count <= Constants.Limits.maxListNameLength else {
            handleError(ValidationError.listNameTooLong)
            return
        }

        do {
            try dataService.createTaskList(name: name, colorHex: colorHex, iconName: iconName)
            await loadTaskLists()
        } catch {
            handleError(error)
        }
    }

    /// Update a task list
    func updateTaskList(
        _ list: TaskListEntity,
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil
    ) async {
        do {
            try dataService.updateTaskList(list, name: name, colorHex: colorHex, iconName: iconName)
            await loadTaskLists()
        } catch {
            handleError(error)
        }
    }

    /// Delete a task list
    func deleteTaskList(_ list: TaskListEntity) async {
        do {
            try dataService.deleteTaskList(list)
            await loadTaskLists()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Computed Properties

    var todayTasksCount: Int {
        (try? dataService.fetchTodayTasks().count) ?? 0
    }

    var upcomingTasksCount: Int {
        (try? dataService.fetchUpcomingTasks().count) ?? 0
    }

    var inboxTasksCount: Int {
        (try? dataService.fetchInboxTasks().count) ?? 0
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("Error: \(error.localizedDescription)")
    }
}

// MARK: - Validation Errors
enum ValidationError: LocalizedError {
    case emptyTitle
    case titleTooLong
    case emptyListName
    case listNameTooLong

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Task title cannot be empty"
        case .titleTooLong:
            return "Task title is too long (max \(Constants.Limits.maxTaskTitleLength) characters)"
        case .emptyListName:
            return "List name cannot be empty"
        case .listNameTooLong:
            return "List name is too long (max \(Constants.Limits.maxListNameLength) characters)"
        }
    }
}
