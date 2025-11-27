//
//  TaskyShortcuts.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import AppIntents

/// Provider for Tasky's Siri Shortcuts
@available(iOS 16.0, *)
struct TaskyShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add task in \(.applicationName)",
                "Create task in \(.applicationName)",
                "Add to my \(.applicationName) list",
                "New task in \(.applicationName)"
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: ShowTodayIntent(),
            phrases: [
                "Show today's tasks in \(.applicationName)",
                "What's on my \(.applicationName) today",
                "Open \(.applicationName) today view",
                "Show my tasks for today in \(.applicationName)"
            ],
            shortTitle: "Today's Tasks",
            systemImageName: "calendar"
        )

        AppShortcut(
            intent: CompleteTaskIntent(),
            phrases: [
                "Complete task in \(.applicationName)",
                "Mark task done in \(.applicationName)",
                "Finish task in \(.applicationName)"
            ],
            shortTitle: "Complete Task",
            systemImageName: "checkmark.circle.fill"
        )
    }
}
