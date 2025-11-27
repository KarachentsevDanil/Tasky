//
//  SubtaskEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import Foundation
internal import CoreData

extension SubtaskEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<SubtaskEntity> {
        return NSFetchRequest<SubtaskEntity>(entityName: "SubtaskEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var title: String
    @NSManaged var isCompleted: Bool
    @NSManaged var sortOrder: Int16
    @NSManaged var createdAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var parentTask: TaskEntity
}

extension SubtaskEntity: Identifiable {
    // id property already declared above
}
