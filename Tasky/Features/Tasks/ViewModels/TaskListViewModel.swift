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

    // MARK: - Undo Support
    private var pendingDeletion: PendingTaskDeletion?
    private var pendingCompletion: PendingTaskCompletion?

    struct PendingTaskDeletion {
        let taskObjectID: NSManagedObjectID
        let timer: DispatchWorkItem
    }

    struct PendingTaskCompletion {
        let taskObjectID: NSManagedObjectID
        let wasCompleted: Bool
        let timer: DispatchWorkItem
    }

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

    /// Toggle task completion immediately (no undo)
    func toggleTaskCompletion(_ task: TaskEntity) async {
        do {
            try dataService.toggleTaskCompletion(task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Toggle task completion with undo support
    func toggleTaskCompletionWithUndo(_ task: TaskEntity, delay: TimeInterval = 5.0) async {
        // Cancel any pending completion
        cancelPendingCompletion()

        let wasCompleted = task.isCompleted
        let taskObjectID = task.objectID

        // Toggle immediately in UI
        do {
            try dataService.toggleTaskCompletion(task)
            await loadTasks()
        } catch {
            handleError(error)
            return
        }

        // Schedule auto-commit (to prevent reverting if user does nothing)
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                // Just clear the pending state - change is already saved
                self?.pendingCompletion = nil
            }
        }

        pendingCompletion = PendingTaskCompletion(taskObjectID: taskObjectID, wasCompleted: wasCompleted, timer: workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Undo the pending completion toggle
    func undoCompletion() async {
        guard let pending = pendingCompletion else { return }

        // Cancel the timer
        pending.timer.cancel()

        // Fetch the task by ObjectID and toggle back
        guard let task = dataService.fetchTask(by: pending.taskObjectID) else {
            pendingCompletion = nil
            return
        }

        // Toggle back to original state
        do {
            try dataService.toggleTaskCompletion(task)
            await loadTasks()
        } catch {
            handleError(error)
        }

        // Clear pending completion
        pendingCompletion = nil
    }

    /// Cancel any pending completion
    private func cancelPendingCompletion() {
        pendingCompletion?.timer.cancel()
        pendingCompletion = nil
    }

    /// Delete a task immediately (no undo)
    func deleteTask(_ task: TaskEntity) async {
        do {
            try dataService.deleteTask(task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Delete a task with undo support (delayed deletion)
    func deleteTaskWithUndo(_ task: TaskEntity, delay: TimeInterval = 5.0) async {
        // Cancel any pending deletion
        cancelPendingDeletion()

        let taskObjectID = task.objectID

        // Hide the task immediately from UI
        tasks.removeAll { $0.id == task.id }

        // Schedule actual deletion
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                await self?.commitDeletion(taskObjectID)
            }
        }

        pendingDeletion = PendingTaskDeletion(taskObjectID: taskObjectID, timer: workItem)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    /// Undo the pending deletion
    func undoDelete() async {
        guard let pending = pendingDeletion else { return }

        // Cancel the timer
        pending.timer.cancel()

        // Clear pending deletion first
        pendingDeletion = nil

        // Restore the task to UI by reloading
        await loadTasks()
    }

    /// Commit the actual deletion after timer expires
    private func commitDeletion(_ taskObjectID: NSManagedObjectID) async {
        // Fetch the task by ObjectID
        guard let task = dataService.fetchTask(by: taskObjectID) else {
            pendingDeletion = nil
            return
        }

        do {
            try dataService.deleteTask(task)
            pendingDeletion = nil
        } catch {
            // If deletion fails, restore the task
            await loadTasks()
            handleError(error)
        }
    }

    /// Cancel any pending deletion
    private func cancelPendingDeletion() {
        pendingDeletion?.timer.cancel()
        pendingDeletion = nil
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

    /// Schedule a task with start and end times
    func scheduleTask(
        _ task: TaskEntity,
        startTime: Date?,
        endTime: Date?
    ) async {
        do {
            try dataService.updateTask(
                task,
                scheduledTime: startTime,
                scheduledEndTime: endTime
            )
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

    // MARK: - AI Prioritization

    /// Update AI priority scores for all tasks
    func updateAIPriorityScores() async {
        do {
            try dataService.updateAIPriorityScores()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Computed Properties

    /// Get the top priority task (highest AI score, not completed)
    var topPriorityTask: TaskEntity? {
        tasks.filter { !$0.isCompleted }
            .max(by: { $0.aiPriorityScore < $1.aiPriorityScore })
    }

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
