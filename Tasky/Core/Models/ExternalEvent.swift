//
//  ExternalEvent.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Represents an external calendar event from EventKit
struct ExternalEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarColorHex: String
    let location: String?
    let notes: String?

    // MARK: - Computed Properties

    var calendarColor: Color {
        Color(hex: calendarColorHex) ?? .gray
    }

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationMinutes: Int {
        Int(duration / 60)
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        if isAllDay {
            return "All day"
        }

        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ExternalEvent, rhs: ExternalEvent) -> Bool {
        lhs.id == rhs.id
    }
}

/// Information about a user's calendar
struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let colorHex: String
    let source: String  // iCloud, Google, Exchange, etc.
    var isEnabled: Bool

    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}

/// Calendar permission status
enum CalendarPermissionStatus {
    case notDetermined
    case authorized
    case denied
    case restricted

    var canRequest: Bool {
        self == .notDetermined
    }

    var hasAccess: Bool {
        self == .authorized
    }
}

/// Blocked time slot for AI planning
struct BlockedTimeSlot: Hashable {
    let startDate: Date
    let endDate: Date
    let title: String
    let isAllDay: Bool

    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Check if this slot overlaps with a given time range
    func overlaps(with start: Date, end: Date) -> Bool {
        !(endDate <= start || startDate >= end)
    }
}
