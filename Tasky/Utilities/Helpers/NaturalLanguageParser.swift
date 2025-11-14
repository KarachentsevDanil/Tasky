//
//  NaturalLanguageParser.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Parses natural language input to extract task metadata (dates, times, priorities, lists)
struct NaturalLanguageParser {

    // MARK: - Parse Result

    struct ParsedTask {
        var cleanTitle: String
        var dueDate: Date?
        var scheduledTime: Date?
        var priority: Int16 = 0
        var listHint: String?
        var suggestions: [Suggestion] = []
    }

    struct Suggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let text: String
        let icon: String

        enum SuggestionType {
            case date
            case time
            case priority
            case list
        }
    }

    // MARK: - Parsing

    /// Parse natural language input and extract task metadata
    static func parse(_ input: String) -> ParsedTask {
        var result = ParsedTask(cleanTitle: input)

        // Parse in order of specificity
        result = parseDateTime(from: result)
        result = parsePriority(from: result)
        result = parseList(from: result)

        // Generate suggestions based on what was found
        result.suggestions = generateSuggestions(from: result)

        return result
    }

    // MARK: - Date & Time Parsing

    private static func parseDateTime(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let lowercased = result.cleanTitle.lowercased()

        // Time patterns (e.g., "at 3pm", "at 14:30", "3:00 pm")
        let timePatterns = [
            (regex: #"(?:at |@ )?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#, format: "12h"),
            (regex: #"(?:at |@ )?(\d{1,2}):(\d{2})"#, format: "24h")
        ]

        for pattern in timePatterns {
            if let match = lowercased.range(of: pattern.regex, options: .regularExpression) {
                let matchedText = String(lowercased[match])
                if let time = parseTime(from: matchedText, format: pattern.format) {
                    result.scheduledTime = time
                    // Remove the time from title
                    result.cleanTitle = result.cleanTitle.replacingOccurrences(
                        of: matchedText,
                        with: "",
                        options: [.regularExpression, .caseInsensitive]
                    ).trimmingCharacters(in: .whitespacesAndNewlines)
                    break
                }
            }
        }

        // Date patterns
        let dateKeywords: [(keyword: String, offset: Calendar.Component, value: Int)] = [
            ("today", .day, 0),
            ("tomorrow", .day, 1),
            ("tmr", .day, 1),
            ("next week", .weekOfYear, 1),
            ("next month", .month, 1),
            ("monday", .day, 0),
            ("tuesday", .day, 0),
            ("wednesday", .day, 0),
            ("thursday", .day, 0),
            ("friday", .day, 0),
            ("saturday", .day, 0),
            ("sunday", .day, 0)
        ]

        for keyword in dateKeywords {
            if lowercased.contains(keyword.keyword) {
                let date: Date

                // Handle weekday names specially
                if ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains(keyword.keyword) {
                    date = nextWeekday(matching: keyword.keyword)
                } else {
                    date = Calendar.current.date(
                        byAdding: keyword.offset,
                        value: keyword.value,
                        to: Date()
                    ) ?? Date()
                }

                result.dueDate = Calendar.current.startOfDay(for: date)

                // Remove the keyword from title
                result.cleanTitle = result.cleanTitle.replacingOccurrences(
                    of: keyword.keyword,
                    with: "",
                    options: .caseInsensitive
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return result
    }

    // MARK: - Priority Parsing

    private static func parsePriority(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let lowercased = result.cleanTitle.lowercased()

        let priorityKeywords: [(keyword: String, priority: Int16)] = [
            ("!high", 3),
            ("!urgent", 3),
            ("!medium", 2),
            ("!low", 1),
            ("!!!", 3),
            ("!!", 2),
            ("!", 1)
        ]

        for keyword in priorityKeywords {
            if lowercased.contains(keyword.keyword) {
                result.priority = keyword.priority
                // Remove the keyword from title
                result.cleanTitle = result.cleanTitle.replacingOccurrences(
                    of: keyword.keyword,
                    with: "",
                    options: .caseInsensitive
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        return result
    }

    // MARK: - List Parsing

    private static func parseList(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let lowercased = result.cleanTitle.lowercased()

        // Look for #hashtag pattern
        if let hashtagRange = lowercased.range(of: #"#(\w+)"#, options: .regularExpression) {
            let hashtag = String(lowercased[hashtagRange])
            result.listHint = hashtag.replacingOccurrences(of: "#", with: "")

            // Remove the hashtag from title
            result.cleanTitle = result.cleanTitle.replacingOccurrences(
                of: hashtag,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            ).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return result
    }

    // MARK: - Suggestions

    private static func generateSuggestions(from parsed: ParsedTask) -> [Suggestion] {
        var suggestions: [Suggestion] = []

        if let date = parsed.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            suggestions.append(Suggestion(
                type: .date,
                text: formatter.string(from: date),
                icon: "calendar"
            ))
        }

        if let time = parsed.scheduledTime {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            suggestions.append(Suggestion(
                type: .time,
                text: formatter.string(from: time),
                icon: "clock"
            ))
        }

        if parsed.priority > 0 {
            let priorityName = Constants.TaskPriority(rawValue: parsed.priority)?.displayName ?? "Unknown"
            suggestions.append(Suggestion(
                type: .priority,
                text: priorityName,
                icon: "flag.fill"
            ))
        }

        if let listHint = parsed.listHint {
            suggestions.append(Suggestion(
                type: .list,
                text: listHint.capitalized,
                icon: "list.bullet"
            ))
        }

        return suggestions
    }

    // MARK: - Helper Methods

    private static func parseTime(from text: String, format: String) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())

        if format == "12h" {
            // Parse 12-hour format (e.g., "3pm", "3:30 pm")
            let pattern = #"(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                return nil
            }

            let hourRange = Range(match.range(at: 1), in: text)!
            var hour = Int(text[hourRange]) ?? 0

            let minuteRange = match.range(at: 2)
            let minute = minuteRange.location != NSNotFound ? Int(text[Range(minuteRange, in: text)!]) ?? 0 : 0

            let ampmRange = Range(match.range(at: 3), in: text)!
            let ampm = text[ampmRange].lowercased()

            if ampm == "pm" && hour != 12 {
                hour += 12
            } else if ampm == "am" && hour == 12 {
                hour = 0
            }

            components.hour = hour
            components.minute = minute
        } else {
            // Parse 24-hour format (e.g., "14:30", "9:15")
            let parts = text.components(separatedBy: ":")
            guard parts.count == 2,
                  let hour = Int(parts[0]),
                  let minute = Int(parts[1]) else {
                return nil
            }

            components.hour = hour
            components.minute = minute
        }

        return calendar.date(from: components)
    }

    private static func nextWeekday(matching weekdayName: String) -> Date {
        let weekdays = ["sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7]
        guard let targetWeekday = weekdays[weekdayName.lowercased()] else { return Date() }

        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday
        if daysToAdd <= 0 {
            daysToAdd += 7 // Move to next week if the day has passed or is today
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}
