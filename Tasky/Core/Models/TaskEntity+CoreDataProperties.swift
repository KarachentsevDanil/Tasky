//
//  TaskEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import Foundation
internal import CoreData

extension TaskEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var title: String
    @NSManaged var notes: String?
    @NSManaged var isCompleted: Bool
    @NSManaged var dueDate: Date?
    @NSManaged var scheduledTime: Date?
    @NSManaged var scheduledEndTime: Date?
    @NSManaged var createdAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var priority: Int16
    @NSManaged var priorityOrder: Int16
    @NSManaged var focusTimeSeconds: Int32
    @NSManaged var aiPriorityScore: Double
    @NSManaged var estimatedDuration: Int16
    @NSManaged var isRecurring: Bool
    @NSManaged var recurrenceDays: String?
    @NSManaged var taskList: TaskListEntity?
    @NSManaged var focusSessions: NSSet?

}

extension TaskEntity: Identifiable {
    // The id property is already declared above as @NSManaged public var id: UUID
    // This conformance ensures SwiftUI recognizes TaskEntity as Identifiable
}

// MARK: - Generated accessors for focusSessions
extension TaskEntity {

    @objc(addFocusSessionsObject:)
    @NSManaged func addToFocusSessions(_ value: FocusSessionEntity)

    @objc(removeFocusSessionsObject:)
    @NSManaged func removeFromFocusSessions(_ value: FocusSessionEntity)

    @objc(addFocusSessions:)
    @NSManaged func addToFocusSessions(_ values: NSSet)

    @objc(removeFocusSessions:)
    @NSManaged func removeFromFocusSessions(_ values: NSSet)

}

// MARK: - Convenience Methods
extension TaskEntity {

    /// Check if task is due today
    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    /// Check if task is overdue
    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return !isCompleted && dueDate < Date() && !Calendar.current.isDateInToday(dueDate)
    }

    /// Check if task is upcoming (within next 7 days)
    var isUpcoming: Bool {
        guard let dueDate = dueDate else { return false }
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        return dueDate > Date() && dueDate <= nextWeek
    }

    /// Check if task is scheduled for today
    var isScheduledToday: Bool {
        guard let scheduledTime = scheduledTime else { return false }
        return Calendar.current.isDateInToday(scheduledTime)
    }

    /// Formatted due date string
    var formattedDueDate: String? {
        guard let dueDate = dueDate else { return nil }

        return AppDateFormatters.formatRelativeDate(dueDate)
    }

    /// Formatted scheduled time string (shows range if end time exists)
    var formattedScheduledTime: String? {
        guard let scheduledTime = scheduledTime else { return nil }

        if let endTime = scheduledEndTime {
            return AppDateFormatters.formatTimeRange(start: scheduledTime, end: endTime)
        } else {
            return AppDateFormatters.timeFormatter.string(from: scheduledTime)
        }
    }

    /// Formatted focus time
    var formattedFocusTime: String {
        let hours = focusTimeSeconds / 3600
        let minutes = (focusTimeSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    /// Get array of recurrence day numbers (1=Mon, 7=Sun)
    var recurrenceDayNumbers: [Int] {
        guard let days = recurrenceDays else { return [] }
        return days.split(separator: ",")
            .compactMap { Int($0) }
            .sorted()
    }

    /// Set recurrence days from array
    func setRecurrenceDays(_ days: [Int]) {
        if days.isEmpty {
            recurrenceDays = nil
        } else {
            recurrenceDays = days.sorted().map { String($0) }.joined(separator: ",")
        }
    }

    /// Get formatted recurrence description
    var recurrenceDescription: String? {
        guard isRecurring else { return nil }

        let dayNumbers = recurrenceDayNumbers
        if dayNumbers.isEmpty { return "Daily" }

        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let selectedDays = dayNumbers.compactMap { num -> String? in
            guard num >= 1 && num <= 7 else { return nil }
            return dayNames[num - 1]
        }

        if selectedDays.count == 7 {
            return "Every day"
        } else if selectedDays.count == 5 && !dayNumbers.contains(6) && !dayNumbers.contains(7) {
            return "Weekdays"
        } else if selectedDays.count == 2 && dayNumbers.contains(6) && dayNumbers.contains(7) {
            return "Weekends"
        } else {
            return selectedDays.joined(separator: ", ")
        }
    }

    /// Check if task should recur on a given date
    func shouldRecurOn(date: Date) -> Bool {
        guard isRecurring else { return false }

        let dayNumbers = recurrenceDayNumbers
        if dayNumbers.isEmpty { return true } // Daily recurrence

        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        // Convert Sunday=1, Monday=2, ... to Monday=1, Sunday=7
        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1

        return dayNumbers.contains(adjustedWeekday)
    }

    /// Check if task is a quick win (< 15 minutes)
    var isQuickWin: Bool {
        return estimatedDuration > 0 && estimatedDuration <= 15
    }

    /// Get staleness in days (how many days since created)
    var stalenessInDays: Int {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
        return max(0, days)
    }

    /// Formatted estimated duration
    var formattedEstimatedDuration: String? {
        guard estimatedDuration > 0 else { return nil }

        if estimatedDuration < 60 {
            return "\(estimatedDuration) min"
        } else {
            let hours = estimatedDuration / 60
            let minutes = estimatedDuration % 60
            if minutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(minutes)m"
            }
        }
    }
}
