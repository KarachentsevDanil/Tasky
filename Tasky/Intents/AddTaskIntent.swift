//
//  AddTaskIntent.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import AppIntents

/// App Intent for creating a new task via Siri or Shortcuts
@available(iOS 16.0, *)
struct AddTaskIntent: AppIntent {

    static var title: LocalizedStringResource = "Add Task"

    static var description = IntentDescription("Create a new task in Tasky")

    static var openAppWhenRun: Bool = false

    // MARK: - Parameters

    @Parameter(title: "Task Title", description: "What do you need to do?")
    var title: String

    @Parameter(title: "Due Date", description: "When is this task due?")
    var dueDate: Date?

    @Parameter(title: "Priority", description: "How important is this task?")
    var priority: TaskPriorityEntity?

    // MARK: - Perform

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let dataService = DataService()

        // Convert priority to Int16
        let priorityValue: Int16 = switch priority?.id {
        case "high": 2
        case "medium": 1
        default: 0
        }

        do {
            try dataService.createTask(
                title: title,
                dueDate: dueDate ?? Date(), // Default to today
                priority: priorityValue
            )

            // Donate this intent for Siri suggestions
            IntentDonationManager.donateAddTask(title: title)

            let dateString = dueDate.map { formatDate($0) } ?? "today"
            return .result(dialog: "Added '\(title)' for \(dateString)")
        } catch {
            throw IntentError.taskCreationFailed
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInTomorrow(date) {
            return "tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
}

// MARK: - Priority Entity

@available(iOS 16.0, *)
struct TaskPriorityEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Priority")

    static var defaultQuery = TaskPriorityQuery()

    var id: String
    var displayName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(displayName)")
    }

    static let high = TaskPriorityEntity(id: "high", displayName: "High")
    static let medium = TaskPriorityEntity(id: "medium", displayName: "Medium")
    static let none = TaskPriorityEntity(id: "none", displayName: "None")

    static let allPriorities: [TaskPriorityEntity] = [.high, .medium, .none]
}

@available(iOS 16.0, *)
struct TaskPriorityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TaskPriorityEntity] {
        TaskPriorityEntity.allPriorities.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [TaskPriorityEntity] {
        TaskPriorityEntity.allPriorities
    }
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, CustomLocalizedStringResourceConvertible {
    case taskCreationFailed
    case taskNotFound
    case completionFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .taskCreationFailed:
            return "Failed to create task"
        case .taskNotFound:
            return "Task not found"
        case .completionFailed:
            return "Failed to complete task"
        }
    }
}
