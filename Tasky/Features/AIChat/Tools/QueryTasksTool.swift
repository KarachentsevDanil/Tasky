//
//  QueryTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when query results are available
extension Notification.Name {
    static let aiQueryResults = Notification.Name("aiQueryResults")
}

/// Tool for querying tasks with natural language
struct QueryTasksTool: Tool {
    let name = "queryTasks"

    let description = "Search and query tasks. Triggers: show tasks, list tasks, what tasks, find tasks, how many tasks, search for."

    let dataService: DataService
    let contextService: ContextService

    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Query type")
        @Guide(.anyOf(["list", "count", "search", "status", "summary"]))
        let queryType: String?

        @Guide(description: "Filter criteria for the query")
        let filter: TaskFilter

        @Guide(description: "Maximum number of tasks to return")
        let limit: Int?

        @Guide(description: "Sort order")
        @Guide(.anyOf(["due_date", "priority", "created", "alphabetical"]))
        let sortBy: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("queryTasks")
        let result = try await executeQuery(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeQuery(arguments: Arguments) async throws -> String {
        let queryType = arguments.queryType ?? "list"
        let limit = min(arguments.limit ?? 10, 20)
        let sortBy = arguments.sortBy ?? "due_date"

        // Fetch tasks based on filter
        var tasks: [TaskEntity]
        do {
            tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
        } catch {
            return "Could not find tasks matching your criteria."
        }

        // Apply sorting
        tasks = sortTasks(tasks, by: sortBy)

        // Execute query based on type
        switch queryType {
        case "count":
            return formatCountResponse(tasks: tasks, filter: arguments.filter)
        case "search":
            return formatSearchResponse(tasks: tasks, filter: arguments.filter, limit: limit)
        case "status":
            return formatStatusResponse(tasks: tasks, filter: arguments.filter)
        case "summary":
            return formatSummaryResponse(tasks: tasks, filter: arguments.filter)
        default: // "list"
            return formatListResponse(tasks: tasks, filter: arguments.filter, limit: limit)
        }
    }

    // MARK: - Response Formatters

    private func formatCountResponse(tasks: [TaskEntity], filter: TaskFilter) -> String {
        let completed = tasks.filter { $0.isCompleted }.count
        let incomplete = tasks.filter { !$0.isCompleted }.count
        let total = tasks.count

        var response = "📊 **Task Count**\n\n"
        response += "• Total: \(total)\n"
        response += "• Incomplete: \(incomplete)\n"
        response += "• Completed: \(completed)\n"

        if let listName = filter.listName {
            response += "\n(Filtered by list: '\(listName)')"
        }
        if let keyword = filter.keyword {
            response += "\n(Matching: '\(keyword)')"
        }

        return response
    }

    @MainActor
    private func formatSearchResponse(tasks: [TaskEntity], filter: TaskFilter, limit: Int) -> String {
        let keyword = filter.keyword ?? filter.taskNames?.first ?? ""

        guard !tasks.isEmpty else {
            return "🔍 No tasks found matching '\(keyword)'."
        }

        let limitedTasks = Array(tasks.prefix(limit))
        var response = "🔍 **Search Results for '\(keyword)':** (\(tasks.count) found)\n\n"

        for task in limitedTasks {
            let status = task.isCompleted ? "✓" : "○"
            let priorityEmoji = AIToolHelpers.priorityEmoji(Int(task.priority))
            var details: [String] = []

            if let dueDate = task.dueDate {
                details.append("due \(AIToolHelpers.formatRelativeDate(dueDate))")
            }
            if let list = task.taskList {
                details.append("in \(list.name)")
            }

            let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"
            response += "\(status) \(task.title)\(detailStr) \(priorityEmoji)\n"
        }

        if tasks.count > limit {
            response += "\n...and \(tasks.count - limit) more"
        }

        return response
    }

    private func formatStatusResponse(tasks: [TaskEntity], filter: TaskFilter) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let overdue = tasks.filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else { return false }
            return dueDate < today
        }

