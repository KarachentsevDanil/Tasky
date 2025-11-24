//
//  TaskEntity+TimeLabels.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import Foundation

extension TaskEntity {

    /// Get human-readable time label for the task
    /// Examples: "Due tonight", "Flexible", "Needs attention", "Overdue"
    var humanReadableTimeLabel: String? {
        let now = Date()
        let calendar = Calendar.current

        // Check scheduled time first (higher priority than due date)
        if let scheduledTime = scheduledTime {
            if scheduledTime < now {
                return "Overdue"
            } else if calendar.isDateInToday(scheduledTime) {
                let components = calendar.dateComponents([.hour], from: now, to: scheduledTime)
                if let hours = components.hour {
                    if hours == 0 {
                        return "Due now"
                    } else if hours <= 2 {
                        return "Due soon"
                    } else if hours >= 18 {
                        return "Due tonight"
                    } else {
                        return "Due at \(AppDateFormatters.timeFormatter.string(from: scheduledTime))"
                    }
                }
            } else if calendar.isDateInTomorrow(scheduledTime) {
                return "Tomorrow"
            }
        }

        // Check due date
        if let dueDate = dueDate {
            if dueDate < now && !calendar.isDateInToday(dueDate) {
                let components = calendar.dateComponents([.day], from: dueDate, to: now)
                if let days = components.day, days > 0 {
                    return "Overdue"
                }
            } else if calendar.isDateInToday(dueDate) {
                return "Due tonight"
            } else if calendar.isDateInTomorrow(dueDate) {
                return "Tomorrow"
            } else {
                let components = calendar.dateComponents([.day], from: now, to: dueDate)
                if let days = components.day, days > 0 {
                    if days == 1 {
                        return "Tomorrow"
                    } else if days <= 3 {
                        return "In \(days) days"
                    } else if days <= 7 {
                        return "This week"
                    }
                }
            }
        }

        // No date set - flexible
        return "Flexible"
    }

    /// Short urgency label for compact display
    var urgencyIndicator: String? {
        let now = Date()
        let calendar = Calendar.current

        if let scheduledTime = scheduledTime {
            if scheduledTime < now {
                return "Overdue"
            } else if calendar.isDateInToday(scheduledTime) {
                let components = calendar.dateComponents([.hour, .minute], from: now, to: scheduledTime)
                if let hours = components.hour, let minutes = components.minute {
                    if hours == 0 && minutes <= 30 {
                        return "In \(minutes)m"
                    } else if hours <= 2 {
                        return "In \(hours)h"
                    }
                }
            }
        }

        if let dueDate = dueDate {
            if dueDate < now && !calendar.isDateInToday(dueDate) {
                return "Overdue"
            } else if calendar.isDateInToday(dueDate) {
                return "Today"
            }
        }

        return nil
    }
}
