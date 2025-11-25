//
//  AIToolNotifications.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation

/// Centralized notification names for AI tool operations
/// All AI tools post notifications for UI feedback and undo support
extension Notification.Name {
    // MARK: - Task Operations (with undo support)

    /// Posted when tasks are created via AI - existing notification
    /// userInfo: ["tasks": [CreatedTaskInfo]]
    // Note: .aiTasksCreated is defined in CreateTasksTool.swift

    /// Posted when a task is marked complete/incomplete
    /// userInfo: ["taskId": UUID?, "taskTitle": String, "completed": Bool, "previousState": Bool, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiTaskCompleted = Notification.Name("aiTaskCompleted")

    /// Posted when a task is updated
    /// userInfo: ["taskId": UUID?, "taskTitle": String, "changes": [String], "previousState": TaskPreviousState, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiTaskUpdated = Notification.Name("aiTaskUpdated")

    /// Posted when a task is rescheduled
    /// userInfo: ["taskId": UUID?, "taskTitle": String, "newDate": Date, "previousDueDate": Date?, "previousScheduledTime": Date?, "previousScheduledEndTime": Date?, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiTaskRescheduled = Notification.Name("aiTaskRescheduled")

    /// Posted when a task is deleted
    /// userInfo: ["deletedTaskInfo": DeletedTaskInfo, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiTaskDeleted = Notification.Name("aiTaskDeleted")

    // MARK: - List Operations

    /// Posted when a list is created
    /// userInfo: ["listName": String, "listId": UUID?]
    static let aiListCreated = Notification.Name("aiListCreated")

    /// Posted when a list is renamed
    /// userInfo: ["listId": UUID?, "oldName": String, "newName": String, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiListUpdated = Notification.Name("aiListUpdated")

    /// Posted when a list is deleted
    /// userInfo: ["listId": UUID?, "listName": String, "colorHex": String?, "iconName": String?, "taskCount": Int, "undoAvailable": Bool, "undoExpiresAt": Date]
    static let aiListDeleted = Notification.Name("aiListDeleted")

    // MARK: - Focus Sessions

    /// Posted to start a focus session
    /// userInfo: ["taskId": UUID?, "taskTitle": String, "durationMinutes": Int]
    static let aiFocusSessionStart = Notification.Name("aiFocusSessionStart")

    /// Posted to stop current focus session
    /// userInfo: [:]
    static let aiFocusSessionStop = Notification.Name("aiFocusSessionStop")

    /// Posted to request focus session status
    /// userInfo: [:]
    static let aiFocusSessionStatus = Notification.Name("aiFocusSessionStatus")

    // MARK: - Undo Actions

    /// Posted when undo is performed
    /// userInfo: ["actionType": String, "description": String]
    static let aiUndoAction = Notification.Name("aiUndoAction")
}
