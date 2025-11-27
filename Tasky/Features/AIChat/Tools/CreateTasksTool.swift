//
//  CreateTasksTool.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when tasks are created via AI
extension Notification.Name {
    static let aiTasksCreated = Notification.Name("aiTasksCreated")
}

/// Tool for creating one or multiple tasks via LLM
struct CreateTasksTool: Tool {
    let name = "createTasks"

    let description = "Create new tasks. Triggers: add, create, remind me, new task, schedule, set reminder."

    // DataService instance for task creation
    let dataService: DataService
    let contextService: ContextService

    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    /// Arguments for creating tasks
    @Generable
    struct Arguments {
        @Guide(description: "List of tasks to create")
        let tasks: [TaskToCreate]

        @Generable
        struct TaskToCreate {
            // === CONTEXT PROPERTIES (generated first for better inference) ===

            @Guide(description: "The title of the task")
            let title: String

            @Guide(description: "Person related to this task (e.g., 'John', 'Sarah'). Extract from 'for John', 'with Sarah'.")
            let relatedPerson: String?

            @Guide(description: "Goal this contributes to (e.g., 'fitness', 'learning'). Extract if mentioned.")
            let relatedGoal: String?

            @Guide(description: "List/project name to assign task to")
            let listName: String?

            // === DEPENDENT PROPERTIES (use context above) ===

            @Guide(description: "Optional notes or description")
            let notes: String?

            @Guide(description: "Due date in ISO 8601 format")
            let dueDate: String?

            @Guide(description: "Scheduled start time in ISO 8601 format")
            let scheduledTime: String?

            @Guide(description: "Scheduled end time in ISO 8601 format")
            let scheduledEndTime: String?

            @Guide(description: "Priority level")
            @Guide(.anyOf(["none", "low", "medium", "high"]))
            let priority: String?

            @Guide(description: "Whether this is a recurring task")
            let isRecurring: Bool?

            @Guide(description: "Days of week for recurrence (1=Mon...7=Sun)")
            let recurrenceDays: [Int]?

            @Guide(description: "Estimated duration in minutes")
            let estimatedMinutes: Int?
        }
    }

