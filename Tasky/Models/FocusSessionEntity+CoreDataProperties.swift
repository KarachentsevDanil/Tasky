//
//  FocusSessionEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
internal import CoreData

extension FocusSessionEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<FocusSessionEntity> {
        return NSFetchRequest<FocusSessionEntity>(entityName: "FocusSessionEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var startTime: Date
    @NSManaged var duration: Int32
    @NSManaged var completed: Bool
    @NSManaged var task: TaskEntity

}

extension FocusSessionEntity: Identifiable {

}

// MARK: - Convenience Methods
extension FocusSessionEntity {

    /// Formatted duration
    var formattedDuration: String {
        let minutes = duration / 60
        return "\(minutes)m"
    }

    /// End time of the session
    var endTime: Date {
        return startTime.addingTimeInterval(TimeInterval(duration))
    }
}
