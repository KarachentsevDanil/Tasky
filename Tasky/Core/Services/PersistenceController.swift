//
//  PersistenceController.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

internal import CoreData
import Foundation

/// Manages the Core Data stack and provides access to the managed object context
class PersistenceController {

    // MARK: - App Group

    /// App Group identifier for sharing data with widgets and extensions
    static let appGroupIdentifier = "group.LaktionovaSoftware.Tasky"

    /// Shared container URL for App Group
    static var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Store URL within the App Group container
    static var sharedStoreURL: URL? {
        sharedContainerURL?.appendingPathComponent("TaskTracker.sqlite")
    }

    // MARK: - Singleton
    static let shared = PersistenceController()

    // MARK: - Preview Instance
    /// Preview instance for SwiftUI previews with in-memory store
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        // Create sample data for previews
        do {
            // Create a sample list
            let sampleList = TaskListEntity(context: viewContext)
            sampleList.id = UUID()
            sampleList.name = "Work"
            sampleList.colorHex = "007AFF"
            sampleList.iconName = "briefcase.fill"
            sampleList.createdAt = Date()
            sampleList.sortOrder = 0

            // Create sample tasks
            for i in 0..<5 {
                let task = TaskEntity(context: viewContext)
                task.id = UUID()
                task.title = "Sample Task \(i + 1)"
                task.notes = "This is a sample task for preview"
                task.isCompleted = i % 2 == 0
                task.createdAt = Date().addingTimeInterval(TimeInterval(-i * 3600))
                task.priority = Int16(i % 4)

                if i < 3 {
                    task.dueDate = Calendar.current.date(byAdding: .day, value: i, to: Date())
                }

                if i == 0 || i == 1 {
                    task.taskList = sampleList
                }
            }

            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error creating preview data: \(nsError), \(nsError.userInfo)")
        }

        return controller
    }()

    // MARK: - Properties
    let container: NSPersistentContainer

    // MARK: - Initialization
    init(inMemory: Bool = false, useSharedContainer: Bool = true) {
        container = NSPersistentContainer(name: "TaskTracker")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else if useSharedContainer, let sharedURL = Self.sharedStoreURL {
            // Use App Group container for data sharing with widgets
            container.persistentStoreDescriptions.first?.url = sharedURL

            // Migrate data from old location if needed
            Self.migrateStoreIfNeeded(container: container, to: sharedURL)
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this error appropriately
                // For now, we'll use fatalError for development
                fatalError("Unresolved error loading persistent store: \(error), \(error.userInfo)")
            }
        }

        // Configure context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Data Migration

    /// Migrate store from old location to App Group container if needed
    private static func migrateStoreIfNeeded(container: NSPersistentContainer, to newURL: URL) {
        // Check if old store exists and new store doesn't
        guard let oldURL = container.persistentStoreDescriptions.first?.url,
              oldURL != newURL,
              FileManager.default.fileExists(atPath: oldURL.path),
              !FileManager.default.fileExists(atPath: newURL.path) else {
            return
        }

        // Perform migration
        do {
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: container.managedObjectModel)
            let oldStore = try coordinator.addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: oldURL
            )

            try coordinator.migratePersistentStore(
                oldStore,
                to: newURL,
                type: .sqlite
            )

            print("Successfully migrated Core Data store to App Group container")

            // Optionally remove old store files
            try? FileManager.default.removeItem(at: oldURL)
            try? FileManager.default.removeItem(at: oldURL.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            try? FileManager.default.removeItem(at: oldURL.deletingPathExtension().appendingPathExtension("sqlite-shm"))
        } catch {
            print("Failed to migrate Core Data store: \(error)")
        }
    }

    // MARK: - Context Management

    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Create a new background context for background operations
    func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }

    // MARK: - Save Context

    /// Save the view context if there are changes
    func saveContext() {
        let context = container.viewContext

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("Error saving context: \(nsError), \(nsError.userInfo)")
        }
    }

    /// Save a specific context
    func save(context: NSManagedObjectContext) throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    // MARK: - Batch Operations

    /// Delete all data (useful for testing/debugging)
    func deleteAllData() throws {
        let context = viewContext

        // Delete all tasks
        let taskFetchRequest: NSFetchRequest<NSFetchRequestResult> = TaskEntity.fetchRequest()
        let deleteTasksRequest = NSBatchDeleteRequest(fetchRequest: taskFetchRequest)
        try context.execute(deleteTasksRequest)

        // Delete all lists
        let listFetchRequest: NSFetchRequest<NSFetchRequestResult> = TaskListEntity.fetchRequest()
        let deleteListsRequest = NSBatchDeleteRequest(fetchRequest: listFetchRequest)
        try context.execute(deleteListsRequest)

        try context.save()
    }
}
