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
    @Published var tags: [TagEntity] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    // MARK: - Multi-Select Mode
    @Published var isMultiSelectMode = false
    @Published var selectedTaskIds: Set<UUID> = []

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
        case tag(TagEntity)
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
                await loadTags()
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
            case .tag(let tag):
                tasks = try dataService.fetchTasks(withTag: tag)
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

    /// Load all tags
    func loadTags() async {
        do {
            tags = try dataService.fetchAllTags()
        } catch {
            handleError(error)
        }
    }

    /// Refresh all data
    func refresh() async {
        await loadTaskLists()
        await loadTags()
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

    /// Update a task with all editable fields
    func updateTask(
        _ task: TaskEntity,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        scheduledTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        priority: Int16? = nil,
        list: TaskListEntity? = nil,
        isRecurring: Bool? = nil,
        recurrenceDays: [Int]? = nil
    ) async {
        do {
            try dataService.updateTask(
                task,
                title: title,
                notes: notes,
                dueDate: dueDate,
                scheduledTime: scheduledTime,
                scheduledEndTime: scheduledEndTime,
                priority: priority,
                list: list
            )

            // Update recurrence fields directly on task
            if let isRecurring {
                task.isRecurring = isRecurring
            }
            if let recurrenceDays {
                // Convert array to comma-separated string
                if recurrenceDays.isEmpty {
                    task.recurrenceDays = nil
                } else {
                    task.recurrenceDays = recurrenceDays.sorted().map { String($0) }.joined(separator: ",")
                }
            }

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

    // MARK: - Tag Operations

    /// Create a new tag
    func createTag(name: String, colorHex: String? = nil) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            handleError(ValidationError.emptyTagName)
            return
        }

        do {
            try dataService.createTag(name: name, colorHex: colorHex)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    /// Update a tag
    func updateTag(_ tag: TagEntity, name: String? = nil, colorHex: String? = nil) async {
        do {
            try dataService.updateTag(tag, name: name, colorHex: colorHex)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    /// Delete a tag
    func deleteTag(_ tag: TagEntity) async {
        do {
            try dataService.deleteTag(tag)
            await loadTags()
        } catch {
            handleError(error)
        }
    }

    /// Add tag to task
    func addTag(_ tag: TagEntity, to task: TaskEntity) async {
        do {
            try dataService.addTag(tag, to: task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Remove tag from task
    func removeTag(_ tag: TagEntity, from task: TaskEntity) async {
        do {
            try dataService.removeTag(tag, from: task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Set tags for a task
    func setTags(_ tags: [TagEntity], for task: TaskEntity) async {
        do {
            try dataService.setTags(tags, for: task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Subtask Operations

    /// Create a subtask for a task
    func createSubtask(title: String, for task: TaskEntity) async {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        do {
            try dataService.createSubtask(title: title, for: task)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Toggle subtask completion
    func toggleSubtaskCompletion(_ subtask: SubtaskEntity) async {
        do {
            try dataService.toggleSubtaskCompletion(subtask)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Delete a subtask
    func deleteSubtask(_ subtask: SubtaskEntity) async {
        do {
            try dataService.deleteSubtask(subtask)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Update subtask title
    func updateSubtask(_ subtask: SubtaskEntity, title: String) async {
        do {
            try dataService.updateSubtask(subtask, title: title)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Reorder subtasks
    func reorderSubtasks(_ subtasks: [SubtaskEntity]) async {
        do {
            try dataService.reorderSubtasks(subtasks)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Convert subtask to task
    func convertSubtaskToTask(_ subtask: SubtaskEntity) async {
        do {
            try dataService.convertSubtaskToTask(subtask)
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Multi-Select Mode

    /// Enter multi-select mode
    func enterMultiSelectMode() {
        isMultiSelectMode = true
        selectedTaskIds.removeAll()
    }

    /// Exit multi-select mode
    func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedTaskIds.removeAll()
    }

    /// Toggle task selection
    func toggleTaskSelection(_ task: TaskEntity) {
        if selectedTaskIds.contains(task.id) {
            selectedTaskIds.remove(task.id)
        } else {
            selectedTaskIds.insert(task.id)
        }
    }

    /// Select all visible tasks
    func selectAllTasks() {
        selectedTaskIds = Set(tasks.map { $0.id })
    }

    /// Deselect all tasks
    func deselectAllTasks() {
        selectedTaskIds.removeAll()
    }

    /// Check if a task is selected
    func isTaskSelected(_ task: TaskEntity) -> Bool {
        selectedTaskIds.contains(task.id)
    }

    /// Get selected tasks
    var selectedTasks: [TaskEntity] {
        tasks.filter { selectedTaskIds.contains($0.id) }
    }

    /// Selected tasks count
    var selectedTasksCount: Int {
        selectedTaskIds.count
    }

    // MARK: - Bulk Operations

    /// Bulk complete selected tasks
    func bulkCompleteSelectedTasks() async {
        let tasksToComplete = selectedTasks
        guard !tasksToComplete.isEmpty else { return }

        do {
            try dataService.completeTasks(tasksToComplete)
            HapticManager.shared.success()
            exitMultiSelectMode()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Bulk delete selected tasks
    func bulkDeleteSelectedTasks() async {
        let tasksToDelete = selectedTasks
        guard !tasksToDelete.isEmpty else { return }

        do {
            try dataService.deleteTasks(tasksToDelete)
            HapticManager.shared.success()
            exitMultiSelectMode()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Bulk reschedule selected tasks
    func bulkRescheduleSelectedTasks(to date: Date) async {
        let tasksToReschedule = selectedTasks
        guard !tasksToReschedule.isEmpty else { return }

        do {
            try dataService.rescheduleTasks(tasksToReschedule, to: date)
            HapticManager.shared.success()
            exitMultiSelectMode()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Bulk move selected tasks to a list
    func bulkMoveSelectedTasks(to list: TaskListEntity?) async {
        let tasksToMove = selectedTasks
        guard !tasksToMove.isEmpty else { return }

        do {
            try dataService.moveTasksToList(tasksToMove, list: list)
            HapticManager.shared.success()
            exitMultiSelectMode()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Bulk set priority for selected tasks
    func bulkSetPriorityForSelectedTasks(_ priority: Int16) async {
        let tasks = selectedTasks
        guard !tasks.isEmpty else { return }

        do {
            try dataService.updateTasksPriority(tasks, priority: priority)
            HapticManager.shared.success()
            exitMultiSelectMode()
            await loadTasks()
        } catch {
            handleError(error)
        }
    }

    /// Bulk add tag to selected tasks
    func bulkAddTagToSelectedTasks(_ tag: TagEntity) async {
        let tasks = selectedTasks
        guard !tasks.isEmpty else { return }

        do {
            try dataService.addTagToTasks(tag, tasks: tasks)
            HapticManager.shared.success()
            exitMultiSelectMode()
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
    case emptyTagName

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
        case .emptyTagName:
            return "Tag name cannot be empty"
        }
    }
}
