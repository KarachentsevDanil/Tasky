//
//  TaskWidgetProvider.swift
//  TaskyWidgets
//
//  Created by Claude Code on 27.11.2025.
//

import WidgetKit
import CoreData

/// Provides task data for Today Tasks widget
struct TodayTasksProvider: TimelineProvider {
    typealias Entry = TodayTasksEntry

    func placeholder(in context: Context) -> TodayTasksEntry {
        TodayTasksEntry(
            date: Date(),
            tasks: [
                WidgetTask(
                    id: UUID(),
                    title: "Sample Task",
                    isCompleted: false,
                    dueDate: Date(),
                    scheduledTime: nil,
                    priority: 1,
                    aiPriorityScore: 50,
                    listName: "Work",
                    listColorHex: "007AFF"
                )
            ],
            completedCount: 2,
            totalCount: 5
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TodayTasksEntry) -> Void) {
        let entry = fetchTodayTasks()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayTasksEntry>) -> Void) {
        let entry = fetchTodayTasks()

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchTodayTasks() -> TodayTasksEntry {
        let tasks = WidgetDataService.shared.fetchTodayTasks()
        let incompleteTasks = tasks.filter { !$0.isCompleted }
        let completedCount = tasks.filter { $0.isCompleted }.count

        return TodayTasksEntry(
            date: Date(),
            tasks: Array(incompleteTasks.prefix(5)),
            completedCount: completedCount,
            totalCount: tasks.count
        )
    }
}

/// Provides task data for Next Task widget
struct NextTaskProvider: TimelineProvider {
    typealias Entry = NextTaskEntry

    func placeholder(in context: Context) -> NextTaskEntry {
        NextTaskEntry(
            date: Date(),
            task: WidgetTask(
                id: UUID(),
                title: "Review project proposal",
                isCompleted: false,
                dueDate: Date(),
                scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()),
                priority: 2,
                aiPriorityScore: 85,
                listName: "Work",
                listColorHex: "007AFF"
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (NextTaskEntry) -> Void) {
        let entry = fetchNextTask()
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextTaskEntry>) -> Void) {
        let entry = fetchNextTask()

        // Refresh every 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }

    private func fetchNextTask() -> NextTaskEntry {
        let task = WidgetDataService.shared.fetchNextTask()
        return NextTaskEntry(date: Date(), task: task)
    }
}

// MARK: - Timeline Entries

struct TodayTasksEntry: TimelineEntry {
    let date: Date
    let tasks: [WidgetTask]
    let completedCount: Int
    let totalCount: Int

    var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

struct NextTaskEntry: TimelineEntry {
    let date: Date
    let task: WidgetTask?
}

// MARK: - Widget Data Service

/// Service for fetching task data in widget extension
final class WidgetDataService {
    static let shared = WidgetDataService()

    private lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TaskTracker")

        // Use App Group container
        if let storeURL = AppGroupConstants.storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
            container.persistentStoreDescriptions = [storeDescription]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Widget: Failed to load Core Data store: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    private init() {}

    func fetchTodayTasks() -> [WidgetTask] {
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        // Fetch tasks due today or scheduled today
        request.predicate = NSPredicate(
            format: "(dueDate >= %@ AND dueDate < %@) OR (scheduledTime >= %@ AND scheduledTime < %@)",
            startOfDay as NSDate,
            endOfDay as NSDate,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        request.sortDescriptors = [
            NSSortDescriptor(key: "isCompleted", ascending: true),
            NSSortDescriptor(key: "aiPriorityScore", ascending: false)
        ]

        do {
            let results = try context.fetch(request)
            return results.map { mapToWidgetTask($0) }
        } catch {
            print("Widget: Failed to fetch tasks: \(error)")
            return []
        }
    }

    func fetchNextTask() -> WidgetTask? {
        let context = container.viewContext
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskEntity")

        // Fetch highest priority incomplete task due today
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        request.predicate = NSPredicate(
            format: "isCompleted == NO AND ((dueDate >= %@ AND dueDate < %@) OR (scheduledTime >= %@ AND scheduledTime < %@))",
            startOfDay as NSDate,
            endOfDay as NSDate,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        request.sortDescriptors = [
            NSSortDescriptor(key: "aiPriorityScore", ascending: false),
            NSSortDescriptor(key: "scheduledTime", ascending: true)
        ]

        request.fetchLimit = 1

        do {
            if let result = try context.fetch(request).first {
                return mapToWidgetTask(result)
            }
        } catch {
            print("Widget: Failed to fetch next task: \(error)")
        }

        return nil
    }

    private func mapToWidgetTask(_ object: NSManagedObject) -> WidgetTask {
        let taskList = object.value(forKey: "taskList") as? NSManagedObject

        return WidgetTask(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            title: object.value(forKey: "title") as? String ?? "Untitled",
            isCompleted: object.value(forKey: "isCompleted") as? Bool ?? false,
            dueDate: object.value(forKey: "dueDate") as? Date,
            scheduledTime: object.value(forKey: "scheduledTime") as? Date,
            priority: Int(object.value(forKey: "priority") as? Int16 ?? 0),
            aiPriorityScore: object.value(forKey: "aiPriorityScore") as? Double ?? 0,
            listName: taskList?.value(forKey: "name") as? String,
            listColorHex: taskList?.value(forKey: "colorHex") as? String
        )
    }
}
