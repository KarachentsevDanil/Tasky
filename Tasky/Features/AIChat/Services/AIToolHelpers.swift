//
//  AIToolHelpers.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation

/// Shared helper methods for AI tools - optimized for local LLM constraints
@MainActor
struct AIToolHelpers {

    // MARK: - Filter Resolution for Bulk Operations

    /// Resolve TaskFilter to TaskFilterCriteria for DataService queries
    static func resolveFilter(_ filter: TaskFilter, dataService: DataService) -> TaskFilterCriteria {
        var criteria = TaskFilterCriteria()

        // Explicit task names take highest priority - find their IDs
        if let names = filter.taskNames, !names.isEmpty {
            var taskIds: [UUID] = []
            for name in names {
                if let task = findTask(name, dataService: dataService) {
                    taskIds.append(task.id)
                }
            }
            if !taskIds.isEmpty {
                criteria.taskIds = taskIds
                return criteria // Explicit names override other filters
            }
        }

        // List filter
        if let listName = filter.listName {
            if let list = findList(listName, dataService: dataService) {
                criteria.listId = list.id
            }
        }

        // Status filter
        if let status = filter.status {
            switch status.lowercased() {
            case "overdue":
                criteria.isOverdue = true
                criteria.isCompleted = false
            case "today":
                criteria.isDueToday = true
                criteria.isCompleted = false
            case "tomorrow":
                criteria.isDueTomorrow = true
                criteria.isCompleted = false
            case "this_week":
                criteria.isDueThisWeek = true
                criteria.isCompleted = false
            case "completed":
                criteria.isCompleted = true
            case "incomplete":
                criteria.isCompleted = false
            case "all":
                break // No filter
            default:
                break
            }
        }

        // Priority filter
        if let priority = filter.priority {
            switch priority.lowercased() {
            case "high": criteria.priorityLevel = 2
            case "medium": criteria.priorityLevel = 1
            case "low": criteria.priorityLevel = 0
            default: break
            }
        }

        // Time range filter
        if let timeRange = filter.timeRange {
            switch timeRange.lowercased() {
            case "older_than_week":
                criteria.olderThanDays = 7
            case "older_than_month":
                criteria.olderThanDays = 30
            case "due_this_week":
                criteria.isDueThisWeek = true
            case "due_next_week":
                criteria.isDueNextWeek = true
            case "no_due_date":
                criteria.hasNoDueDate = true
            default:
                break
            }
        }

        // Keyword filter
        if let keyword = filter.keyword, !keyword.isEmpty {
            criteria.keyword = keyword
        }

        return criteria
    }

    /// Fetch tasks matching a TaskFilter
    static func fetchTasksMatching(_ filter: TaskFilter, dataService: DataService) throws -> [TaskEntity] {
        let criteria = resolveFilter(filter, dataService: dataService)
        return try dataService.fetchTasks(matching: criteria)
    }

    /// Find multiple tasks by names
    static func findTasks(_ names: [String], dataService: DataService) -> [TaskEntity] {
        return names.compactMap { findTask($0, dataService: dataService) }
    }

