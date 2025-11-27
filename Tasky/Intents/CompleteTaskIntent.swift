//
//  CompleteTaskIntent.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import AppIntents

/// App Intent for completing a task by name via Siri or Shortcuts
@available(iOS 16.0, *)
struct CompleteTaskIntent: AppIntent {

    static var title: LocalizedStringResource = "Complete Task"

    static var description = IntentDescription("Mark a task as complete in Tasky")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Task Name", description: "The name of the task to complete")
    var taskName: String

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dataService = DataService()

        // Fetch all incomplete tasks
        let allTasks = (try? dataService.fetchAllTasks()) ?? []
        let incompleteTasks = allTasks.filter { !$0.isCompleted }

        // Find matching task using fuzzy matching
        guard let matchedTask = findMatchingTask(query: taskName, in: incompleteTasks) else {
            return .result(dialog: "I couldn't find a task matching '\(taskName)'")
        }

        do {
            try dataService.toggleTaskCompletion(matchedTask)

            // Donate completion for Siri suggestions
            IntentDonationManager.donateCompleteTask(title: matchedTask.title)

            return .result(dialog: "Marked '\(matchedTask.title)' as complete!")
        } catch {
            throw IntentError.completionFailed
        }
    }

    // MARK: - Fuzzy Matching

    private func findMatchingTask(query: String, in tasks: [TaskEntity]) -> TaskEntity? {
        let normalizedQuery = query.lowercased()

        // Priority 1: Exact match
        if let exact = tasks.first(where: { $0.title.lowercased() == normalizedQuery }) {
            return exact
        }

        // Priority 2: Starts with query
        if let prefix = tasks.first(where: { $0.title.lowercased().hasPrefix(normalizedQuery) }) {
            return prefix
        }

        // Priority 3: Contains query
        if let contains = tasks.first(where: { $0.title.lowercased().contains(normalizedQuery) }) {
            return contains
        }

        // Priority 4: Word match (any word in query matches any word in title)
        let queryWords = normalizedQuery.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        for task in tasks {
            let titleWords = task.title.lowercased().components(separatedBy: .whitespaces)
            if queryWords.contains(where: { queryWord in
                titleWords.contains(where: { $0.hasPrefix(queryWord) })
            }) {
                return task
            }
        }

        return nil
    }
}
