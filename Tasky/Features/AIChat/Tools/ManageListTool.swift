//
//  ManageListTool.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import FoundationModels

/// Tool for creating, renaming, and deleting task lists
/// Optimized for local LLM with explicit action options
struct ManageListTool: Tool {
    let name = "manageList"

    let description = "Manage task lists. Triggers: create list, new list, rename list, delete list, remove list."

    let dataService: DataService

    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    /// Arguments with explicit action options
    @Generable
    struct Arguments {
        @Guide(description: "Action to perform on the list")
        @Guide(.anyOf(["create", "rename", "delete"]))
        let action: String

        @Guide(description: "List name. For create: new name. For rename/delete: existing name.")
        let listName: String

        @Guide(description: "New name. Only required for rename action.")
        let newName: String?

        @Guide(description: "List color. Optional for create, defaults to blue.")
        @Guide(.anyOf(["red", "orange", "yellow", "green", "blue", "purple", "pink", "gray"]))
        let color: String?

        @Guide(description: "List icon. Optional for create, defaults to list.")
        @Guide(.anyOf(["list", "folder", "briefcase", "house", "cart", "heart", "star", "flag", "book", "gift"]))
        let icon: String?
    }

    // Color mapping to hex values
    private let colorMap: [String: String] = [
        "red": "#FF3B30",
        "orange": "#FF9500",
        "yellow": "#FFCC00",
        "green": "#34C759",
        "blue": "#007AFF",
        "purple": "#AF52DE",
        "pink": "#FF2D55",
        "gray": "#8E8E93"
    ]

    // Valid SF Symbol icon names
    private let iconMap: [String: String] = [
        "list": "list.bullet",
        "folder": "folder",
        "briefcase": "briefcase",
        "house": "house",
        "cart": "cart",
        "heart": "heart",
        "star": "star",
        "flag": "flag",
        "book": "book",
        "gift": "gift"
    ]

    func call(arguments: Arguments) async throws -> GeneratedContent {
        // Track usage for personalized suggestions
        await AIUsageTracker.shared.trackToolCall("manageList")
        let result = await executeAction(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executeAction(arguments: Arguments) async -> String {
        switch arguments.action.lowercased() {
        case "create":
            return await createList(arguments)
        case "rename":
            return await renameList(arguments)
        case "delete":
            return await deleteList(arguments)
        default:
            return "Unknown action '\(arguments.action)'. Use: create, rename, or delete."
        }
    }

    @MainActor
    private func createList(_ arguments: Arguments) async -> String {
        let name = arguments.listName.trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty else {
            return "List name cannot be empty."
        }

        // Check if list already exists
        if AIToolHelpers.findList(name, dataService: dataService) != nil {
            return "A list named '\(name)' already exists."
        }

        // Get color hex (default to blue)
        let colorHex = arguments.color.flatMap { colorMap[$0.lowercased()] } ?? colorMap["blue"]!

        // Get icon name (default to list.bullet)
        let iconName = arguments.icon.flatMap { iconMap[$0.lowercased()] } ?? "list.bullet"

        do {
            let newList = try dataService.createTaskList(name: name, colorHex: colorHex, iconName: iconName)

            NotificationCenter.default.post(
                name: .aiListCreated,
                object: nil,
                userInfo: [
                    "listName": name,
                    "listId": newList.id as Any
                ]
            )

            HapticManager.shared.success()

            return "Created list '\(name)'"

        } catch {
            HapticManager.shared.error()
            return "Failed to create list: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func renameList(_ arguments: Arguments) async -> String {
        guard let newName = arguments.newName, !newName.isEmpty else {
            return "Please specify the new name for the list."
        }

        guard let list = AIToolHelpers.findList(arguments.listName, dataService: dataService) else {
            return "Could not find list '\(arguments.listName)'. Available: \(AIToolHelpers.getAvailableListNames(dataService: dataService))"
        }

        let oldName = list.name

        do {
            try dataService.updateTaskList(list, name: newName, colorHex: list.colorHex, iconName: list.iconName)

            NotificationCenter.default.post(
                name: .aiListUpdated,
                object: nil,
                userInfo: [
                    "listId": list.id as Any,
                    "oldName": oldName,
                    "newName": newName,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.success()

            return "Renamed '\(oldName)' to '\(newName)'"

        } catch {
            HapticManager.shared.error()
            return "Failed to rename list: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func deleteList(_ arguments: Arguments) async -> String {
        guard let list = AIToolHelpers.findList(arguments.listName, dataService: dataService) else {
            return "Could not find list '\(arguments.listName)'. Available: \(AIToolHelpers.getAvailableListNames(dataService: dataService))"
        }

        let listName = list.name
        let listId = list.id
        let taskCount = list.tasksArray.count
        let colorHex = list.colorHex
        let iconName = list.iconName

        do {
            try dataService.deleteTaskList(list)

            // Store info for potential undo
            NotificationCenter.default.post(
                name: .aiListDeleted,
                object: nil,
                userInfo: [
                    "listId": listId as Any,
                    "listName": listName,
                    "colorHex": colorHex as Any,
                    "iconName": iconName as Any,
                    "taskCount": taskCount,
                    "undoAvailable": true,
                    "undoExpiresAt": Date().addingTimeInterval(5.0)
                ]
            )

            HapticManager.shared.lightImpact()

            var response = "Deleted list '\(listName)'"
            if taskCount > 0 {
                response += " (\(taskCount) tasks moved to Inbox)"
            }

            return response

        } catch {
            HapticManager.shared.error()
            return "Failed to delete list: \(error.localizedDescription)"
        }
    }
}