    /// Format duration in minutes to human readable string
    static func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        } else if minutes % 60 == 0 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }

    // MARK: - Task Finding

    /// Find a task by title with fuzzy matching
    /// Priority: incomplete tasks > exact match > prefix match > contains match > word match
    static func findTask(_ searchTitle: String, dataService: DataService) -> TaskEntity? {
        guard let allTasks = try? dataService.fetchAllTasks() else { return nil }
        let lowercased = searchTitle.lowercased().trimmingCharacters(in: .whitespaces)

        // Prefer incomplete tasks for operations
        let incomplete = allTasks.filter { !$0.isCompleted }
        let searchPool = incomplete.isEmpty ? allTasks : incomplete

        // 1. Exact match (highest confidence)
        if let exact = searchPool.first(where: { $0.title.lowercased() == lowercased }) {
            return exact
        }

        // 2. Starts with (high confidence)
        if let prefix = searchPool.first(where: { $0.title.lowercased().hasPrefix(lowercased) }) {
            return prefix
        }

        // 3. Contains (medium confidence)
        if let partial = searchPool.first(where: { $0.title.lowercased().contains(lowercased) }) {
            return partial
        }

        // 4. Word match (lower confidence but still useful)
        let searchWords = Set(lowercased.components(separatedBy: .whitespaces).filter { !$0.isEmpty })
        if let wordMatch = searchPool.first(where: { task in
            let title = task.title.lowercased()
            let titleWords = Set(title.components(separatedBy: .whitespaces))
            return !searchWords.isDisjoint(with: titleWords)
        }) {
            return wordMatch
        }

        return nil
    }

    /// Find similar tasks for suggestion when exact match fails
    static func findSimilarTasks(_ searchTitle: String, dataService: DataService) -> String {
        guard let allTasks = try? dataService.fetchAllTasks() else { return "" }
        let lowercased = searchTitle.lowercased()

        let searchWords = Set(lowercased.components(separatedBy: .whitespaces))
        let similar = allTasks
            .filter { !$0.isCompleted }
            .filter { task in
                let title = task.title.lowercased()
                let titleWords = Set(title.components(separatedBy: .whitespaces))
                return !searchWords.isDisjoint(with: titleWords) ||
                       title.contains(lowercased) ||
                       lowercased.contains(title)
            }
            .prefix(3)
            .map { $0.title }

        return similar.map { "- \($0)" }.joined(separator: "\n")
    }

    // MARK: - List Finding

    /// Find a list by name with fuzzy matching
    static func findList(_ name: String, dataService: DataService) -> TaskListEntity? {
        guard let lists = try? dataService.fetchAllTaskLists() else { return nil }
        let lowercased = name.lowercased()

        return lists.first(where: { $0.name.lowercased() == lowercased }) ??
               lists.first(where: { $0.name.lowercased().contains(lowercased) })
    }

    /// Get comma-separated list of available list names
    static func getAvailableListNames(dataService: DataService) -> String {
        guard let lists = try? dataService.fetchAllTaskLists() else { return "none" }
        if lists.isEmpty { return "none" }
        return lists.map { $0.name }.joined(separator: ", ")
    }

    // MARK: - Date Parsing (Optimized for Local LLM)

    /// Parse ISO 8601 date string with multiple format support
    static func parseISO8601Date(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        let formats: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime],
            [.withFullDate]
        ]

        for options in formats {
            formatter.formatOptions = options
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        return nil
    }

    /// Calculate new date from natural language shortcut
    /// Supports: today, tomorrow, next_week, next_month, weekday names, specific_date
    static func calculateNewDate(_ when: String, specificDate: String?) -> Date? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch when.lowercased() {
        case "today":
            return today
        case "tomorrow":
            return calendar.date(byAdding: .day, value: 1, to: today)
        case "next_week":
            return calendar.date(byAdding: .day, value: 7, to: today)
        case "next_month":
            return calendar.date(byAdding: .month, value: 1, to: today)
        case "specific_date":
            guard let dateString = specificDate else { return nil }
            return parseISO8601Date(dateString)
        default:
            return parseWeekday(when)
        }
    }

    /// Parse weekday name to next occurrence
    static func parseWeekday(_ day: String) -> Date? {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
                        "thursday": 5, "friday": 6, "saturday": 7]

        guard let targetWeekday = weekdays[day.lowercased()] else { return nil }

        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 { daysToAdd += 7 }

        return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: today))
    }

    /// Parse time string (HH:MM format) and apply to a date
    static func parseTime(_ timeString: String, onDate date: Date) -> Date? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        guard components.count >= 2 else { return nil }

        let hour = components[0]
        let minute = components[1]

        guard hour >= 0, hour < 24, minute >= 0, minute < 60 else { return nil }

        var dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = minute

        return Calendar.current.date(from: dateComponents)
    }

    // MARK: - Date Formatting

    /// Format date as relative string (today, tomorrow, etc.)
    static func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "today" }
        if calendar.isDateInTomorrow(date) { return "tomorrow" }
        if calendar.isDateInYesterday(date) { return "yesterday" }

        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    /// Format time as short string
    static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Priority Helpers

    /// Get priority name from value
    static func priorityName(_ priority: Int) -> String {
        switch priority {
        case 3: return "high"
        case 2: return "medium"
        case 1: return "low"
        default: return "none"
        }
    }

    /// Get priority emoji indicator
    static func priorityEmoji(_ priority: Int) -> String {
        switch priority {
        case 3: return "🔴"
        case 2: return "🟠"
        case 1: return "🟡"
        default: return ""
        }
    }
}

// MARK: - Stores previous task state for undo functionality
struct TaskPreviousState {
    let title: String?
    let notes: String?
    let dueDate: Date?
    let scheduledTime: Date?
    let scheduledEndTime: Date?
    let priority: Int16
    let listId: UUID?
}

// MARK: - Complete task info stored for undo restoration
struct DeletedTaskInfo {
    let id: UUID?
    let title: String
    let notes: String?
    let dueDate: Date?
    let scheduledTime: Date?
    let scheduledEndTime: Date?
    let priority: Int
    let listId: UUID?
    let listName: String?
    let isRecurring: Bool
    let recurrenceDays: String?
    let estimatedDuration: Int
}
