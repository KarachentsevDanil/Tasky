//
//  TaskFilter.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Shared filter system for bulk AI tool operations
/// Designed for local LLM with explicit, parseable options
@Generable
struct TaskFilter {
    @Guide(description: "Filter by list name. Example: 'Shopping', 'Work'")
    let listName: String?

    @Guide(description: "Filter by status")
    @Guide(.anyOf(["overdue", "today", "tomorrow", "this_week", "completed", "incomplete", "all"]))
    let status: String?

    @Guide(description: "Filter by priority")
    @Guide(.anyOf(["high", "medium", "low", "any"]))
    let priority: String?

    @Guide(description: "Filter by time range")
    @Guide(.anyOf(["older_than_week", "older_than_month", "due_this_week", "due_next_week", "no_due_date"]))
    let timeRange: String?

    @Guide(description: "Filter by keyword in title")
    let keyword: String?

    @Guide(description: "Explicit task titles. Use when user mentions specific tasks by name.")
    let taskNames: [String]?
}

/// Internal filter criteria for DataService queries
/// Converts TaskFilter into Core Data predicates
struct TaskFilterCriteria {
    var listId: UUID?
    var isCompleted: Bool?
    var isOverdue: Bool = false
    var isDueToday: Bool = false
    var isDueTomorrow: Bool = false
    var isDueThisWeek: Bool = false
    var isDueNextWeek: Bool = false
    var priorityLevel: Int16?
    var keyword: String?
    var taskIds: [UUID]?
    var olderThanDays: Int?
    var hasNoDueDate: Bool = false

    /// Build NSPredicate from filter criteria
    func buildPredicate() -> NSPredicate {
        var predicates: [NSPredicate] = []
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        // Explicit task IDs take highest priority
        if let ids = taskIds, !ids.isEmpty {
            predicates.append(NSPredicate(format: "id IN %@", ids))
            return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        // List filter
        if let listId = listId {
            predicates.append(NSPredicate(format: "taskList.id == %@", listId as CVarArg))
        }

        // Completion status
        if let isCompleted = isCompleted {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: isCompleted)))
        }

        // Overdue tasks
        if isOverdue {
            predicates.append(NSPredicate(format: "dueDate < %@ AND isCompleted == NO", startOfToday as NSDate))
        }

        // Due today
        if isDueToday {
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            predicates.append(NSPredicate(format: "(dueDate >= %@ AND dueDate < %@) OR (scheduledTime >= %@ AND scheduledTime < %@)",
                                          startOfToday as NSDate, endOfToday as NSDate,
                                          startOfToday as NSDate, endOfToday as NSDate))
        }

        // Due tomorrow
        if isDueTomorrow {
            let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!
            let endOfTomorrow = calendar.date(byAdding: .day, value: 2, to: startOfToday)!
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@",
                                          startOfTomorrow as NSDate, endOfTomorrow as NSDate))
        }

        // Due this week
        if isDueThisWeek {
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@",
                                          startOfToday as NSDate, endOfWeek as NSDate))
        }

        // Due next week
        if isDueNextWeek {
            let startOfNextWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)!
            let endOfNextWeek = calendar.date(byAdding: .day, value: 14, to: startOfToday)!
            predicates.append(NSPredicate(format: "dueDate >= %@ AND dueDate < %@",
                                          startOfNextWeek as NSDate, endOfNextWeek as NSDate))
        }

        // Priority filter
        if let priority = priorityLevel {
            predicates.append(NSPredicate(format: "priority >= %d", priority))
        }

        // Keyword search
        if let keyword = keyword, !keyword.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", keyword))
        }

        // No due date
        if hasNoDueDate {
            predicates.append(NSPredicate(format: "dueDate == nil"))
        }

        // Older than X days
        if let days = olderThanDays {
            let cutoffDate = calendar.date(byAdding: .day, value: -days, to: now)!
            predicates.append(NSPredicate(format: "createdAt < %@", cutoffDate as NSDate))
        }

        return predicates.isEmpty
            ? NSPredicate(value: true)
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
