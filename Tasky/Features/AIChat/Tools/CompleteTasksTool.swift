//
//  CompleteTasksTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for completing one or more tasks via filter or explicit names
struct CompleteTasksTool: Tool {
    let name = "completeTasks"
    let description = "Mark tasks as done. Triggers: done, finished, complete, check off, mark done, all done."

    let dataService: DataService
    let contextService: ContextService

    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Filter to select tasks. Can use list, status, keyword, or explicit taskNames.")
        let filter: TaskFilter

        @Guide(description: "true = mark complete, false = reopen/uncomplete. Default true.")
        let completed: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("completeTasks")
        let result = try await executeComplete(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeComplete(arguments: Arguments) async throws -> String {
        let completed = arguments.completed ?? true

        // Fetch tasks matching filter
        let tasks: [TaskEntity]
        do {
            tasks = try AIToolHelpers.fetchTasksMatching(arguments.filter, dataService: dataService)
        } catch {
            return "Could not find tasks matching your criteria."
        }

        // Filter to only tasks that need state change
        let tasksToChange = tasks.filter { $0.isCompleted != completed }

        guard !tasksToChange.isEmpty else {
            if tasks.isEmpty {
                return "No tasks found matching your criteria."
            } else {
                let action = completed ? "already complete" : "already incomplete"
                return tasks.count == 1
                    ? "'\(tasks[0].title)' is \(action)."
                    : "All \(tasks.count) matching tasks are \(action)."
            }
        }

        // Execute bulk complete
        do {
            let count = try dataService.completeTasks(tasksToChange, completed: completed)
            let taskTitles = tasksToChange.map { $0.title }
            let taskIds = tasksToChange.map { $0.id }

            // Post notification
            NotificationCenter.default.post(
                name: .aiBulkTasksCompleted,
                object: nil,
                userInfo: [
                    "taskIds": taskIds,
                    "taskTitles": taskTitles,
                    "completed": completed,
                    "count": count
                ]
            )

            // Haptic feedback
            HapticManager.shared.success()

            // Track completion patterns for context learning
            if completed {
                await trackCompletionPatterns(tasksToChange)
            }

            // Format response
            let action = completed ? "Completed" : "Reopened"
            if count == 1 {
                return "✓ \(action) '\(taskTitles[0])'"
            } else {
                let titles = taskTitles.prefix(3).joined(separator: ", ")
                let suffix = count > 3 ? " and \(count - 3) more" : ""
                return "✓ \(action) \(count) tasks: \(titles)\(suffix)"
            }
        } catch {
            HapticManager.shared.error()
            return "Failed to complete tasks. Please try again."
        }
    }

    // MARK: - Pattern Tracking

    /// Track task completion patterns for context learning
    @MainActor
    private func trackCompletionPatterns(_ tasks: [TaskEntity]) async {
        let now = Date()
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: now)
        let weekday = calendar.component(.weekday, from: now)

        // Track hourly completion pattern
        do {
            let hourKey = "completion_hour_\(hour)"
            if let existing = try contextService.fetchContext(category: .pattern, key: hourKey) {
                // Increment data points in metadata
                var metadata = existing.metadataDict ?? [:]
                let dataPoints = (metadata["dataPoints"] as? Int ?? 0) + tasks.count
                metadata["dataPoints"] = dataPoints
                metadata["lastObserved"] = ISO8601DateFormatter().string(from: now)
                existing.setMetadata(metadata)
                try contextService.reinforceContext(existing)
            } else {
                let metadata: [String: Any] = [
                    "patternType": "productivityPeak",
                    "dataPoints": tasks.count,
                    "lastObserved": ISO8601DateFormatter().string(from: now)
                ]
                try contextService.saveContext(
                    category: .pattern,
                    key: hourKey,
                    value: "Completes tasks around \(hour):00",
                    source: .inferred,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ Failed to track hourly completion pattern: \(error)")
        }

        // Track weekday completion pattern
        do {
            let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let dayKey = "completion_day_\(weekday)"
            if let existing = try contextService.fetchContext(category: .pattern, key: dayKey) {
                var metadata = existing.metadataDict ?? [:]
                let dataPoints = (metadata["dataPoints"] as? Int ?? 0) + tasks.count
                metadata["dataPoints"] = dataPoints
                metadata["lastObserved"] = ISO8601DateFormatter().string(from: now)
                existing.setMetadata(metadata)
                try contextService.reinforceContext(existing)
            } else {
                let metadata: [String: Any] = [
                    "patternType": "completionHabit",
                    "dataPoints": tasks.count,
                    "lastObserved": ISO8601DateFormatter().string(from: now)
                ]
                try contextService.saveContext(
                    category: .pattern,
                    key: dayKey,
                    value: "Active on \(weekdayNames[weekday])s",
                    source: .inferred,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ Failed to track weekday completion pattern: \(error)")
        }

        print("🧠 ContextStore: Tracked completion patterns for \(tasks.count) task(s)")
    }
}
