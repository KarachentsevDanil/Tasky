//
//  SuggestBreakdownTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when breakdown suggestions are generated
extension Notification.Name {
    static let aiBreakdownSuggested = Notification.Name("aiBreakdownSuggested")
}

/// Tool for breaking down complex tasks into smaller subtasks
struct SuggestBreakdownTool: Tool {
    let name = "suggestBreakdown"

    let description = "Break down a complex task into smaller, actionable subtasks. Triggers: break down, split task, subtasks for, how do I do, steps for."

    let dataService: DataService
    let contextService: ContextService

    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "The task name to break down, or description of what needs to be done")
        let taskName: String

        @Guide(description: "Number of subtasks to suggest (3-7 recommended)")
        let numberOfSteps: Int?

        @Guide(description: "Whether to create the subtasks immediately")
        let createSubtasks: Bool?

        @Guide(description: "Target list for created subtasks")
        let listName: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("suggestBreakdown")
        let result = try await executeBreakdown(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeBreakdown(arguments: Arguments) async throws -> String {
        let taskName = arguments.taskName.trimmingCharacters(in: .whitespaces)
        let numberOfSteps = min(max(arguments.numberOfSteps ?? 5, 2), 10)
        let createSubtasks = arguments.createSubtasks ?? false

        // Try to find existing task
        let existingTask = AIToolHelpers.findTask(taskName, dataService: dataService)

        // Generate breakdown suggestions based on task type
        let suggestions = generateBreakdownSuggestions(
            taskName: taskName,
            existingTask: existingTask,
            numberOfSteps: numberOfSteps
        )

        guard !suggestions.isEmpty else {
            return "I couldn't generate a breakdown for '\(taskName)'. Try being more specific about what needs to be done."
        }

        // Build response
        var response: String

        if let task = existingTask {
            response = "📋 **Breakdown for '\(task.title)':**\n\n"
        } else {
            response = "📋 **Suggested breakdown for '\(taskName)':**\n\n"
        }

        for (index, suggestion) in suggestions.enumerated() {
            response += "\(index + 1). \(suggestion)\n"
        }

        // Create subtasks if requested
        if createSubtasks {
            var targetList: TaskListEntity?
            if let listName = arguments.listName {
                targetList = AIToolHelpers.findList(listName, dataService: dataService)
            } else if let existingTaskList = existingTask?.taskList {
                targetList = existingTaskList
            }

            var createdCount = 0
            let dueDate = existingTask?.dueDate ?? Calendar.current.startOfDay(for: Date())

            for suggestion in suggestions {
                do {
                    _ = try dataService.createTask(
                        title: suggestion,
                        notes: "Subtask of: \(taskName)",
                        dueDate: dueDate,
                        scheduledTime: nil,
                        scheduledEndTime: nil,
                        priority: existingTask?.priority ?? 1,
                        list: targetList,
                        isRecurring: false,
                        recurrenceDays: nil,
                        estimatedDuration: 15
                    )
                    createdCount += 1
                } catch {
                    print("⚠️ Failed to create subtask: \(error)")
                }
            }

            if createdCount > 0 {
                response += "\n✅ Created \(createdCount) subtasks"
                if let list = targetList {
                    response += " in '\(list.name)'"
                }
                response += "."

                // Post notification
                NotificationCenter.default.post(
                    name: .aiBreakdownSuggested,
                    object: nil,
                    userInfo: [
                        "originalTask": taskName,
                        "subtasksCreated": createdCount,
                        "subtaskTitles": suggestions
                    ]
                )
            }
        } else {
            response += "\n💡 Say \"create these subtasks\" to add them to your task list."
        }

        HapticManager.shared.success()

        return response
    }

    // MARK: - Breakdown Generation

    private func generateBreakdownSuggestions(
        taskName: String,
        existingTask: TaskEntity?,
        numberOfSteps: Int
    ) -> [String] {
        let lowercased = taskName.lowercased()

        // Common task patterns with predefined breakdowns
        if lowercased.contains("presentation") || lowercased.contains("slides") {
            return truncateToCount([
                "Define presentation outline and key points",
                "Research and gather content",
                "Create slide structure",
                "Add visuals and graphics",
                "Write speaker notes",
                "Practice run-through",
                "Get feedback and revise"
            ], count: numberOfSteps)
        }

        if lowercased.contains("report") || lowercased.contains("document") {
            return truncateToCount([
                "Outline main sections",
                "Gather data and sources",
                "Write first draft",
                "Add charts/visualizations",
                "Review and edit",
                "Format and finalize"
            ], count: numberOfSteps)
        }

        if lowercased.contains("meeting") || lowercased.contains("call") {
            return truncateToCount([
                "Define meeting agenda",
                "Send calendar invites",
                "Prepare discussion points",
                "Gather relevant documents",
                "Set up meeting room/link",
                "Follow up with notes"
            ], count: numberOfSteps)
        }

        if lowercased.contains("project") || lowercased.contains("launch") {
            return truncateToCount([
                "Define project scope and goals",
                "Identify key stakeholders",
                "Create timeline and milestones",
                "Assign responsibilities",
                "Set up tracking system",
                "Schedule kickoff meeting",
                "Review and adjust plan"
            ], count: numberOfSteps)
        }

        if lowercased.contains("clean") || lowercased.contains("organize") {
            return truncateToCount([
                "Declutter and remove items",
                "Sort items into categories",
                "Clean surfaces",
                "Organize storage",
                "Label containers/areas",
                "Final walkthrough"
            ], count: numberOfSteps)
        }

        if lowercased.contains("learn") || lowercased.contains("study") || lowercased.contains("course") {
            return truncateToCount([
                "Set learning goals",
                "Gather resources and materials",
                "Create study schedule",
                "Complete first module/chapter",
                "Take notes and review",
                "Practice with exercises",
                "Test understanding"
            ], count: numberOfSteps)
        }

        if lowercased.contains("email") || lowercased.contains("write") || lowercased.contains("draft") {
            return truncateToCount([
                "Outline key points to cover",
                "Write initial draft",
                "Review for clarity",
                "Check tone and formatting",
                "Proofread and send"
            ], count: numberOfSteps)
        }

        if lowercased.contains("shop") || lowercased.contains("buy") || lowercased.contains("purchase") {
            return truncateToCount([
                "Make list of items needed",
                "Research options and prices",
                "Compare and decide",
                "Make purchase",
                "Arrange delivery/pickup"
            ], count: numberOfSteps)
        }

        if lowercased.contains("plan") || lowercased.contains("trip") || lowercased.contains("travel") {
            return truncateToCount([
                "Set dates and budget",
                "Book transportation",
                "Reserve accommodation",
                "Plan activities/itinerary",
                "Pack and prepare",
                "Confirm all bookings"
            ], count: numberOfSteps)
        }

        // Generic breakdown for unknown task types
        return truncateToCount([
            "Define what 'done' looks like for \(taskName)",
            "Gather required resources/information",
            "Complete first major step",
            "Review progress and adjust",
            "Finish remaining work",
            "Final review and wrap-up"
        ], count: numberOfSteps)
    }

    private func truncateToCount(_ items: [String], count: Int) -> [String] {
        return Array(items.prefix(count))
    }
}
