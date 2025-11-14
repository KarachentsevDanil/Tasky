//
//  DateFormatters.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import Foundation

/// Shared date formatters to avoid expensive repeated initialization
/// DateFormatter creation is expensive - reusing formatters improves performance
enum AppDateFormatters {

    // MARK: - Common Date/Time Formatters

    /// Format: "3:45 PM"
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()

    /// Format: "Nov 14, 2025"
    static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    /// Format: "11/14/25"
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()

    // MARK: - Custom Pattern Formatters

    /// Format: "Thursday, Nov 14"
    static let dayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }()

    /// Format: "Nov 14"
    static let shortDayMonthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    /// Format: "Nov 2025"
    static let monthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter
    }()

    /// Format: "November 2025"
    static let fullMonthYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()

    /// Format: "6AM", "12PM"
    static let hourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        return formatter
    }()

    /// Format: "Thu"
    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }()

    // MARK: - ISO8601 Formatters

    /// ISO8601 formatter for API communication and AI tool date parsing
    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    /// ISO8601 formatter with fractional seconds
    static let iso8601FormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    // MARK: - Weekday Symbols

    /// Very short weekday symbols: ["S", "M", "T", "W", "T", "F", "S"]
    static var veryShortWeekdaySymbols: [String] {
        DateFormatter().veryShortWeekdaySymbols
    }

    /// Short weekday symbols: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    static var shortWeekdaySymbols: [String] {
        DateFormatter().shortWeekdaySymbols
    }

    // MARK: - Helper Methods

    /// Format a time range: "3:00 PM - 4:30 PM"
    static func formatTimeRange(start: Date, end: Date) -> String {
        "\(timeFormatter.string(from: start)) - \(timeFormatter.string(from: end))"
    }

    /// Format date relative to today: "Today", "Yesterday", "Tomorrow", or formatted date
    static func formatRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return mediumDateFormatter.string(from: date)
        }
    }

    /// Format short relative date: "Today", "Tomorrow", or "Nov 14"
    static func formatShortRelativeDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            return shortDayMonthFormatter.string(from: date)
        }
    }
}
