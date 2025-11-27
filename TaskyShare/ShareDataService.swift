//
//  ShareDataService.swift
//  TaskyShare
//
//  Created by Claude Code on 27.11.2025.
//

import CoreData

/// Lightweight data service for Share Extension
/// Uses App Group container to share data with main app
final class ShareDataService {

    // MARK: - App Group Constants

    private static let appGroupIdentifier = "group.LaktionovaSoftware.Tasky"

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private static var storeURL: URL? {
        containerURL?.appendingPathComponent("TaskTracker.sqlite")
    }

    // MARK: - Core Data Stack

    private lazy var container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "TaskTracker")

        // Use App Group container URL
        if let storeURL = Self.storeURL {
            let storeDescription = NSPersistentStoreDescription(url: storeURL)
            container.persistentStoreDescriptions = [storeDescription]
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                print("ShareExtension: Failed to load Core Data store: \(error)")
            }
        }

        return container
    }()

    // MARK: - Task Creation

    /// Create a new task in the shared Core Data store
    func createTask(title: String, notes: String? = nil) throws {
        let context = container.viewContext

        // Create the task entity
        let task = NSEntityDescription.insertNewObject(forEntityName: "TaskEntity", into: context)

        task.setValue(UUID(), forKey: "id")
        task.setValue(title, forKey: "title")
        task.setValue(notes, forKey: "notes")
        task.setValue(false, forKey: "isCompleted")
        task.setValue(Date(), forKey: "createdAt")
        task.setValue(Int16(0), forKey: "priority")
        task.setValue(Int16(0), forKey: "priorityOrder")
        task.setValue(Int64(0), forKey: "focusTimeSeconds")
        task.setValue(Int16(0), forKey: "estimatedDuration")
        task.setValue(false, forKey: "isRecurring")
        task.setValue(Int16(0), forKey: "rescheduleCount")

        // Calculate initial AI priority score (basic calculation)
        task.setValue(Double(0), forKey: "aiPriorityScore")

        // Set due date to today by default (so it shows in Today view)
        task.setValue(Date(), forKey: "dueDate")

        try context.save()
    }
}
