//
//  CleanupTool.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import Foundation
import FoundationModels

/// Tool for smart task cleanup with preview mode
struct CleanupTool: Tool {
    let name = "cleanup"
    let description = "Smart task cleanup. Triggers: clean up, tidy, organize tasks, clear old, archive, fix overdue."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Cleanup action to perform")
        @Guide(.anyOf(["reschedule_overdue", "archive_completed", "delete_old_completed", "full_cleanup"]))
        let action: String

        @Guide(description: "Preview only - show what would happen without making changes. Default true.")
        let preview: Bool?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("cleanup")
        let result = try await executeCleanup(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeCleanup(arguments: Arguments) async throws -> String {
        let preview = arguments.preview ?? true

        switch arguments.action.lowercased() {
        case "reschedule_overdue":
            return try await rescheduleOverdue(preview: preview)

        case "archive_completed":
            return try await archiveCompleted(preview: preview)

        case "delete_old_completed":
            return try await deleteOldCompleted(preview: preview)

        case "full_cleanup":
            return try await fullCleanup(preview: preview)

        default:
            return "Unknown action. Try: reschedule_overdue, archive_completed, delete_old_completed, or full_cleanup."
        }
    }

    // MARK: - Cleanup Actions

    @MainActor
    private func rescheduleOverdue(preview: Bool) async throws -> String {
        let overdueTasks = try dataService.fetchOverdueTasks()

        guard !overdueTasks.isEmpty else {
            return "No overdue tasks found. You're all caught up!"
        }

        let count = overdueTasks.count
        let titles = overdueTasks.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        let suffix = count > 5 ? "\n• ...and \(count - 5) more" : ""

        if preview {
            return "Would reschedule \(count) overdue tasks to today:\n\(titles)\(suffix)\n\nSay \"do it\" to proceed."
        }

        // Execute reschedule
        let today = Calendar.current.startOfDay(for: Date())
        try dataService.rescheduleTasks(overdueTasks, to: today)

        // Post notification
        NotificationCenter.default.post(
            name: .aiCleanupCompleted,
            object: nil,
            userInfo: [
                "action": "reschedule_overdue",
                "preview": false,
                "affectedCount": count,
                "message": "Rescheduled \(count) tasks to today"
            ]
        )

        HapticManager.shared.success()
        return "✓ Rescheduled \(count) overdue tasks to today."
    }

    @MainActor
    private func archiveCompleted(preview: Bool) async throws -> String {
        // Archive = delete completed tasks older than 7 days
        let oldCompleted = try dataService.fetchTasksOlderThan(days: 7, completedOnly: true)

        guard !oldCompleted.isEmpty else {
            return "No old completed tasks to archive (tasks completed more than 7 days ago)."
        }

        let count = oldCompleted.count
        let titles = oldCompleted.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        let suffix = count > 5 ? "\n• ...and \(count - 5) more" : ""

        if preview {
            return "Would archive (delete) \(count) completed tasks older than 7 days:\n\(titles)\(suffix)\n\nSay \"do it\" to proceed."
        }

        // Execute archive (delete)
        try dataService.deleteTasks(oldCompleted)

        NotificationCenter.default.post(
            name: .aiCleanupCompleted,
            object: nil,
            userInfo: [
                "action": "archive_completed",
                "preview": false,
                "affectedCount": count,
                "message": "Archived \(count) old completed tasks"
            ]
        )

        HapticManager.shared.success()
        return "✓ Archived \(count) completed tasks older than 7 days."
    }

    @MainActor
    private func deleteOldCompleted(preview: Bool) async throws -> String {
        // Delete completed tasks older than 30 days
        let oldCompleted = try dataService.fetchTasksOlderThan(days: 30, completedOnly: true)

        guard !oldCompleted.isEmpty else {
            return "No completed tasks older than 30 days to delete."
        }

        let count = oldCompleted.count
        let titles = oldCompleted.prefix(5).map { "• \($0.title)" }.joined(separator: "\n")
        let suffix = count > 5 ? "\n• ...and \(count - 5) more" : ""

        if preview {
            return "Would delete \(count) completed tasks older than 30 days:\n\(titles)\(suffix)\n\nSay \"do it\" to proceed."
        }

        try dataService.deleteTasks(oldCompleted)

        NotificationCenter.default.post(
            name: .aiCleanupCompleted,
            object: nil,
            userInfo: [
                "action": "delete_old_completed",
                "preview": false,
                "affectedCount": count,
                "message": "Deleted \(count) old completed tasks"
            ]
        )

        HapticManager.shared.success()
        return "✓ Deleted \(count) completed tasks older than 30 days."
    }

    @MainActor
    private func fullCleanup(preview: Bool) async throws -> String {
        // Combine all cleanup actions
        let overdueTasks = try dataService.fetchOverdueTasks()
        let oldCompleted = try dataService.fetchTasksOlderThan(days: 7, completedOnly: true)

        let overdueCount = overdueTasks.count
        let archivedCount = oldCompleted.count

        if overdueCount == 0 && archivedCount == 0 {
            return "Nothing to clean up! Your tasks are well organized."
        }

        var summary = "Full cleanup summary:\n"

        if overdueCount > 0 {
            summary += "• \(overdueCount) overdue tasks → reschedule to today\n"
        }
        if archivedCount > 0 {
            summary += "• \(archivedCount) old completed tasks → archive\n"
        }

        if preview {
            summary += "\nSay \"do it\" to proceed with full cleanup."
            return summary
        }

        // Execute cleanup
        var actionsCompleted: [String] = []

        if overdueCount > 0 {
            let today = Calendar.current.startOfDay(for: Date())
            try dataService.rescheduleTasks(overdueTasks, to: today)
            actionsCompleted.append("rescheduled \(overdueCount) overdue")
        }

        if archivedCount > 0 {
            try dataService.deleteTasks(oldCompleted)
            actionsCompleted.append("archived \(archivedCount) old completed")
        }

        NotificationCenter.default.post(
            name: .aiCleanupCompleted,
            object: nil,
            userInfo: [
                "action": "full_cleanup",
                "preview": false,
                "affectedCount": overdueCount + archivedCount,
                "message": actionsCompleted.joined(separator: ", ")
            ]
        )

        HapticManager.shared.success()
        return "✓ Cleanup complete: " + actionsCompleted.joined(separator: ", ")
    }
}
