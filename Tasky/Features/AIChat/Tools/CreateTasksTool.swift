//
//  CreateTasksTool.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import Foundation
import FoundationModels

/// Tool for creating one or multiple tasks via LLM
struct CreateTasksTool: Tool {
    let name = "create_tasks"

    let description = """
    Creates one or multiple tasks in the user's task list. Use this when the user wants to add new tasks, \
    schedule activities, or set reminders. You can create multiple tasks at once if the user mentions several things to do.
    """

    // DataService instance for task creation
    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments for creating tasks
    @Generable
    struct Arguments {
        @Guide(description: "List of tasks to create")
        let tasks: [TaskToCreate]

        @Generable
        struct TaskToCreate {
            @Guide(description: "The title of the task")
            let title: String

            @Guide(description: "Optional notes or description")
            let notes: String?

            @Guide(description: "Optional due date in ISO 8601 format")
            let dueDate: String?

            @Guide(description: "Optional scheduled start time in ISO 8601 format")
            let scheduledTime: String?

            @Guide(description: "Optional scheduled end time in ISO 8601 format")
            let scheduledEndTime: String?

            @Guide(description: "Priority level: 0 (none), 1 (low), 2 (medium), 3 (high)")
            let priority: Int?

            @Guide(description: "Whether this is a recurring task")
            let isRecurring: Bool?

            @Guide(description: "Days of week for recurrence (1=Mon, 2=Tue, ..., 7=Sun)")
            let recurrenceDays: [Int]?
        }
    }

    /// Implements the Tool protocol
    func call(arguments: Arguments) async throws -> GeneratedContent {
        let result = try await executeTasks(arguments: arguments)
        return GeneratedContent(result)
    }

    /// Executes the tool to create tasks
    private func executeTasks(arguments: Arguments) async throws -> String {
        var createdTitles: [String] = []
        var failedCount = 0

        for taskData in arguments.tasks {
            do {
                // Parse dates if provided, with fallback to today for dueDate
                var dueDate: Date?
                if let dueDateString = taskData.dueDate {
                    dueDate = parseISO8601DateAsDay(dueDateString)
                    if dueDate == nil {
                        print("⚠️ Failed to parse dueDate '\(dueDateString)', defaulting to today")
                        dueDate = Calendar.current.startOfDay(for: Date())
                    }
                } else {
                    // If no dueDate provided at all, default to today
                    dueDate = Calendar.current.startOfDay(for: Date())
                    print("📅 No dueDate provided, defaulting to today")
                }

                let scheduledTime = taskData.scheduledTime.flatMap { parseISO8601DateWithTime($0) }
                let scheduledEndTime = taskData.scheduledEndTime.flatMap { parseISO8601DateWithTime($0) }

                // Debug logging
                print("📅 CreateTasksTool - Parsing dates for '\(taskData.title)':")
                print("  - Raw dueDate string: \(taskData.dueDate ?? "nil")")
                print("  - Parsed dueDate: \(dueDate?.description ?? "nil")")
                print("  - Raw scheduledTime string: \(taskData.scheduledTime ?? "nil")")
                print("  - Parsed scheduledTime: \(scheduledTime?.description ?? "nil")")
                print("  - Raw scheduledEndTime string: \(taskData.scheduledEndTime ?? "nil")")
                print("  - Parsed scheduledEndTime: \(scheduledEndTime?.description ?? "nil")")

                // Validate priority
                let priority = Int16(min(max(taskData.priority ?? 0, 0), 3))

                // Create the task
                _ = try dataService.createTask(
                    title: taskData.title,
                    notes: taskData.notes,
                    dueDate: dueDate,
                    scheduledTime: scheduledTime,
                    scheduledEndTime: scheduledEndTime,
                    priority: priority,
                    list: nil,
                    isRecurring: taskData.isRecurring ?? false,
                    recurrenceDays: taskData.recurrenceDays
                )

                createdTitles.append(taskData.title)
                print("✅ Successfully created task '\(taskData.title)' with dueDate: \(dueDate != nil), scheduledTime: \(scheduledTime != nil), scheduledEndTime: \(scheduledEndTime != nil)")
            } catch {
                failedCount += 1
                print("❌ Failed to create task '\(taskData.title)': \(error)")
            }
        }

        let createdCount = createdTitles.count
        let totalRequested = arguments.tasks.count

        // Format response message
        if createdCount == 0 {
            return "Sorry, I couldn't create any tasks. Please try again."
        } else if createdCount == 1 {
            return "✓ Created task: \"\(createdTitles[0])\""
        } else {
            let taskList = createdTitles.map { "• \($0)" }.joined(separator: "\n")
            let header = createdCount == totalRequested
                ? "✓ Created \(createdCount) tasks:"
                : "✓ Created \(createdCount) of \(totalRequested) tasks:"
            return "\(header)\n\(taskList)"
        }
    }

    /// Parse ISO 8601 date string and normalize to start of day in user's local timezone
    /// Use this for dueDate to ensure consistent day-based filtering
    private func parseISO8601DateAsDay(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        // Try different ISO 8601 format variations
        let formatOptionsList: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],  // 2025-11-07T14:30:00.000Z
            [.withInternetDateTime],                          // 2025-11-07T14:30:00Z
            [.withFullDate, .withTime, .withColonSeparatorInTime], // 2025-11-07T14:30:00
            [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone], // 2025-11-07T14:30:00+00:00
            [.withFullDate]                                   // 2025-11-07 (date only)
        ]

        for options in formatOptionsList {
            formatter.formatOptions = options
            if let parsedDate = formatter.date(from: dateString) {
                // Normalize to start of day in user's local timezone
                let calendar = Calendar.current
                let components = calendar.dateComponents([.year, .month, .day], from: parsedDate)
                if let normalizedDate = calendar.date(from: components) {
                    print("📅 Parsed dueDate '\(dateString)' -> normalized to startOfDay: \(normalizedDate)")
                    return normalizedDate
                }
                return parsedDate
            }
        }

        // If all ISO 8601 parsing fails, log the issue
        print("⚠️ Could not parse dueDate string: '\(dateString)'")
        return nil
    }

    /// Parse ISO 8601 date string preserving the exact time
    /// Use this for scheduledTime to maintain specific appointment times
    private func parseISO8601DateWithTime(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()

        // Try different ISO 8601 format variations
        let formatOptionsList: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],  // 2025-11-07T14:30:00.000Z
            [.withInternetDateTime],                          // 2025-11-07T14:30:00Z
            [.withFullDate, .withTime, .withColonSeparatorInTime], // 2025-11-07T14:30:00
            [.withFullDate, .withTime, .withColonSeparatorInTime, .withTimeZone], // 2025-11-07T14:30:00+00:00
            [.withFullDate]                                   // 2025-11-07 (date only - will use midnight)
        ]

        for options in formatOptionsList {
            formatter.formatOptions = options
            if let parsedDate = formatter.date(from: dateString) {
                print("📅 Parsed scheduledTime '\(dateString)' -> \(parsedDate)")
                return parsedDate
            }
        }

        // If all ISO 8601 parsing fails, log the issue
        print("⚠️ Could not parse scheduledTime string: '\(dateString)'")
        return nil
    }
}
