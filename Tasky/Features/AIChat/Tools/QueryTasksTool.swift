//
//  QueryTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for querying and listing tasks via LLM
struct QueryTasksTool: Tool {
    let name = "queryTasks"

    let description = "Query and list tasks. Triggers: what's due, show tasks, how many, list tasks, upcoming, overdue."

    // DataService instance for querying tasks
    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments for querying tasks
    @Generable
    struct Arguments {
        @Guide(description: "Filter type for task query")
        @Guide(.anyOf(["today", "tomorrow", "upcoming", "overdue", "inbox", "completed", "high_priority", "all"]))
        let filter: String

        @Guide(description: "Maximum number of tasks to return (default 10)")
        let limit: Int?

        @Guide(description: "Include completed tasks in results (default false)")
        let includeCompleted: Bool?
    }

    /// Implements the Tool protocol
    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = await executeQuery(arguments: arguments)
        return GeneratedContent(result)
    }

    /// Executes the query (runs on MainActor for Core Data access)
    @MainActor
    private func executeQuery(arguments: Arguments) async -> String {
        let limit = min(max(arguments.limit ?? 10, 1), 50) // Limit between 1-50
        let includeCompleted = arguments.includeCompleted ?? false

        var tasks: [TaskEntity] = []
        var filterDescription = ""

        do {
            switch arguments.filter.lowercased() {
            case "today":
                tasks = try fetchTasksDueToday()
                filterDescription = "due today"

            case "tomorrow":
                tasks = try fetchTasksDueTomorrow()
                filterDescription = "due tomorrow"

            case "upcoming":
                tasks = try fetchUpcomingTasks()
                filterDescription = "upcoming"

            case "overdue":
                tasks = try fetchOverdueTasks()
                filterDescription = "overdue"

            case "inbox":
                tasks = try fetchInboxTasks()
                filterDescription = "in inbox"

            case "completed":
                tasks = try fetchCompletedTasks()
                filterDescription = "completed"

            case "high_priority":
                tasks = try fetchHighPriorityTasks()
                filterDescription = "high priority"

            case "all":
                tasks = try dataService.fetchAllTasks()
                filterDescription = "total"

            case let filter where filter.hasPrefix("list:"):
                let listName = String(filter.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                tasks = try fetchTasksInList(named: listName)
                filterDescription = "in '\(listName)'"

            default:
                tasks = try dataService.fetchAllTasks()
                filterDescription = "total"
            }
        } catch {
            print("❌ QueryTasksTool error: \(error)")
            return "Sorry, I couldn't retrieve your tasks. Please try again."
        }

        // Filter completed tasks if needed
        if !includeCompleted && arguments.filter.lowercased() != "completed" {
            tasks = tasks.filter { !$0.isCompleted }
        }

        // Apply limit
        let totalCount = tasks.count
        let limitedTasks = Array(tasks.prefix(limit))

        // Format response
        if limitedTasks.isEmpty {
            return "No tasks \(filterDescription). You're all caught up!"
        }

        var response = "You have \(totalCount) task(s) \(filterDescription)"
        if totalCount > limit {
            response += " (showing first \(limit))"
        }
        response += ":\n\n"

        for (index, task) in limitedTasks.enumerated() {
            let priorityIndicator = task.priority > 1 ? " [!]" : ""
            let dueInfo = task.dueDate.map { " - due \(formatDate($0))" } ?? ""
            let listInfo = task.taskList.map { " (\($0.name))" } ?? ""
            let completedMark = task.isCompleted ? " [done]" : ""

            response += "\(index + 1). \(task.title)\(priorityIndicator)\(dueInfo)\(listInfo)\(completedMark)\n"
        }

        return response
    }

    // MARK: - Query Methods

    private func fetchTasksDueToday() throws -> [TaskEntity] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfDay && dueDate < endOfDay
        }.sorted { ($0.priority, $0.dueDate ?? .distantFuture) > ($1.priority, $1.dueDate ?? .distantFuture) }
    }

    private func fetchTasksDueTomorrow() throws -> [TaskEntity] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let dayAfter = calendar.date(byAdding: .day, value: 2, to: startOfToday) else {
            return []
        }

        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= tomorrow && dueDate < dayAfter
        }.sorted { ($0.priority, $0.dueDate ?? .distantFuture) > ($1.priority, $1.dueDate ?? .distantFuture) }
    }

    private func fetchUpcomingTasks() throws -> [TaskEntity] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let oneWeekLater = calendar.date(byAdding: .day, value: 7, to: startOfToday) else {
            return []
        }

        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate >= startOfToday && dueDate <= oneWeekLater && !task.isCompleted
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func fetchOverdueTasks() throws -> [TaskEntity] {
        let startOfToday = Calendar.current.startOfDay(for: Date())

        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return dueDate < startOfToday && !task.isCompleted
        }.sorted { ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture) }
    }

    private func fetchInboxTasks() throws -> [TaskEntity] {
        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { task in
            task.taskList == nil && !task.isCompleted
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private func fetchCompletedTasks() throws -> [TaskEntity] {
        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private func fetchHighPriorityTasks() throws -> [TaskEntity] {
        let allTasks = try dataService.fetchAllTasks()
        return allTasks.filter { $0.priority >= 2 && !$0.isCompleted }
            .sorted { ($0.priority, $0.dueDate ?? .distantFuture) > ($1.priority, $1.dueDate ?? .distantFuture) }
    }

    private func fetchTasksInList(named listName: String) throws -> [TaskEntity] {
        let allLists = try dataService.fetchAllTaskLists()
        let lowercasedName = listName.lowercased()

        // Find matching list
        guard let matchedList = allLists.first(where: { $0.name.lowercased() == lowercasedName })
                ?? allLists.first(where: { $0.name.lowercased().contains(lowercasedName) }) else {
            return []
        }

        return try dataService.fetchTasks(for: matchedList)
            .filter { !$0.isCompleted }
            .sorted { ($0.priority, $0.dueDate ?? .distantFuture) > ($1.priority, $1.dueDate ?? .distantFuture) }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
}
