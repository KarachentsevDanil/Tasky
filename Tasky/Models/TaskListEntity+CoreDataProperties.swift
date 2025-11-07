//
//  TaskListEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
internal import CoreData
import SwiftUI

extension TaskListEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskListEntity> {
        return NSFetchRequest<TaskListEntity>(entityName: "TaskListEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var name: String
    @NSManaged var colorHex: String?
    @NSManaged var iconName: String?
    @NSManaged var createdAt: Date
    @NSManaged var sortOrder: Int16
    @NSManaged var tasks: NSSet?

}

// MARK: - Generated accessors for tasks
extension TaskListEntity {

    @objc(addTasksObject:)
    @NSManaged func addToTasks(_ value: TaskEntity)

    @objc(removeTasksObject:)
    @NSManaged func removeFromTasks(_ value: TaskEntity)

    @objc(addTasks:)
    @NSManaged func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged func removeFromTasks(_ values: NSSet)

}

extension TaskListEntity: Identifiable {

}

// MARK: - Convenience Methods
extension TaskListEntity {

    /// Get tasks as an array
    var tasksArray: [TaskEntity] {
        let set = tasks as? Set<TaskEntity> ?? []
        return set.sorted { $0.createdAt > $1.createdAt }
    }

    /// Get incomplete tasks count
    var incompleteTasksCount: Int {
        tasksArray.filter { !$0.isCompleted }.count
    }

    /// Get color from hex string
    var color: Color {
        guard let hexString = colorHex else { return .blue }
        return Color(hex: hexString) ?? .blue
    }
}
