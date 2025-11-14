//
//  DataService.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

internal import CoreData
import Foundation

/// Service layer for data operations
class DataService {

    // MARK: - Properties
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }

    // MARK: - Initialization
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Task Operations

    /// Create a new task
    @discardableResult
    func createTask(
        title: String,
        notes: String? = nil,
        dueDate: Date? = nil,
        scheduledTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        priority: Int16 = 0,
        priorityOrder: Int16 = 0,
        list: TaskListEntity? = nil,
        isRecurring: Bool = false,
        recurrenceDays: [Int]? = nil
    ) throws -> TaskEntity {
        let task = TaskEntity(context: viewContext)
        task.id = UUID()
        task.title = title
        task.notes = notes
        task.dueDate = dueDate
        task.scheduledTime = scheduledTime
        task.scheduledEndTime = scheduledEndTime
        task.priority = priority
        task.priorityOrder = priorityOrder
        task.isCompleted = false
        task.createdAt = Date()
        task.focusTimeSeconds = 0
        task.taskList = list
        task.isRecurring = isRecurring

        if isRecurring, let days = recurrenceDays {
            task.setRecurrenceDays(days)
        }

        try persistenceController.save(context: viewContext)

        // Schedule notifications for the task
        Task { @MainActor in
            await scheduleNotificationsForTask(task)
        }

        return task
    }

    /// Update an existing task
    func updateTask(
        _ task: TaskEntity,
        title: String? = nil,
        notes: String? = nil,
        dueDate: Date? = nil,
        scheduledTime: Date? = nil,
        scheduledEndTime: Date? = nil,
        priority: Int16? = nil,
        priorityOrder: Int16? = nil,
        list: TaskListEntity? = nil
    ) throws {
        if let title = title {
            task.title = title
        }
        if let notes = notes {
            task.notes = notes
        }
        if let dueDate = dueDate {
            task.dueDate = dueDate
        }
        if let scheduledTime = scheduledTime {
            task.scheduledTime = scheduledTime
        }
        if let scheduledEndTime = scheduledEndTime {
            task.scheduledEndTime = scheduledEndTime
        }
        if let priority = priority {
            task.priority = priority
        }
        if let priorityOrder = priorityOrder {
            task.priorityOrder = priorityOrder
        }
        if let list = list {
            task.taskList = list
        }

        try persistenceController.save(context: viewContext)

        // Reschedule notifications if dates changed
        if dueDate != nil || scheduledTime != nil || scheduledEndTime != nil {
            Task { @MainActor in
                NotificationManager.shared.cancelTaskNotifications(taskId: task.id)
                await scheduleNotificationsForTask(task)
            }
        }
    }

    /// Toggle task completion status
    func toggleTaskCompletion(_ task: TaskEntity) throws {
        task.isCompleted.toggle()
        task.completedAt = task.isCompleted ? Date() : nil

        try persistenceController.save(context: viewContext)

        // Cancel notifications when task is completed
        if task.isCompleted {
            NotificationManager.shared.cancelTaskNotifications(taskId: task.id)
        }
    }

    /// Delete a task
    func deleteTask(_ task: TaskEntity) throws {
        // Cancel notifications before deleting
        NotificationManager.shared.cancelTaskNotifications(taskId: task.id)

        viewContext.delete(task)
        try persistenceController.save(context: viewContext)
    }

    /// Reorder tasks by updating priorityOrder
    func reorderTasks(_ tasks: [TaskEntity]) throws {
        for (index, task) in tasks.enumerated() {
            task.priorityOrder = Int16(index)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Fetch a task by its ObjectID
    func fetchTask(by objectID: NSManagedObjectID) -> TaskEntity? {
        do {
            return try viewContext.existingObject(with: objectID) as? TaskEntity
        } catch {
            return nil
        }
    }

    /// Fetch all tasks
    func fetchAllTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]
        fetchRequest.fetchLimit = 1000  // Reasonable limit for task management app
        fetchRequest.fetchBatchSize = 50  // Load 50 tasks at a time for better memory usage
        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch tasks for today
    func fetchTodayTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Include tasks with dueDate today OR scheduledTime today
        fetchRequest.predicate = NSPredicate(
            format: "(dueDate >= %@ AND dueDate < %@) OR (scheduledTime >= %@ AND scheduledTime < %@)",
            startOfDay as NSDate,
            endOfDay as NSDate,
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.priorityOrder, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.scheduledTime, ascending: true),
            NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)
        ]
        fetchRequest.fetchBatchSize = 20  // Most users won't have more than 20 tasks per day

        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch upcoming tasks (next 7 days)
    func fetchUpcomingTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()

        let calendar = Calendar.current
        let now = Date()
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: now)!

        fetchRequest.predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate <= %@ AND isCompleted == NO",
            now as NSDate,
            nextWeek as NSDate
        )
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)]
        fetchRequest.fetchBatchSize = 30  // 7 days of tasks

        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch inbox tasks (tasks without a list)
    func fetchInboxTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "taskList == nil AND isCompleted == NO")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]
        fetchRequest.fetchBatchSize = 30

        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch completed tasks
    func fetchCompletedTasks() throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.completedAt, ascending: false)]
        fetchRequest.fetchLimit = 500  // Limit completed tasks shown
        fetchRequest.fetchBatchSize = 50  // Load in batches

        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch tasks for a specific list
    func fetchTasks(for list: TaskListEntity) throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "taskList == %@", list)
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]
        fetchRequest.fetchBatchSize = 30

        return try viewContext.fetch(fetchRequest)
    }

    // MARK: - Task List Operations

    /// Create a new task list
    @discardableResult
    func createTaskList(
        name: String,
        colorHex: String? = nil,
        iconName: String? = nil
    ) throws -> TaskListEntity {
        // Check max lists limit
        let existingLists = try fetchAllTaskLists()
        guard existingLists.count < Constants.Limits.maxCustomLists else {
            throw DataServiceError.maxListsReached
        }

        let list = TaskListEntity(context: viewContext)
        list.id = UUID()
        list.name = name
        list.colorHex = colorHex ?? Constants.Colors.defaultListColor
        list.iconName = iconName ?? Constants.Icons.list
        list.createdAt = Date()
        list.sortOrder = Int16(existingLists.count)

        try persistenceController.save(context: viewContext)
        return list
    }

    /// Update an existing task list
    func updateTaskList(
        _ list: TaskListEntity,
        name: String? = nil,
        colorHex: String? = nil,
        iconName: String? = nil
    ) throws {
        if let name = name {
            list.name = name
        }
        if let colorHex = colorHex {
            list.colorHex = colorHex
        }
        if let iconName = iconName {
            list.iconName = iconName
        }

        try persistenceController.save(context: viewContext)
    }

    /// Delete a task list
    func deleteTaskList(_ list: TaskListEntity) throws {
        viewContext.delete(list)
        try persistenceController.save(context: viewContext)
    }

    /// Fetch all task lists
    func fetchAllTaskLists() throws -> [TaskListEntity] {
        let fetchRequest: NSFetchRequest<TaskListEntity> = TaskListEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TaskListEntity.sortOrder, ascending: true)]
        return try viewContext.fetch(fetchRequest)
    }

    // MARK: - Notification Helpers

    /// Schedule notifications for a task based on its dates
    @MainActor
    private func scheduleNotificationsForTask(_ task: TaskEntity) async {
        let taskId = task.id
        let title = task.title

        // Schedule due date notification
        if let dueDate = task.dueDate, dueDate > Date() {
            try? await NotificationManager.shared.scheduleTaskNotification(
                taskId: taskId,
                title: title,
                date: dueDate,
                isScheduledTime: false
            )

            // Schedule reminder 15 minutes before due date
            try? await NotificationManager.shared.scheduleTaskReminderNotification(
                taskId: taskId,
                title: title,
                dueDate: dueDate
            )
        }

        // Schedule scheduled time notification
        if let scheduledTime = task.scheduledTime, scheduledTime > Date() {
            try? await NotificationManager.shared.scheduleTaskNotification(
                taskId: taskId,
                title: title,
                date: scheduledTime,
                isScheduledTime: true
            )
        }
    }

    // MARK: - Initialization Helpers

    /// Create default inbox list if it doesn't exist
    func createDefaultInboxIfNeeded() throws {
        let lists = try fetchAllTaskLists()
        if lists.isEmpty {
            try createTaskList(
                name: Constants.DefaultLists.inboxName,
                colorHex: Constants.Colors.defaultListColor,
                iconName: Constants.Icons.inbox
            )
        }
    }
}

// MARK: - Errors
enum DataServiceError: LocalizedError {
    case maxListsReached

    var errorDescription: String? {
        switch self {
        case .maxListsReached:
            return "Maximum number of lists (\(Constants.Limits.maxCustomLists)) reached"
        }
    }
}
