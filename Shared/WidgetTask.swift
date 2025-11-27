//
//  WidgetTask.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation

/// Lightweight task model for widget display
/// This struct is shared between the main app and widget extension
struct WidgetTask: Identifiable, Codable, Hashable {
    let id: UUID
    let title: String
    let isCompleted: Bool
    let dueDate: Date?
    let scheduledTime: Date?
    let priority: Int
    let aiPriorityScore: Double
    let listName: String?
    let listColorHex: String?

    // MARK: - Computed Properties

    var isDueToday: Bool {
        guard let dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isOverdue: Bool {
        guard let dueDate else { return false }
        return dueDate < Date() && !Calendar.current.isDateInToday(dueDate)
    }

    var isScheduledToday: Bool {
        guard let scheduledTime else { return false }
        return Calendar.current.isDateInToday(scheduledTime)
    }

    var formattedDueDate: String? {
        guard let dueDate else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(dueDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(dueDate) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: dueDate)
        }
    }

    var formattedScheduledTime: String? {
        guard let scheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: scheduledTime)
    }

    var priorityLevel: PriorityLevel {
        switch priority {
        case 2: return .high
        case 1: return .medium
        default: return .none
        }
    }

    enum PriorityLevel: String, Codable {
        case high, medium, none

        var iconName: String {
            switch self {
            case .high: return "flag.fill"
            case .medium: return "flag"
            case .none: return ""
            }
        }
    }
}

// MARK: - App Group Constants

enum AppGroupConstants {
    static let identifier = "group.LaktionovaSoftware.Tasky"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }

    static var storeURL: URL? {
        containerURL?.appendingPathComponent("TaskTracker.sqlite")
    }
}
