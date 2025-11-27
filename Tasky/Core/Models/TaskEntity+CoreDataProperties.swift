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
    @NSManaged var recurrenceType: String?
    @NSManaged var recurrenceInterval: Int16
    @NSManaged var recurrenceDayOfMonth: Int16
    @NSManaged var recurrenceWeekdayOrdinal: Int16
    @NSManaged var recurrenceEndDate: Date?
    @NSManaged var recurrenceCount: Int16
    @NSManaged var completedOccurrences: Int16
    @NSManaged var rescheduleCount: Int16
    @NSManaged var taskList: TaskListEntity?
    @NSManaged var focusSessions: NSSet?
    @NSManaged var goals: NSSet?
    @NSManaged var tags: NSSet?
    @NSManaged var subtasks: NSSet?

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

// MARK: - Generated accessors for goals
extension TaskEntity {

    @objc(addGoalsObject:)
    @NSManaged func addToGoals(_ value: GoalEntity)

    @objc(removeGoalsObject:)
    @NSManaged func removeFromGoals(_ value: GoalEntity)

    @objc(addGoals:)
    @NSManaged func addToGoals(_ values: NSSet)

    @objc(removeGoals:)
    @NSManaged func removeFromGoals(_ values: NSSet)

    /// Get linked goals as array
    var linkedGoals: [GoalEntity] {
        guard let goals = goals as? Set<GoalEntity> else { return [] }
        return Array(goals).sorted { $0.name < $1.name }
    }

    /// Check if task is linked to any goal
    var hasGoals: Bool {
        !linkedGoals.isEmpty
    }

}

// MARK: - Generated accessors for tags
extension TaskEntity {

    @objc(addTagsObject:)
    @NSManaged func addToTags(_ value: TagEntity)

    @objc(removeTagsObject:)
    @NSManaged func removeFromTags(_ value: TagEntity)

    @objc(addTags:)
    @NSManaged func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged func removeFromTags(_ values: NSSet)

    /// Get tags as sorted array
    var tagsArray: [TagEntity] {
        let set = tags as? Set<TagEntity> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Check if task has any tags
    var hasTags: Bool {
        !tagsArray.isEmpty
    }
}

// MARK: - Generated accessors for subtasks
extension TaskEntity {

    @objc(addSubtasksObject:)
    @NSManaged func addToSubtasks(_ value: SubtaskEntity)

    @objc(removeSubtasksObject:)
    @NSManaged func removeFromSubtasks(_ value: SubtaskEntity)

    @objc(addSubtasks:)
    @NSManaged func addToSubtasks(_ values: NSSet)

    @objc(removeSubtasks:)
    @NSManaged func removeFromSubtasks(_ values: NSSet)

    /// Get subtasks as sorted array
    var subtasksArray: [SubtaskEntity] {
        let set = subtasks as? Set<SubtaskEntity> ?? []
        return set.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Check if task has any subtasks
    var hasSubtasks: Bool {
        !subtasksArray.isEmpty
    }

    /// Get subtask progress as tuple (completed, total)
    var subtasksProgress: (completed: Int, total: Int) {
        let array = subtasksArray
        let completed = array.filter { $0.isCompleted }.count
        return (completed: completed, total: array.count)
    }

    /// Get formatted subtask progress string (e.g., "3/7")
    var subtasksProgressString: String? {
        let progress = subtasksProgress
        guard progress.total > 0 else { return nil }
        return "\(progress.completed)/\(progress.total)"
    }

    /// Check if all subtasks are completed
    var allSubtasksCompleted: Bool {
        let progress = subtasksProgress
        return progress.total > 0 && progress.completed == progress.total
    }

    /// Get subtask completion percentage (0.0 to 1.0)
    var subtasksCompletionPercentage: Double {
        let progress = subtasksProgress
        guard progress.total > 0 else { return 0 }
        return Double(progress.completed) / Double(progress.total)
    }
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

    /// Check if task is stuck (rescheduled 3+ times)
    var isStuck: Bool {
        return rescheduleCount >= 3 && !isCompleted
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
