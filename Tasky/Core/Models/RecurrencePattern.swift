//
//  RecurrencePattern.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import Foundation

/// Represents different recurrence types
enum RecurrenceType: String, CaseIterable, Identifiable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case afterCompletion = "afterCompletion"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .afterCompletion: return "After Completion"
        }
    }

    var icon: String {
        switch self {
        case .daily: return "sunrise"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .yearly: return "calendar.badge.exclamationmark"
        case .afterCompletion: return "checkmark.circle.badge.clock"
        }
    }
}

/// Represents ordinal position in a month (e.g., "first Monday")
enum WeekdayOrdinal: Int16, CaseIterable, Identifiable {
    case first = 1
    case second = 2
    case third = 3
    case fourth = 4
    case last = -1

    var id: Int16 { rawValue }

    var displayName: String {
        switch self {
        case .first: return "First"
        case .second: return "Second"
        case .third: return "Third"
        case .fourth: return "Fourth"
        case .last: return "Last"
        }
    }
}

/// Complete recurrence pattern configuration
struct RecurrencePattern {
    var type: RecurrenceType
    var interval: Int16 = 1
    var weekdays: Set<Int> = []
    var dayOfMonth: Int16 = 0
    var weekdayOrdinal: WeekdayOrdinal?
    var endDate: Date?
    var maxOccurrences: Int16 = 0

    // MARK: - Initialization

    init(type: RecurrenceType = .weekly) {
        self.type = type
    }

    init(from task: TaskEntity) {
        self.type = RecurrenceType(rawValue: task.recurrenceType ?? "") ?? .weekly
        self.interval = task.recurrenceInterval
        self.weekdays = Set(task.recurrenceDayNumbers)
        self.dayOfMonth = task.recurrenceDayOfMonth
        self.weekdayOrdinal = task.recurrenceWeekdayOrdinal != 0
            ? WeekdayOrdinal(rawValue: task.recurrenceWeekdayOrdinal)
            : nil
        self.endDate = task.recurrenceEndDate
        self.maxOccurrences = task.recurrenceCount
    }

    // MARK: - Apply to Task

    func apply(to task: TaskEntity) {
        task.recurrenceType = type.rawValue
        task.recurrenceInterval = interval
        task.setRecurrenceDays(Array(weekdays))
        task.recurrenceDayOfMonth = dayOfMonth
        task.recurrenceWeekdayOrdinal = weekdayOrdinal?.rawValue ?? 0
        task.recurrenceEndDate = endDate
        task.recurrenceCount = maxOccurrences
    }

    // MARK: - Human Readable Description

    var description: String {
        var parts: [String] = []

        switch type {
        case .daily:
            if interval == 1 {
                parts.append("Every day")
            } else {
                parts.append("Every \(interval) days")
            }

        case .weekly:
            if interval == 1 {
                parts.append("Every week")
            } else {
                parts.append("Every \(interval) weeks")
            }

            if !weekdays.isEmpty {
                let dayNames = weekdays.sorted().compactMap { weekdayName(for: $0) }
                if dayNames.count == 7 {
                    // Already covered by "Every day"
                } else if dayNames.count == 5 && !weekdays.contains(6) && !weekdays.contains(7) {
                    parts.append("on weekdays")
                } else if dayNames.count == 2 && weekdays.contains(6) && weekdays.contains(7) {
                    parts.append("on weekends")
                } else {
                    parts.append("on \(dayNames.joined(separator: ", "))")
                }
            }

        case .monthly:
            if interval == 1 {
                parts.append("Every month")
            } else {
                parts.append("Every \(interval) months")
            }

            if let ordinal = weekdayOrdinal, !weekdays.isEmpty {
                let dayName = weekdayName(for: weekdays.first ?? 1) ?? ""
                parts.append("on the \(ordinal.displayName.lowercased()) \(dayName)")
            } else if dayOfMonth > 0 {
                parts.append("on day \(dayOfMonth)")
            }

        case .yearly:
            if interval == 1 {
                parts.append("Every year")
            } else {
                parts.append("Every \(interval) years")
            }

        case .afterCompletion:
            if interval == 1 {
                parts.append("1 day after completion")
            } else {
                parts.append("\(interval) days after completion")
            }
        }

        // End condition
        if let endDate = endDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            parts.append("until \(formatter.string(from: endDate))")
        } else if maxOccurrences > 0 {
            parts.append("for \(maxOccurrences) times")
        }

        return parts.joined(separator: " ")
    }

    private func weekdayName(for number: Int) -> String? {
        let names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        guard number >= 1 && number <= 7 else { return nil }
        return names[number - 1]
    }

    // MARK: - Calculate Next Occurrence

    func nextOccurrence(from date: Date) -> Date? {
        let calendar = Calendar.current

        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: Int(interval), to: date)

        case .weekly:
            if weekdays.isEmpty {
                return calendar.date(byAdding: .weekOfYear, value: Int(interval), to: date)
            }

            // Find next matching weekday
            var nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            var attempts = 0
            let maxAttempts = 7 * Int(interval) + 1

            while attempts < maxAttempts {
                let weekday = calendar.component(.weekday, from: nextDate)
                let adjustedWeekday = weekday == 1 ? 7 : weekday - 1 // Convert to Mon=1, Sun=7

                if weekdays.contains(adjustedWeekday) {
                    return nextDate
                }

                nextDate = calendar.date(byAdding: .day, value: 1, to: nextDate) ?? nextDate
                attempts += 1
            }

            return nil

        case .monthly:
            var components = DateComponents()
            components.month = Int(interval)
            return calendar.date(byAdding: components, to: date)

        case .yearly:
            return calendar.date(byAdding: .year, value: Int(interval), to: date)

        case .afterCompletion:
            return calendar.date(byAdding: .day, value: Int(interval), to: date)
        }
    }

    // MARK: - Validation

    var isValid: Bool {
        switch type {
        case .weekly:
            return !weekdays.isEmpty || interval > 0
        case .monthly:
            return dayOfMonth > 0 || weekdayOrdinal != nil
        default:
            return true
        }
    }
}

// MARK: - Task Extension for Recurrence

extension TaskEntity {

    var recurrencePattern: RecurrencePattern? {
        guard isRecurring else { return nil }
        return RecurrencePattern(from: self)
    }

    func setRecurrencePattern(_ pattern: RecurrencePattern?) {
        if let pattern = pattern {
            isRecurring = true
            pattern.apply(to: self)
        } else {
            isRecurring = false
            recurrenceType = nil
            recurrenceInterval = 1
            recurrenceDays = nil
            recurrenceDayOfMonth = 0
            recurrenceWeekdayOrdinal = 0
            recurrenceEndDate = nil
            recurrenceCount = 0
        }
    }

    var formattedRecurrencePattern: String? {
        recurrencePattern?.description
    }
}
