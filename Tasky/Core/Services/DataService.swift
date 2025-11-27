//
//  DataService.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

internal import CoreData
import Foundation
import WidgetKit

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

    // MARK: - Widget Refresh

    /// Notify widgets to refresh their data
    private func refreshWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
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
        recurrenceDays: [Int]? = nil,
        estimatedDuration: Int16 = 0
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
        task.estimatedDuration = estimatedDuration
        task.taskList = list
        task.isRecurring = isRecurring

        if isRecurring, let days = recurrenceDays {
            task.setRecurrenceDays(days)
        }

        // Calculate initial AI priority score
        task.aiPriorityScore = calculateAIPriorityScore(for: task)

        try persistenceController.save(context: viewContext)

        // Refresh widgets to show new task
        refreshWidgets()

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

        // Recalculate AI priority score if any relevant field changed
        if dueDate != nil || scheduledTime != nil || priority != nil {
            task.aiPriorityScore = calculateAIPriorityScore(for: task)
        }

        try persistenceController.save(context: viewContext)

        // Refresh widgets
        refreshWidgets()

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

        // Refresh widgets
        refreshWidgets()

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

        // Refresh widgets
        refreshWidgets()
    }

    /// Delete a task by its UUID
    func deleteTaskById(_ id: UUID) throws {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let tasks = try viewContext.fetch(request)
        if let task = tasks.first {
            try deleteTask(task)
        }
    }

    /// Fetch a task by its UUID
    func fetchTaskById(_ id: UUID) throws -> TaskEntity? {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        let tasks = try viewContext.fetch(request)
        return tasks.first
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
            NSSortDescriptor(keyPath: \TaskEntity.aiPriorityScore, ascending: false), // Highest score first
            NSSortDescriptor(keyPath: \TaskEntity.scheduledTime, ascending: true)
        ]
        fetchRequest.fetchBatchSize = 20  // Most users won't have more than 20 tasks per day

        let tasks = try viewContext.fetch(fetchRequest)

        // Update AI scores before returning (ensures they're current)
        for task in tasks where !task.isCompleted {
            task.aiPriorityScore = calculateAIPriorityScore(for: task)
        }
        try? persistenceController.save(context: viewContext)

        return tasks
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

    // MARK: - AI Prioritization

    /// Calculate AI priority score for a task
    /// Formula: Score = (Urgency × 3) + (Importance × 2) + (Quick Win × 1) + (Staleness × 1)
    func calculateAIPriorityScore(for task: TaskEntity) -> Double {
        var score: Double = 0

        // Urgency scoring (weight: 3)
        let urgencyScore = calculateUrgencyScore(for: task)
        score += urgencyScore * 3

        // Importance scoring (weight: 2) - based on manual priority
        let importanceScore = calculateImportanceScore(for: task)
        score += importanceScore * 2

        // Quick win scoring (weight: 1)
        let quickWinScore = task.isQuickWin ? 10.0 : 0.0
        score += quickWinScore * 1

        // Staleness scoring (weight: 1) - tasks sitting around for a while
        let stalenessScore = calculateStalenessScore(for: task)
        score += stalenessScore * 1

        return score
    }

    /// Calculate urgency score based on due date and scheduled time
    private func calculateUrgencyScore(for task: TaskEntity) -> Double {
        let now = Date()
        let calendar = Calendar.current

        // Check scheduled time first (higher priority)
        if let scheduledTime = task.scheduledTime {
            if scheduledTime < now {
                return 100 // Overdue scheduled time
            } else if calendar.isDateInToday(scheduledTime) {
                return 50 // Scheduled today
            } else if calendar.isDateInTomorrow(scheduledTime) {
                return 25 // Scheduled tomorrow
            }
        }

        // Check due date
        if let dueDate = task.dueDate {
            if dueDate < now && !calendar.isDateInToday(dueDate) {
                return 100 // Overdue
            } else if calendar.isDateInToday(dueDate) {
                return 50 // Due today
            } else if calendar.isDateInTomorrow(dueDate) {
                return 25 // Due tomorrow
            }
        }

        return 0
    }

    /// Calculate importance score based on manual priority
    private func calculateImportanceScore(for task: TaskEntity) -> Double {
        switch task.priority {
        case 2: return 30 // High priority
        case 1: return 15 // Medium priority
        default: return 0 // No/low priority
        }
    }

    /// Calculate staleness score (tasks older than 3 days get extra points)
    private func calculateStalenessScore(for task: TaskEntity) -> Double {
        let stalenessInDays = task.stalenessInDays
        guard stalenessInDays > 3 else { return 0 }

        let staleDays = stalenessInDays - 3
        let score = Double(staleDays) * 2
        return min(score, 20) // Max +20 for staleness
    }

    /// Update AI priority scores for all incomplete tasks
    func updateAIPriorityScores() throws {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isCompleted == NO")
        let tasks = try viewContext.fetch(fetchRequest)

        for task in tasks {
            task.aiPriorityScore = calculateAIPriorityScore(for: task)
        }

        try persistenceController.save(context: viewContext)
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

    // MARK: - Batch Operations for Bulk AI Tools

    /// Complete multiple tasks at once (single save)
    @discardableResult
    func completeTasks(_ tasks: [TaskEntity], completed: Bool = true) throws -> Int {
        var count = 0
        for task in tasks {
            if task.isCompleted != completed {
                task.isCompleted = completed
                task.completedAt = completed ? Date() : nil
                count += 1

                // Cancel notifications when completed
                if completed {
                    NotificationManager.shared.cancelTaskNotifications(taskId: task.id)
                }
            }
        }
        try persistenceController.save(context: viewContext)
        refreshWidgets()
        return count
    }

    /// Reschedule multiple tasks to a new date (single save)
    @discardableResult
    func rescheduleTasks(_ tasks: [TaskEntity], to newDate: Date, time: Date? = nil) throws -> Int {
        for task in tasks {
            task.dueDate = newDate
            if let time = time {
                task.scheduledTime = time
            }
            // Increment reschedule count for stuck task tracking
            task.rescheduleCount += 1

            // Recalculate AI priority score
            task.aiPriorityScore = calculateAIPriorityScore(for: task)

            // Reschedule notifications
            NotificationManager.shared.cancelTaskNotifications(taskId: task.id)
            Task { @MainActor in
                if newDate > Date() {
                    try? await NotificationManager.shared.scheduleTaskNotification(
                        taskId: task.id,
                        title: task.title,
                        date: newDate,
                        isScheduledTime: false
                    )
                }
            }
        }
        try persistenceController.save(context: viewContext)
        refreshWidgets()
        return tasks.count
    }

    /// Delete multiple tasks at once (single save)
    @discardableResult
    func deleteTasks(_ tasks: [TaskEntity]) throws -> Int {
        let count = tasks.count
        for task in tasks {
            NotificationManager.shared.cancelTaskNotifications(taskId: task.id)
            viewContext.delete(task)
        }
        try persistenceController.save(context: viewContext)
        refreshWidgets()
        return count
    }

    /// Update priority for multiple tasks (single save)
    @discardableResult
    func updateTasksPriority(_ tasks: [TaskEntity], priority: Int16) throws -> Int {
        for task in tasks {
            task.priority = priority
            task.aiPriorityScore = calculateAIPriorityScore(for: task)
        }
        try persistenceController.save(context: viewContext)
        refreshWidgets()
        return tasks.count
    }

    /// Move multiple tasks to a list (single save)
    @discardableResult
    func moveTasksToList(_ tasks: [TaskEntity], list: TaskListEntity?) throws -> Int {
        for task in tasks {
            task.taskList = list
        }
        try persistenceController.save(context: viewContext)
        refreshWidgets()
        return tasks.count
    }

    // MARK: - Filter-Based Queries for Bulk Operations

    /// Fetch tasks matching filter criteria
    func fetchTasks(matching criteria: TaskFilterCriteria) throws -> [TaskEntity] {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = criteria.buildPredicate()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.priority, ascending: false),
            NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)
        ]
        fetchRequest.fetchBatchSize = 50
        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch overdue tasks (due before today, not completed)
    func fetchOverdueTasks() throws -> [TaskEntity] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "dueDate < %@ AND isCompleted == NO",
            startOfToday as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)]
        return try viewContext.fetch(request)
    }

    /// Fetch tasks older than specified days
    func fetchTasksOlderThan(days: Int, completedOnly: Bool = false) throws -> [TaskEntity] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let request = TaskEntity.fetchRequest()

        if completedOnly {
            request.predicate = NSPredicate(
                format: "completedAt < %@ AND isCompleted == YES",
                cutoffDate as NSDate
            )
        } else {
            request.predicate = NSPredicate(
                format: "createdAt < %@",
                cutoffDate as NSDate
            )
        }
        return try viewContext.fetch(request)
    }

    /// Fetch tasks completed within a date range
    func fetchTasksCompletedBetween(start: Date, end: Date) throws -> [TaskEntity] {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "completedAt >= %@ AND completedAt < %@ AND isCompleted == YES",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.completedAt, ascending: false)]
        return try viewContext.fetch(request)
    }

    /// Fetch tasks created within a date range
    func fetchTasksCreatedBetween(start: Date, end: Date) throws -> [TaskEntity] {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "createdAt >= %@ AND createdAt < %@",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)]
        return try viewContext.fetch(request)
    }

    /// Get task count for a specific list
    func fetchTaskCount(for list: TaskListEntity, completedOnly: Bool = false) throws -> Int {
        let request = TaskEntity.fetchRequest()
        if completedOnly {
            request.predicate = NSPredicate(format: "taskList == %@ AND isCompleted == YES", list)
        } else {
            request.predicate = NSPredicate(format: "taskList == %@", list)
        }
        return try viewContext.count(for: request)
    }

    /// Fetch high priority incomplete tasks
    func fetchHighPriorityPendingTasks() throws -> [TaskEntity] {
        let request = TaskEntity.fetchRequest()
        request.predicate = NSPredicate(format: "priority >= 2 AND isCompleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.priority, ascending: false),
            NSSortDescriptor(keyPath: \TaskEntity.dueDate, ascending: true)
        ]
        return try viewContext.fetch(request)
    }

    // MARK: - Focus Session Operations

    /// Fetch today's focus sessions
    func fetchTodaysFocusSessions() throws -> [FocusSessionEntity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try fetchFocusSessions(from: startOfDay, to: endOfDay)
    }

    /// Fetch yesterday's focus sessions
    func fetchYesterdaysFocusSessions() throws -> [FocusSessionEntity] {
        let calendar = Calendar.current
        let startOfYesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        let startOfToday = calendar.startOfDay(for: Date())

        return try fetchFocusSessions(from: startOfYesterday, to: startOfToday)
    }

    /// Fetch focus sessions within a date range
    func fetchFocusSessions(from startDate: Date, to endDate: Date) throws -> [FocusSessionEntity] {
        let request = FocusSessionEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "startTime >= %@ AND startTime < %@ AND completed == YES",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSessionEntity.startTime, ascending: false)]
        return try viewContext.fetch(request)
    }

    /// Fetch all completed focus sessions
    func fetchAllFocusSessions() throws -> [FocusSessionEntity] {
        let request = FocusSessionEntity.fetchRequest()
        request.predicate = NSPredicate(format: "completed == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSessionEntity.startTime, ascending: false)]
        return try viewContext.fetch(request)
    }

    /// Fetch focus sessions grouped by day for heatmap
    func fetchFocusSessionsByDay(from startDate: Date, to endDate: Date) throws -> [DayFocusData] {
        let sessions = try fetchFocusSessions(from: startDate, to: endDate)
        let calendar = Calendar.current

        // Group sessions by day
        var dayData: [Date: DayFocusData] = [:]

        for session in sessions {
            let day = calendar.startOfDay(for: session.startTime)

            if var existing = dayData[day] {
                existing.totalSeconds += Int(session.duration)
                existing.sessionCount += 1
                dayData[day] = existing
            } else {
                dayData[day] = DayFocusData(
                    date: day,
                    totalSeconds: Int(session.duration),
                    sessionCount: 1
                )
            }
        }

        // Fill in missing days with zero data
        var result: [DayFocusData] = []
        var currentDate = calendar.startOfDay(for: startDate)

        while currentDate < endDate {
            if let data = dayData[currentDate] {
                result.append(data)
            } else {
                result.append(DayFocusData(date: currentDate, totalSeconds: 0, sessionCount: 0))
            }
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        return result
    }

    /// Fetch focus rankings by task
    func fetchFocusRankings(from startDate: Date? = nil, to endDate: Date? = nil) throws -> [TaskFocusRanking] {
        let request = FocusSessionEntity.fetchRequest()

        if let start = startDate, let end = endDate {
            request.predicate = NSPredicate(
                format: "startTime >= %@ AND startTime < %@ AND completed == YES",
                start as NSDate,
                end as NSDate
            )
        } else {
            request.predicate = NSPredicate(format: "completed == YES")
        }

        let sessions = try viewContext.fetch(request)

        // Group by task
        var taskTotals: [UUID: (title: String, listName: String?, seconds: Int, count: Int)] = [:]

        for session in sessions {
            let taskId = session.task.id
            let existing = taskTotals[taskId]

            if let existing = existing {
                taskTotals[taskId] = (
                    title: existing.title,
                    listName: existing.listName,
                    seconds: existing.seconds + Int(session.duration),
                    count: existing.count + 1
                )
            } else {
                taskTotals[taskId] = (
                    title: session.task.title,
                    listName: session.task.taskList?.name,
                    seconds: Int(session.duration),
                    count: 1
                )
            }
        }

        // Convert to rankings and sort by duration
        return taskTotals.map { (id, data) in
            TaskFocusRanking(
                id: id,
                taskTitle: data.title,
                taskListName: data.listName,
                totalSeconds: data.seconds,
                sessionCount: data.count
            )
        }
        .sorted { $0.totalSeconds > $1.totalSeconds }
    }

    /// Calculate focus statistics
    func calculateFocusStatistics() throws -> FocusStatistics {
        var stats = FocusStatistics()

        // Today's stats
        let todaySessions = try fetchTodaysFocusSessions()
        stats.todaysPomoCount = todaySessions.count
        stats.todaysFocusSeconds = todaySessions.reduce(0) { $0 + Int($1.duration) }

        // Yesterday's stats
        let yesterdaySessions = try fetchYesterdaysFocusSessions()
        stats.yesterdaysPomoCount = yesterdaySessions.count
        stats.yesterdaysFocusSeconds = yesterdaySessions.reduce(0) { $0 + Int($1.duration) }

        // Total stats
        let allSessions = try fetchAllFocusSessions()
        stats.totalPomoCount = allSessions.count
        stats.totalFocusSeconds = allSessions.reduce(0) { $0 + Int($1.duration) }

        return stats
    }

    // MARK: - Goal Operations

    /// Create a new goal
    @discardableResult
    func createGoal(
        name: String,
        notes: String? = nil,
        targetDate: Date? = nil,
        colorHex: String? = nil,
        iconName: String? = nil
    ) throws -> GoalEntity {
        let goal = GoalEntity(context: viewContext)
        goal.id = UUID()
        goal.name = name
        goal.notes = notes
        goal.targetDate = targetDate
        goal.status = GoalStatus.active.rawValue
        goal.colorHex = colorHex ?? Constants.Colors.defaultListColor
        goal.iconName = iconName ?? "target"
        goal.createdAt = Date()

        // Set sort order
        let existingGoals = try fetchAllGoals()
        goal.sortOrder = Int16(existingGoals.count)

        try persistenceController.save(context: viewContext)
        return goal
    }

    /// Update an existing goal
    func updateGoal(
        _ goal: GoalEntity,
        name: String? = nil,
        notes: String? = nil,
        targetDate: Date? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        status: GoalStatus? = nil
    ) throws {
        if let name = name {
            goal.name = name
        }
        if let notes = notes {
            goal.notes = notes
        }
        if let targetDate = targetDate {
            goal.targetDate = targetDate
        }
        if let colorHex = colorHex {
            goal.colorHex = colorHex
        }
        if let iconName = iconName {
            goal.iconName = iconName
        }
        if let status = status {
            goal.status = status.rawValue
            if status == .completed {
                goal.completedAt = Date()
            }
        }

        try persistenceController.save(context: viewContext)
    }

    /// Delete a goal
    func deleteGoal(_ goal: GoalEntity) throws {
        viewContext.delete(goal)
        try persistenceController.save(context: viewContext)
    }

    /// Fetch all goals
    func fetchAllGoals(includeArchived: Bool = false) throws -> [GoalEntity] {
        let fetchRequest: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()

        if !includeArchived {
            fetchRequest.predicate = NSPredicate(
                format: "status != %@ AND status != %@",
                GoalStatus.completed.rawValue,
                GoalStatus.abandoned.rawValue
            )
        }

        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \GoalEntity.sortOrder, ascending: true)
        ]
        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch goals by status
    func fetchGoals(status: GoalStatus) throws -> [GoalEntity] {
        let fetchRequest: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "status == %@", status.rawValue)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \GoalEntity.sortOrder, ascending: true)
        ]
        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch a goal by ID
    func fetchGoalById(_ id: UUID) throws -> GoalEntity? {
        let fetchRequest: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        return try viewContext.fetch(fetchRequest).first
    }

    /// Link a task to a goal
    func linkTaskToGoal(task: TaskEntity, goal: GoalEntity) throws {
        task.addToGoals(goal)
        try persistenceController.save(context: viewContext)
    }

    /// Unlink a task from a goal
    func unlinkTaskFromGoal(task: TaskEntity, goal: GoalEntity) throws {
        task.removeFromGoals(goal)
        try persistenceController.save(context: viewContext)
    }

    /// Link multiple tasks to a goal
    func linkTasksToGoal(tasks: [TaskEntity], goal: GoalEntity) throws {
        for task in tasks {
            task.addToGoals(goal)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Fetch tasks for a specific goal
    func fetchTasksForGoal(_ goal: GoalEntity) -> [TaskEntity] {
        return goal.linkedTasks
    }

    /// Mark goal as completed
    func completeGoal(_ goal: GoalEntity) throws {
        goal.status = GoalStatus.completed.rawValue
        goal.completedAt = Date()
        try persistenceController.save(context: viewContext)
    }

    /// Mark goal as abandoned
    func abandonGoal(_ goal: GoalEntity) throws {
        goal.status = GoalStatus.abandoned.rawValue
        try persistenceController.save(context: viewContext)
    }

    /// Reorder goals
    func reorderGoals(_ goals: [GoalEntity]) throws {
        for (index, goal) in goals.enumerated() {
            goal.sortOrder = Int16(index)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Get goal count
    func fetchGoalCount(activeOnly: Bool = true) throws -> Int {
        let fetchRequest: NSFetchRequest<GoalEntity> = GoalEntity.fetchRequest()
        if activeOnly {
            fetchRequest.predicate = NSPredicate(format: "status == %@", GoalStatus.active.rawValue)
        }
        return try viewContext.count(for: fetchRequest)
    }

    // MARK: - Tag Operations

    /// Create a new tag
    @discardableResult
    func createTag(name: String, colorHex: String? = nil) throws -> TagEntity {
        let tag = TagEntity(context: viewContext)
        tag.id = UUID()
        tag.name = name
        tag.colorHex = colorHex ?? Constants.Colors.defaultListColor
        tag.createdAt = Date()

        // Set sort order
        let existingTags = try fetchAllTags()
        tag.sortOrder = Int16(existingTags.count)

        try persistenceController.save(context: viewContext)
        return tag
    }

    /// Update an existing tag
    func updateTag(_ tag: TagEntity, name: String? = nil, colorHex: String? = nil) throws {
        if let name = name {
            tag.name = name
        }
        if let colorHex = colorHex {
            tag.colorHex = colorHex
        }
        try persistenceController.save(context: viewContext)
    }

    /// Delete a tag
    func deleteTag(_ tag: TagEntity) throws {
        viewContext.delete(tag)
        try persistenceController.save(context: viewContext)
    }

    /// Fetch all tags
    func fetchAllTags() throws -> [TagEntity] {
        let fetchRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \TagEntity.sortOrder, ascending: true)]
        return try viewContext.fetch(fetchRequest)
    }

    /// Fetch a tag by ID
    func fetchTagById(_ id: UUID) throws -> TagEntity? {
        let fetchRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1
        return try viewContext.fetch(fetchRequest).first
    }

    /// Fetch a tag by name
    func fetchTagByName(_ name: String) throws -> TagEntity? {
        let fetchRequest: NSFetchRequest<TagEntity> = TagEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "name ==[c] %@", name)
        fetchRequest.fetchLimit = 1
        return try viewContext.fetch(fetchRequest).first
    }

    /// Add a tag to a task
    func addTag(_ tag: TagEntity, to task: TaskEntity) throws {
        task.addToTags(tag)
        try persistenceController.save(context: viewContext)
    }

    /// Remove a tag from a task
    func removeTag(_ tag: TagEntity, from task: TaskEntity) throws {
        task.removeFromTags(tag)
        try persistenceController.save(context: viewContext)
    }

    /// Set tags for a task (replaces all existing tags)
    func setTags(_ tags: [TagEntity], for task: TaskEntity) throws {
        // Remove all existing tags
        if let existingTags = task.tags {
            task.removeFromTags(existingTags)
        }
        // Add new tags
        for tag in tags {
            task.addToTags(tag)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Fetch tasks with a specific tag
    func fetchTasks(withTag tag: TagEntity) throws -> [TaskEntity] {
        return tag.tasksArray
    }

    /// Reorder tags
    func reorderTags(_ tags: [TagEntity]) throws {
        for (index, tag) in tags.enumerated() {
            tag.sortOrder = Int16(index)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Bulk add tag to multiple tasks
    @discardableResult
    func addTagToTasks(_ tag: TagEntity, tasks: [TaskEntity]) throws -> Int {
        for task in tasks {
            task.addToTags(tag)
        }
        try persistenceController.save(context: viewContext)
        return tasks.count
    }

    /// Bulk remove tag from multiple tasks
    @discardableResult
    func removeTagFromTasks(_ tag: TagEntity, tasks: [TaskEntity]) throws -> Int {
        for task in tasks {
            task.removeFromTags(tag)
        }
        try persistenceController.save(context: viewContext)
        return tasks.count
    }

    // MARK: - Subtask Operations

    /// Create a new subtask for a task
    @discardableResult
    func createSubtask(title: String, for task: TaskEntity) throws -> SubtaskEntity {
        let subtask = SubtaskEntity(context: viewContext)
        subtask.id = UUID()
        subtask.title = title
        subtask.isCompleted = false
        subtask.createdAt = Date()
        subtask.parentTask = task

        // Set sort order
        let existingSubtasks = task.subtasksArray
        subtask.sortOrder = Int16(existingSubtasks.count)

        try persistenceController.save(context: viewContext)
        return subtask
    }

    /// Update a subtask title
    func updateSubtask(_ subtask: SubtaskEntity, title: String) throws {
        subtask.title = title
        try persistenceController.save(context: viewContext)
    }

    /// Toggle subtask completion
    func toggleSubtaskCompletion(_ subtask: SubtaskEntity) throws {
        subtask.isCompleted.toggle()
        subtask.completedAt = subtask.isCompleted ? Date() : nil
        try persistenceController.save(context: viewContext)
    }

    /// Delete a subtask
    func deleteSubtask(_ subtask: SubtaskEntity) throws {
        viewContext.delete(subtask)
        try persistenceController.save(context: viewContext)
    }

    /// Reorder subtasks for a task
    func reorderSubtasks(_ subtasks: [SubtaskEntity]) throws {
        for (index, subtask) in subtasks.enumerated() {
            subtask.sortOrder = Int16(index)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Complete all subtasks for a task
    func completeAllSubtasks(for task: TaskEntity) throws {
        for subtask in task.subtasksArray where !subtask.isCompleted {
            subtask.isCompleted = true
            subtask.completedAt = Date()
        }
        try persistenceController.save(context: viewContext)
    }

    /// Delete all subtasks for a task
    func deleteAllSubtasks(for task: TaskEntity) throws {
        for subtask in task.subtasksArray {
            viewContext.delete(subtask)
        }
        try persistenceController.save(context: viewContext)
    }

    /// Create multiple subtasks at once
    @discardableResult
    func createSubtasks(titles: [String], for task: TaskEntity) throws -> [SubtaskEntity] {
        var subtasks: [SubtaskEntity] = []
        let startOrder = Int16(task.subtasksArray.count)

        for (index, title) in titles.enumerated() {
            let subtask = SubtaskEntity(context: viewContext)
            subtask.id = UUID()
            subtask.title = title
            subtask.isCompleted = false
            subtask.createdAt = Date()
            subtask.parentTask = task
            subtask.sortOrder = startOrder + Int16(index)
            subtasks.append(subtask)
        }

        try persistenceController.save(context: viewContext)
        return subtasks
    }

    /// Convert a subtask to a standalone task
    @discardableResult
    func convertSubtaskToTask(_ subtask: SubtaskEntity) throws -> TaskEntity {
        let parentTask = subtask.parentTask

        // Create new task with subtask info
        let newTask = try createTask(
            title: subtask.title,
            dueDate: parentTask.dueDate,
            priority: parentTask.priority,
            list: parentTask.taskList
        )

        // Copy tags from parent
        if let parentTags = parentTask.tags as? Set<TagEntity> {
            for tag in parentTags {
                newTask.addToTags(tag)
            }
        }

        // Delete the subtask
        try deleteSubtask(subtask)

        return newTask
    }

    // MARK: - Bulk Operations

    /// Complete multiple tasks at once
    func completeTasks(_ tasks: [TaskEntity]) throws {
        for task in tasks {
            task.isCompleted = true
            task.completedAt = Date()
        }
        try persistenceController.save(context: viewContext)
    }

}

// MARK: - Errors
enum DataServiceError: LocalizedError {
    case maxListsReached
    case maxGoalsReached

    var errorDescription: String? {
        switch self {
        case .maxListsReached:
            return "Maximum number of lists (\(Constants.Limits.maxCustomLists)) reached"
        case .maxGoalsReached:
            return "Maximum number of goals reached"
        }
    }
}