        let dueToday = tasks.filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else { return false }
            return calendar.isDateInToday(dueDate)
        }

        let dueTomorrow = tasks.filter { task in
            guard !task.isCompleted, let dueDate = task.dueDate else { return false }
            return calendar.isDateInTomorrow(dueDate)
        }

        let completed = tasks.filter { $0.isCompleted }
        let noDueDate = tasks.filter { !$0.isCompleted && $0.dueDate == nil }

        var response = "📈 **Task Status**\n\n"

        if !overdue.isEmpty {
            response += "🔴 Overdue: \(overdue.count)\n"
            for task in overdue.prefix(3) {
                response += "   • \(task.title)\n"
            }
        }

        if !dueToday.isEmpty {
            response += "🟠 Due Today: \(dueToday.count)\n"
            for task in dueToday.prefix(3) {
                response += "   • \(task.title)\n"
            }
        }

        if !dueTomorrow.isEmpty {
            response += "🟡 Due Tomorrow: \(dueTomorrow.count)\n"
        }

        if !noDueDate.isEmpty {
            response += "⚪ No Due Date: \(noDueDate.count)\n"
        }

        response += "✅ Completed: \(completed.count)\n"

        return response
    }

    @MainActor
    private func formatSummaryResponse(tasks: [TaskEntity], filter: TaskFilter) -> String {
        let incomplete = tasks.filter { !$0.isCompleted }
        let completed = tasks.filter { $0.isCompleted }

        // Priority breakdown
        let highPriority = incomplete.filter { $0.priority >= 2 }.count
        let mediumPriority = incomplete.filter { $0.priority == 1 }.count
        let lowPriority = incomplete.filter { $0.priority == 0 }.count

        // Estimated time
        let totalEstimatedMinutes = incomplete.reduce(0) { $0 + Int($1.estimatedDuration) }

        // By list
        var byList: [String: Int] = [:]
        for task in incomplete {
            let listName = task.taskList?.name ?? "Inbox"
            byList[listName, default: 0] += 1
        }

        var response = "📋 **Task Summary**\n\n"

        response += "**Overview:**\n"
        response += "• \(incomplete.count) incomplete, \(completed.count) completed\n"
        if totalEstimatedMinutes > 0 {
            response += "• Estimated time: \(AIToolHelpers.formatDuration(totalEstimatedMinutes))\n"
        }

        response += "\n**By Priority:**\n"
        if highPriority > 0 { response += "• 🔴 High: \(highPriority)\n" }
        if mediumPriority > 0 { response += "• 🟠 Medium: \(mediumPriority)\n" }
        if lowPriority > 0 { response += "• ⚪ Normal: \(lowPriority)\n" }

        if byList.count > 1 {
            response += "\n**By List:**\n"
            for (list, count) in byList.sorted(by: { $0.value > $1.value }).prefix(5) {
                response += "• \(list): \(count)\n"
            }
        }

        return response
    }

    @MainActor
    private func formatListResponse(tasks: [TaskEntity], filter: TaskFilter, limit: Int) -> String {
        guard !tasks.isEmpty else {
            return "No tasks found matching your criteria."
        }

        let limitedTasks = Array(tasks.prefix(limit))
        var response = "📋 **Tasks** (\(tasks.count) total):\n\n"

        for task in limitedTasks {
            let status = task.isCompleted ? "✓" : "○"
            let priorityEmoji = AIToolHelpers.priorityEmoji(Int(task.priority))

            var details: [String] = []
            if let dueDate = task.dueDate {
                details.append(AIToolHelpers.formatRelativeDate(dueDate))
            }

            let detailStr = details.isEmpty ? "" : " - \(details.joined(separator: ", "))"
            response += "\(status) \(task.title)\(detailStr) \(priorityEmoji)\n"
        }

        if tasks.count > limit {
            response += "\n...and \(tasks.count - limit) more tasks"
        }

        // Post notification
        let taskIds = limitedTasks.map { $0.id }
        NotificationCenter.default.post(
            name: .aiQueryResults,
            object: nil,
            userInfo: [
                "taskIds": taskIds,
                "totalCount": tasks.count
            ]
        )

        return response
    }

    // MARK: - Sorting

    private func sortTasks(_ tasks: [TaskEntity], by sortBy: String) -> [TaskEntity] {
        switch sortBy {
        case "priority":
            return tasks.sorted { $0.priority > $1.priority }
        case "created":
            return tasks.sorted { $0.createdAt > $1.createdAt }
        case "alphabetical":
            return tasks.sorted { $0.title.lowercased() < $1.title.lowercased() }
        default: // "due_date"
            return tasks.sorted { task1, task2 in
                let date1 = task1.dueDate ?? Date.distantFuture
                let date2 = task2.dueDate ?? Date.distantFuture
                return date1 < date2
            }
        }
    }
}
