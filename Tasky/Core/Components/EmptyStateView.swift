//
//  EmptyStateView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Reusable empty state component with icon, title, message, and optional action
struct EmptyStateView: View {

    // MARK: - Properties
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    // MARK: - Initialization
    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            // Title
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)

            // Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Optional action button
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
        .accessibilityHint(actionTitle.map { "Double tap to \($0.lowercased())" } ?? "")
    }
}

// MARK: - Convenience Initializers
extension EmptyStateView {

    /// Empty state for no tasks
    static func noTasks(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "checkmark.circle.fill",
            title: "No tasks yet",
            message: "Add a task to get started",
            actionTitle: action != nil ? "Add Task" : nil,
            action: action
        )
    }

    /// Empty state for no results
    static func noResults(searchTerm: String? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "No results found",
            message: searchTerm.map { "No tasks match '\($0)'" } ?? "Try adjusting your search"
        )
    }

    /// Empty state for completed tasks
    static func allComplete() -> EmptyStateView {
        EmptyStateView(
            icon: "checkmark.circle.fill",
            title: "All done!",
            message: "You've completed all your tasks"
        )
    }

    /// Empty state for unscheduled tasks
    static func noUnscheduledTasks() -> EmptyStateView {
        EmptyStateView(
            icon: "tray",
            title: "No unscheduled tasks",
            message: "All your tasks have been scheduled"
        )
    }

    /// Empty state for lists
    static func noLists(action: (() -> Void)? = nil) -> EmptyStateView {
        EmptyStateView(
            icon: "folder",
            title: "No lists yet",
            message: "Create a list to organize your tasks",
            actionTitle: action != nil ? "Create List" : nil,
            action: action
        )
    }
}

// MARK: - Preview
#Preview("Default") {
    EmptyStateView(
        icon: "tray",
        title: "Nothing here",
        message: "Add some items to get started"
    )
}

#Preview("With Action") {
    EmptyStateView(
        icon: "checkmark.circle.fill",
        title: "No tasks",
        message: "Tap below to add your first task",
        actionTitle: "Add Task",
        action: { print("Add tapped") }
    )
}

#Preview("No Tasks") {
    EmptyStateView.noTasks(action: { print("Add task") })
}

#Preview("No Results") {
    EmptyStateView.noResults(searchTerm: "work")
}

#Preview("All Complete") {
    EmptyStateView.allComplete()
}