    /// Implements the Tool protocol
    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("createTasks")
        let result = try await executeTasks(arguments: arguments)
        return GeneratedContent(result)
    }

    /// Executes the tool to create tasks (runs on MainActor for Core Data access)
    @MainActor
    private func executeTasks(arguments: Arguments) async throws -> String {
        var createdTitles: [String] = []
        var createdTasksInfo: [CreatedTaskInfo] = []
        var failedCount = 0
        var listNotFoundNames: [String] = []

        // Fetch all available lists once for matching
        let allLists = (try? dataService.fetchAllTaskLists()) ?? []

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

                // Find matching list by name
                var matchedList: TaskListEntity?
                if let listName = taskData.listName {
                    matchedList = findMatchingList(listName, from: allLists)
                    if matchedList == nil {
                        listNotFoundNames.append(listName)
                        print("⚠️ List '\(listName)' not found, task will go to Inbox")
                    } else {
                        print("📂 Matched list '\(listName)' -> '\(matchedList?.name ?? "unknown")'")
                    }
                }

                // Calculate estimated duration
                let estimatedDuration = Int16(min(max(taskData.estimatedMinutes ?? 0, 0), 480)) // Max 8 hours

                // Debug logging
                print("📅 CreateTasksTool - Parsing dates for '\(taskData.title)':")
                print("  - Raw dueDate string: \(taskData.dueDate ?? "nil")")
                print("  - Parsed dueDate: \(dueDate?.description ?? "nil")")
                print("  - Raw scheduledTime string: \(taskData.scheduledTime ?? "nil")")
                print("  - Parsed scheduledTime: \(scheduledTime?.description ?? "nil")")
                print("  - Raw scheduledEndTime string: \(taskData.scheduledEndTime ?? "nil")")
                print("  - Parsed scheduledEndTime: \(scheduledEndTime?.description ?? "nil")")
                print("  - List: \(matchedList?.name ?? "Inbox")")
                print("  - Estimated duration: \(estimatedDuration) min")

                // Parse priority from string
                let priority: Int16
                switch taskData.priority?.lowercased() {
                case "high": priority = 3
                case "medium": priority = 2
                case "low": priority = 1
                default: priority = 0  // "none" or nil
                }

                // Create the task
                let createdTask = try dataService.createTask(
                    title: taskData.title,
                    notes: taskData.notes,
                    dueDate: dueDate,
                    scheduledTime: scheduledTime,
                    scheduledEndTime: scheduledEndTime,
                    priority: priority,
                    list: matchedList,
                    isRecurring: taskData.isRecurring ?? false,
                    recurrenceDays: taskData.recurrenceDays,
                    estimatedDuration: estimatedDuration
                )

                createdTitles.append(taskData.title)

                // Build CreatedTaskInfo for preview
                let taskInfo = CreatedTaskInfo(
                    title: taskData.title,
                    dueDate: dueDate,
                    priority: Int(priority),
                    listName: matchedList?.name,
                    estimatedMinutes: Int(estimatedDuration),
                    taskEntityId: createdTask.id
                )
                createdTasksInfo.append(taskInfo)

                // Extract and reinforce context from task creation
                await extractContextFromTask(taskData, taskId: createdTask.id)

                print("✅ Successfully created task '\(taskData.title)' with dueDate: \(dueDate != nil), scheduledTime: \(scheduledTime != nil), scheduledEndTime: \(scheduledEndTime != nil)")
            } catch {
                failedCount += 1
                print("❌ Failed to create task '\(taskData.title)': \(error)")
            }
        }

        let createdCount = createdTitles.count
        let totalRequested = arguments.tasks.count

        // Format response message
        var response: String
        if createdCount == 0 {
            response = "Sorry, I couldn't create any tasks. Please try again."
        } else if createdCount == 1 {
            response = "✓ Created task: \"\(createdTitles[0])\""
        } else {
            let taskList = createdTitles.map { "• \($0)" }.joined(separator: "\n")
            let header = createdCount == totalRequested
                ? "✓ Created \(createdCount) tasks:"
                : "✓ Created \(createdCount) of \(totalRequested) tasks:"
            response = "\(header)\n\(taskList)"
        }

        // Add note about lists not found
        if !listNotFoundNames.isEmpty {
            let uniqueListNames = Array(Set(listNotFoundNames))
            if uniqueListNames.count == 1 {
                response += "\n\n(Note: List '\(uniqueListNames[0])' was not found, task added to Inbox)"
            } else {
                response += "\n\n(Note: Lists not found: \(uniqueListNames.joined(separator: ", ")); tasks added to Inbox)"
            }
        }

        // Post notification with created tasks info for preview
        if !createdTasksInfo.isEmpty {
            NotificationCenter.default.post(
                name: .aiTasksCreated,
                object: nil,
                userInfo: ["tasks": createdTasksInfo]
            )
        }

        return response
    }

    /// Find a matching list by name (case-insensitive, with fuzzy matching)
    @MainActor
    private func findMatchingList(_ name: String, from lists: [TaskListEntity]) -> TaskListEntity? {
        let lowercasedName = name.lowercased()

        // Exact match first
        if let exact = lists.first(where: { $0.name.lowercased() == lowercasedName }) {
            return exact
        }

        // Fuzzy match (contains)
        if let partial = lists.first(where: { $0.name.lowercased().contains(lowercasedName) }) {
            return partial
        }

        // Reverse fuzzy match (name contains list name)
        if let reverse = lists.first(where: { lowercasedName.contains($0.name.lowercased()) && !$0.name.isEmpty }) {
            return reverse
        }

        return nil
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

    // MARK: - Context Extraction

    /// Extract context from task creation and reinforce in ContextStore
    @MainActor
    private func extractContextFromTask(_ taskData: Arguments.TaskToCreate, taskId: UUID) async {
        // Extract and reinforce person context
        if let person = taskData.relatedPerson, !person.isEmpty {
            do {
                let metadata: [String: Any] = [
                    "lastMentionedTaskId": taskId.uuidString
                ]
                try contextService.saveContext(
                    category: .person,
                    key: person.lowercased(),
                    value: person,
                    source: .extracted,
                    metadata: metadata
                )
                print("🧠 ContextStore: Reinforced person '\(person)' from task creation")
            } catch {
                print("⚠️ Failed to save person context: \(error)")
            }
        }

        // Extract and reinforce goal context
        if let goal = taskData.relatedGoal, !goal.isEmpty {
            do {
                try contextService.saveContext(
                    category: .goal,
                    key: goal.lowercased(),
                    value: goal,
                    source: .extracted
                )
                print("🧠 ContextStore: Reinforced goal '\(goal)' from task creation")
            } catch {
                print("⚠️ Failed to save goal context: \(error)")
            }
        }

        // Extract list association as preference if applicable
        if let listName = taskData.listName, !listName.isEmpty {
            // Track list usage pattern
            do {
                try contextService.saveContext(
                    category: .preference,
                    key: "list_\(listName.lowercased())",
                    value: "Uses '\(listName)' list for tasks",
                    source: .inferred
                )
            } catch {
                print("⚠️ Failed to save list preference context: \(error)")
            }
        }
    }
}
