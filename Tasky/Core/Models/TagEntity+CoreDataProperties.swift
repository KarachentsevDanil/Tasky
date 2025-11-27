//
//  TagEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import Foundation
import SwiftUI
internal import CoreData

extension TagEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<TagEntity> {
        return NSFetchRequest<TagEntity>(entityName: "TagEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var name: String
    @NSManaged var colorHex: String?
    @NSManaged var sortOrder: Int16
    @NSManaged var createdAt: Date
    @NSManaged var tasks: NSSet?
}

extension TagEntity: Identifiable {
    // id property already declared above
}

// MARK: - Generated accessors for tasks
extension TagEntity {

    @objc(addTasksObject:)
    @NSManaged func addToTasks(_ value: TaskEntity)

    @objc(removeTasksObject:)
    @NSManaged func removeFromTasks(_ value: TaskEntity)

    @objc(addTasks:)
    @NSManaged func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged func removeFromTasks(_ values: NSSet)
}

// MARK: - Convenience Methods
extension TagEntity {

    /// Get the tag color
    var color: Color {
        guard let hex = colorHex else { return .blue }
        return Color(hex: hex) ?? .blue
    }

    /// Get tasks as array
    var tasksArray: [TaskEntity] {
        let set = tasks as? Set<TaskEntity> ?? []
        return set.sorted { ($0.createdAt) > ($1.createdAt) }
    }

    /// Get incomplete tasks count
    var incompleteTasksCount: Int {
        tasksArray.filter { !$0.isCompleted }.count
    }
}
