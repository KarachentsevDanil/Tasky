//
//  AIUndoManager.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import SwiftUI
import Combine

/// Manages 5-second undo window for AI operations
/// Consistent with existing UI undo patterns in the app
@MainActor
class AIUndoManager: ObservableObject {

    // MARK: - Published Properties

    @Published var currentUndo: UndoableAction?
    @Published var showUndoToast = false

    // MARK: - Private Properties

    private var undoTimer: Timer?
    private let undoWindowDuration: TimeInterval = 5.0

    // MARK: - Undoable Action

    struct UndoableAction: Identifiable {
        let id = UUID()
        let type: ActionType
        let description: String
        let undoHandler: () -> Void
        let expiresAt: Date

        enum ActionType {
            case complete
            case update
            case reschedule
            case delete
            case listUpdate
            case listDelete
            case create
        }
    }

    // MARK: - Public Methods

    /// Register a new undoable action (replaces any existing pending undo)
    func registerUndo(_ action: UndoableAction) {
        // Cancel any existing undo timer
        undoTimer?.invalidate()

        currentUndo = action
        showUndoToast = true

        // Set 5-second expiration timer
        undoTimer = Timer.scheduledTimer(withTimeInterval: undoWindowDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.expireUndo()
            }
        }
    }

    /// Perform the undo action if available
    func performUndo() {
        guard let action = currentUndo else { return }

        undoTimer?.invalidate()
        action.undoHandler()

        // Post notification for analytics/logging
        NotificationCenter.default.post(
            name: .aiUndoAction,
            object: nil,
            userInfo: [
                "actionType": String(describing: action.type),
                "description": action.description
            ]
        )

        currentUndo = nil
        showUndoToast = false

        HapticManager.shared.lightImpact()
    }

    /// Dismiss the undo toast without performing undo
    func dismissUndo() {
        undoTimer?.invalidate()
        currentUndo = nil
        showUndoToast = false
    }

    /// Check if an undo action is currently available
    var hasUndoAvailable: Bool {
        guard let action = currentUndo else { return false }
        return Date() < action.expiresAt
    }

    /// Time remaining for undo action
    var timeRemaining: TimeInterval {
        guard let action = currentUndo else { return 0 }
        return max(0, action.expiresAt.timeIntervalSince(Date()))
    }

    // MARK: - Private Methods

    private func expireUndo() {
        currentUndo = nil
        showUndoToast = false
    }

    // MARK: - Convenience Factory Methods

    /// Create undo action for task completion toggle
    static func createCompletionUndo(
        taskId: UUID?,
        taskTitle: String,
        wasCompleted: Bool,
        dataService: DataService
    ) -> UndoableAction {
        UndoableAction(
            type: .complete,
            description: wasCompleted ? "Completed '\(taskTitle)'" : "Reopened '\(taskTitle)'",
            undoHandler: {
                guard let id = taskId else { return }
                Task { @MainActor in
                    if let task = try? dataService.fetchTaskById(id) {
                        try? dataService.toggleTaskCompletion(task)
                    }
                }
            },
            expiresAt: Date().addingTimeInterval(5.0)
        )
    }

    /// Create undo action for task update
    static func createUpdateUndo(
        taskId: UUID?,
        taskTitle: String,
        previousState: TaskPreviousState,
        dataService: DataService
    ) -> UndoableAction {
        UndoableAction(
            type: .update,
            description: "Updated '\(taskTitle)'",
            undoHandler: {
                guard let id = taskId else { return }
                Task { @MainActor in
                    if let task = try? dataService.fetchTaskById(id) {
                        // Find list by ID if needed
                        var list: TaskListEntity?
                        if let listId = previousState.listId,
                           let lists = try? dataService.fetchAllTaskLists() {
                            list = lists.first { $0.id == listId }
                        }

                        try? dataService.updateTask(
                            task,
                            title: previousState.title,
                            notes: previousState.notes,
                            dueDate: previousState.dueDate,
                            scheduledTime: previousState.scheduledTime,
                            scheduledEndTime: previousState.scheduledEndTime,
                            priority: previousState.priority,
                            list: list
                        )
                    }
                }
            },
            expiresAt: Date().addingTimeInterval(5.0)
        )
    }

    /// Create undo action for task deletion
    static func createDeleteUndo(
        deletedInfo: DeletedTaskInfo,
        dataService: DataService
    ) -> UndoableAction {
        UndoableAction(
            type: .delete,
            description: "Deleted '\(deletedInfo.title)'",
            undoHandler: {
                Task { @MainActor in
                    // Find list by ID
                    var list: TaskListEntity?
                    if let listId = deletedInfo.listId,
                       let lists = try? dataService.fetchAllTaskLists() {
                        list = lists.first { $0.id == listId }
                    }

                    // Recreate the task
                    _ = try? dataService.createTask(
                        title: deletedInfo.title,
                        notes: deletedInfo.notes,
                        dueDate: deletedInfo.dueDate,
                        scheduledTime: deletedInfo.scheduledTime,
                        scheduledEndTime: deletedInfo.scheduledEndTime,
                        priority: Int16(deletedInfo.priority),
                        list: list,
                        isRecurring: deletedInfo.isRecurring,
                        estimatedDuration: Int16(deletedInfo.estimatedDuration)
                    )
                }
            },
            expiresAt: Date().addingTimeInterval(5.0)
        )
    }

    /// Create undo action for task reschedule
    static func createRescheduleUndo(
        taskId: UUID?,
        taskTitle: String,
        previousDueDate: Date?,
        previousScheduledTime: Date?,
        previousScheduledEndTime: Date?,
        dataService: DataService
    ) -> UndoableAction {
        UndoableAction(
            type: .reschedule,
            description: "Rescheduled '\(taskTitle)'",
            undoHandler: {
                guard let id = taskId else { return }
                Task { @MainActor in
                    if let task = try? dataService.fetchTaskById(id) {
                        try? dataService.updateTask(
                            task,
                            dueDate: previousDueDate,
                            scheduledTime: previousScheduledTime,
                            scheduledEndTime: previousScheduledEndTime
                        )
                    }
                }
            },
            expiresAt: Date().addingTimeInterval(5.0)
        )
    }
}
