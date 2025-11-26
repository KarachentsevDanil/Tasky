//
//  NaturalLanguageParser.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation

/// Parses natural language input to extract task metadata (dates, times, priorities, lists, durations)
struct NaturalLanguageParser {

    // MARK: - Parse Result

    struct ParsedTask {
        var cleanTitle: String
        var dueDate: Date?
        var scheduledTime: Date?
        var scheduledEndTime: Date?
        var durationSeconds: Int?
        var priority: Int16 = 0
        var listHint: String?
        var suggestions: [Suggestion] = []
        var isDeadlineOnly: Bool = false  // True when time is set but no duration/end time
        var recurrence: RecurrenceRule?   // Parsed recurrence pattern
    }

    /// Recurrence rule for repeating tasks
    struct RecurrenceRule: Equatable {
        enum Frequency: String, CaseIterable {
            case daily = "daily"
            case weekly = "weekly"
            case monthly = "monthly"
            case yearly = "yearly"
            case weekdays = "weekdays"  // Mon-Fri
            case weekends = "weekends"  // Sat-Sun
        }

        var frequency: Frequency
        var interval: Int = 1           // e.g., "every 2 weeks" -> interval = 2
        var weekdays: [Int]?            // For weekly: specific days (1=Sun, 2=Mon, etc.)
        var dayOfMonth: Int?            // For monthly: specific day

        var displayText: String {
            switch frequency {
            case .daily:
                return interval == 1 ? "Daily" : "Every \(interval) days"
            case .weekly:
                if let days = weekdays, !days.isEmpty {
                    let dayNames = days.compactMap { weekdayName(for: $0) }
                    return "Weekly on \(dayNames.joined(separator: ", "))"
                }
                return interval == 1 ? "Weekly" : "Every \(interval) weeks"
            case .monthly:
                if let day = dayOfMonth {
                    return "Monthly on the \(ordinal(day))"
                }
                return interval == 1 ? "Monthly" : "Every \(interval) months"
            case .yearly:
                return interval == 1 ? "Yearly" : "Every \(interval) years"
            case .weekdays:
                return "Every weekday"
            case .weekends:
                return "Every weekend"
            }
        }

        private func weekdayName(for day: Int) -> String? {
            let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
            guard day >= 1, day <= 7 else { return nil }
            return names[day]
        }

        private func ordinal(_ n: Int) -> String {
            let suffix: String
            let ones = n % 10
            let tens = (n / 10) % 10
            if tens == 1 {
                suffix = "th"
            } else {
                switch ones {
                case 1: suffix = "st"
                case 2: suffix = "nd"
                case 3: suffix = "rd"
                default: suffix = "th"
                }
            }
            return "\(n)\(suffix)"
        }
    }

    struct Suggestion: Identifiable {
        let id = UUID()
        let type: SuggestionType
        let text: String
        let icon: String

        enum SuggestionType {
            case date
            case time
            case duration
            case priority
            case list
            case recurrence
        }
    }

    // MARK: - Time Keywords

    /// Smart time keywords with default hours
    private static let timeKeywords: [(keyword: String, hour: Int, minute: Int)] = [
        ("midnight", 0, 0),
        ("noon", 12, 0),
        ("midday", 12, 0),
        ("morning", 9, 0),
        ("afternoon", 14, 0),
        ("evening", 18, 0),
        ("tonight", 20, 0),
        ("night", 21, 0),
        ("eod", 17, 0),      // End of day
        ("cob", 17, 0)       // Close of business
    ]

    // MARK: - Priority Keywords

    /// Priority keywords with natural language support
    private static let priorityKeywords: [(pattern: String, priority: Int16)] = [
        // Word-based (most natural)
        (#"\b(high\s*priority|urgent|critical|asap)\b"#, 3),
        (#"\b(medium\s*priority|important)\b"#, 2),
        (#"\b(low\s*priority)\b"#, 1),
        // Symbol-based
        (#"!!!"#, 3),
        (#"!!"#, 2),
        (#"!high\b"#, 3),
        (#"!urgent\b"#, 3),
        (#"!medium\b"#, 2),
        (#"!low\b"#, 1),
        (#"(?<![!])!(?![!])"#, 1)  // Single ! not preceded or followed by !
    ]

    // MARK: - Parsing

    /// Parse natural language input and extract task metadata
    static func parse(_ input: String) -> ParsedTask {
        var result = ParsedTask(cleanTitle: input)

        // Parse recurrence first (before other patterns that might conflict)
        result = parseRecurrence(from: result)

        // Parse in order of specificity (most specific first)
        result = parseTimeRange(from: result)
        result = parseDuration(from: result)
        result = parseDateTime(from: result)
        result = parsePriority(from: result)
        result = parseList(from: result)

        // Apply smart date defaults
        result = applySmartDateDefaults(to: result)

        // Clean up title
        result.cleanTitle = cleanTitle(result.cleanTitle)

        // Generate suggestions based on what was found
        result.suggestions = generateSuggestions(from: result)

        return result
    }

    // MARK: - Recurrence Parsing

    /// Parse recurrence patterns like "every day", "every monday", "weekly", "every 2 weeks"
    private static func parseRecurrence(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let text = result.cleanTitle
        let lowercased = text.lowercased()

        // Weekday names for pattern matching
        let weekdayPattern = "(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)"

        // Order matters - most specific patterns first
        let patterns: [(pattern: String, handler: (NSTextCheckingResult, String) -> RecurrenceRule?)] = [
            // "every weekday" or "on weekdays"
            (#"\b(?:every\s+weekday|on\s+weekdays|weekdays)\b"#, { _, _ in
                RecurrenceRule(frequency: .weekdays)
            }),

            // "every weekend" or "on weekends"
            (#"\b(?:every\s+weekend|on\s+weekends|weekends)\b"#, { _, _ in
                RecurrenceRule(frequency: .weekends)
            }),

            // "every N days/weeks/months"
            (#"\bevery\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b"#, { match, text in
                guard let intervalRange = Range(match.range(at: 1), in: text),
                      let unitRange = Range(match.range(at: 2), in: text) else { return nil }
                let interval = Int(text[intervalRange]) ?? 1
                let unit = String(text[unitRange]).lowercased()
                let frequency: RecurrenceRule.Frequency
                if unit.hasPrefix("day") {
                    frequency = .daily
                } else if unit.hasPrefix("week") {
                    frequency = .weekly
                } else if unit.hasPrefix("month") {
                    frequency = .monthly
                } else {
                    frequency = .yearly
                }
                return RecurrenceRule(frequency: frequency, interval: interval)
            }),

            // "every monday", "every tuesday", etc. (single weekday)
            (#"\bevery\s+(\#(weekdayPattern))\b"#, { match, text in
                guard let dayRange = Range(match.range(at: 1), in: text) else { return nil }
                let dayName = String(text[dayRange]).lowercased()
                let weekday = weekdayNumber(for: dayName)
                return RecurrenceRule(frequency: .weekly, weekdays: [weekday])
            }),

            // "weekly on monday" or "weekly on tuesday"
            (#"\bweekly\s+on\s+(\#(weekdayPattern))\b"#, { match, text in
                guard let dayRange = Range(match.range(at: 1), in: text) else { return nil }
                let dayName = String(text[dayRange]).lowercased()
                let weekday = weekdayNumber(for: dayName)
                return RecurrenceRule(frequency: .weekly, weekdays: [weekday])
            }),

            // "every month on the 15th" or "monthly on the 1st"
            (#"\b(?:every\s+month|monthly)\s+on\s+the\s+(\d{1,2})(?:st|nd|rd|th)?\b"#, { match, text in
                guard let dayRange = Range(match.range(at: 1), in: text) else { return nil }
                let day = Int(text[dayRange]) ?? 1
                return RecurrenceRule(frequency: .monthly, dayOfMonth: day)
            }),

            // Simple keywords: "daily", "weekly", "monthly", "yearly"
            (#"\bdaily\b"#, { _, _ in
                RecurrenceRule(frequency: .daily)
            }),
            (#"\bweekly\b"#, { _, _ in
                RecurrenceRule(frequency: .weekly)
            }),
            (#"\bmonthly\b"#, { _, _ in
                RecurrenceRule(frequency: .monthly)
            }),
            (#"\byearly\b"#, { _, _ in
                RecurrenceRule(frequency: .yearly)
            }),
            (#"\bannually\b"#, { _, _ in
                RecurrenceRule(frequency: .yearly)
            }),

            // "every day"
            (#"\bevery\s+day\b"#, { _, _ in
                RecurrenceRule(frequency: .daily)
            }),
            // "every week"
            (#"\bevery\s+week\b"#, { _, _ in
                RecurrenceRule(frequency: .weekly)
            }),
            // "every month"
            (#"\bevery\s+month\b"#, { _, _ in
                RecurrenceRule(frequency: .monthly)
            }),
            // "every year"
            (#"\bevery\s+year\b"#, { _, _ in
                RecurrenceRule(frequency: .yearly)
            })
        ]

        for (pattern, handler) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) else {
                continue
            }

            if let rule = handler(match, lowercased) {
                result.recurrence = rule

                // Remove matched text from title
                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                break
            }
        }

        return result
    }

    /// Convert weekday name to number (1=Sun, 2=Mon, etc.)
    private static func weekdayNumber(for name: String) -> Int {
        let weekdays: [String: Int] = [
            "sunday": 1, "sun": 1,
            "monday": 2, "mon": 2,
            "tuesday": 3, "tue": 3,
            "wednesday": 4, "wed": 4,
            "thursday": 5, "thu": 5,
            "friday": 6, "fri": 6,
            "saturday": 7, "sat": 7
        ]
        return weekdays[name.lowercased()] ?? 2  // Default to Monday
    }

    // MARK: - Time Range Parsing

    /// Parse time ranges like "2-3pm", "from 2pm to 3pm", "between 1:30pm and 2:30pm"
    private static func parseTimeRange(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let text = result.cleanTitle

        let patterns = [
            // "2-3pm" or "2pm-3pm"
            #"(?:at\s+)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s*[-–—]\s*(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            // "from 2pm to 3pm" or "from 2 to 3pm"
            #"from\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+to\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#,
            // "between 2pm and 3pm"
            #"between\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?\s+and\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            // Extract start time components
            let startHourRange = Range(match.range(at: 1), in: text)!
            var startHour = Int(text[startHourRange]) ?? 0
            let startMinuteRange = match.range(at: 2)
            let startMinute = startMinuteRange.location != NSNotFound
                ? Int(text[Range(startMinuteRange, in: text)!]) ?? 0 : 0
            let startAmPmRange = match.range(at: 3)
            let startAmPm = startAmPmRange.location != NSNotFound
                ? String(text[Range(startAmPmRange, in: text)!]).lowercased() : nil

            // Extract end time components
            let endHourRange = Range(match.range(at: 4), in: text)!
            var endHour = Int(text[endHourRange]) ?? 0
            let endMinuteRange = match.range(at: 5)
            let endMinute = endMinuteRange.location != NSNotFound
                ? Int(text[Range(endMinuteRange, in: text)!]) ?? 0 : 0
            let endAmPmRange = Range(match.range(at: 6), in: text)!
            let endAmPm = String(text[endAmPmRange]).lowercased()

            // Infer start AM/PM from end if not specified
            let effectiveStartAmPm = startAmPm ?? endAmPm

            // Convert to 24-hour format
            startHour = convert12To24Hour(startHour, ampm: effectiveStartAmPm)
            endHour = convert12To24Hour(endHour, ampm: endAmPm)

            // Create times
            let calendar = Calendar.current
            var startComponents = calendar.dateComponents([.year, .month, .day], from: Date())
            startComponents.hour = startHour
            startComponents.minute = startMinute

            var endComponents = startComponents
            endComponents.hour = endHour
            endComponents.minute = endMinute

            if let startTime = calendar.date(from: startComponents),
               let endTime = calendar.date(from: endComponents) {
                result.scheduledTime = startTime
                result.scheduledEndTime = endTime

                // Calculate duration
                result.durationSeconds = Int(endTime.timeIntervalSince(startTime))

                // Remove matched text
                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
            }
            break
        }

        return result
    }

    // MARK: - Duration Parsing

    /// Parse durations like "for 30 minutes", "for 1 hour", "for 1.5 hours"
    private static func parseDuration(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed

        // Skip if we already have a time range
        guard result.durationSeconds == nil else { return result }

        let text = result.cleanTitle

        let patterns = [
            // "for 30 minutes", "for 1 hour", "for 1.5 hours"
            #"for\s+(\d+(?:\.\d+)?)\s*(min(?:ute)?s?|hrs?|hours?)"#,
            // "30 min", "1hr", "2 hours"
            #"(\d+(?:\.\d+)?)\s*(min(?:ute)?s?|hrs?|hours?)(?:\s+long)?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            let valueRange = Range(match.range(at: 1), in: text)!
            let value = Double(text[valueRange]) ?? 0

            let unitRange = Range(match.range(at: 2), in: text)!
            let unit = text[unitRange].lowercased()

            var seconds: Int
            if unit.hasPrefix("min") {
                seconds = Int(value * 60)
            } else {
                seconds = Int(value * 3600)
            }

            result.durationSeconds = seconds

            // Calculate end time if we have a start time
            if let startTime = result.scheduledTime {
                result.scheduledEndTime = startTime.addingTimeInterval(Double(seconds))
            }

            // Remove matched text
            let matchRange = Range(match.range, in: text)!
            result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
            break
        }

        return result
    }

    // MARK: - Date & Time Parsing

    private static func parseDateTime(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed

        // Parse time first (more specific)
        result = parseTime(from: result)

        // Then parse date
        result = parseDate(from: result)

        return result
    }

    /// Parse time from input
    private static func parseTime(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed

        // Skip if we already have a time from range parsing
        guard result.scheduledTime == nil else { return result }

        let text = result.cleanTitle
        let lowercased = text.lowercased()

        // Check for smart time keywords first (noon, morning, etc.)
        for keyword in timeKeywords {
            let pattern = #"\b"# + keyword.keyword + #"\b"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {

                let calendar = Calendar.current
                var components = calendar.dateComponents([.year, .month, .day], from: Date())
                components.hour = keyword.hour
                components.minute = keyword.minute

                result.scheduledTime = calendar.date(from: components)

                // Remove from title (use original text for proper removal)
                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                break
            }
        }

        // If no keyword matched, try time patterns
        if result.scheduledTime == nil {
            let timePatterns = [
                // "at 3pm", "@ 3:30 pm", "3pm"
                (#"(?:at\s+|@\s*)?(\d{1,2})(?::(\d{2}))?\s*(am|pm)"#, "12h"),
                // "at 14:30", "@ 9:15"
                (#"(?:at\s+|@\s*)(\d{1,2}):(\d{2})"#, "24h")
            ]

            for (pattern, format) in timePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                      let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                    continue
                }

                if let time = extractTime(from: text, match: match, format: format) {
                    result.scheduledTime = time

                    // Calculate end time if we have duration
                    if let duration = result.durationSeconds {
                        result.scheduledEndTime = time.addingTimeInterval(Double(duration))
                    }

                    // Remove matched text
                    let matchRange = Range(match.range, in: text)!
                    result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                    break
                }
            }
        }

        return result
    }

    /// Parse date from input
    private static func parseDate(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed

        // Skip if we already have a date
        guard result.dueDate == nil else { return result }

        let text = result.cleanTitle
        let lowercased = text.lowercased()
        let calendar = Calendar.current

        // Order matters - most specific patterns first

        // 1. Relative dates: "in 3 days", "in 2 weeks", "3 days from now"
        let relativePatterns = [
            (#"in\s+(\d+)\s*(day|days|week|weeks|month|months)"#, true),
            (#"(\d+)\s*(day|days|week|weeks|month|months)\s+from\s+now"#, true)
        ]

        for (pattern, _) in relativePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) else {
                continue
            }

            let valueRange = Range(match.range(at: 1), in: lowercased)!
            let value = Int(lowercased[valueRange]) ?? 0

            let unitRange = Range(match.range(at: 2), in: lowercased)!
            let unit = String(lowercased[unitRange])

            let component: Calendar.Component
            if unit.hasPrefix("day") {
                component = .day
            } else if unit.hasPrefix("week") {
                component = .weekOfYear
            } else {
                component = .month
            }

            if let date = calendar.date(byAdding: component, value: value, to: Date()) {
                result.dueDate = calendar.startOfDay(for: date)

                // Remove matched text
                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                return result
            }
        }

        // 2. Absolute dates: "Dec 15", "December 15th", "12/25", "12-25"
        result = parseAbsoluteDate(from: result)
        if result.dueDate != nil { return result }

        // 3. "next" prefix dates: "next friday", "next week", "next month"
        let nextPattern = #"\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|week|month)\b"#
        if let regex = try? NSRegularExpression(pattern: nextPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) {

            let termRange = Range(match.range(at: 1), in: lowercased)!
            let term = String(lowercased[termRange])

            var date: Date?
            if term == "week" {
                date = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
            } else if term == "month" {
                date = calendar.date(byAdding: .month, value: 1, to: Date())
            } else {
                // It's a weekday - get next week's occurrence
                date = nextWeekday(matching: term, forceNextWeek: true)
            }

            if let date = date {
                result.dueDate = calendar.startOfDay(for: date)

                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                return result
            }
        }

        // 4. Simple date keywords with word boundaries
        let dateKeywords: [(pattern: String, offset: Calendar.Component, value: Int)] = [
            (#"\btoday\b"#, .day, 0),
            (#"\btomorrow\b"#, .day, 1),
            (#"\btmr\b"#, .day, 1),
            (#"\bthis\s+weekend\b"#, .day, 0),  // Will be handled specially
            (#"\bend\s+of\s+week\b"#, .day, 0),
            (#"\beow\b"#, .day, 0),
            (#"\bmonday\b"#, .day, 0),
            (#"\btuesday\b"#, .day, 0),
            (#"\bwednesday\b"#, .day, 0),
            (#"\bthursday\b"#, .day, 0),
            (#"\bfriday\b"#, .day, 0),
            (#"\bsaturday\b"#, .day, 0),
            (#"\bsunday\b"#, .day, 0)
        ]

        for keyword in dateKeywords {
            guard let regex = try? NSRegularExpression(pattern: keyword.pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: lowercased, range: NSRange(lowercased.startIndex..., in: lowercased)) else {
                continue
            }

            let matchRange = Range(match.range, in: lowercased)!
            let matchedText = String(lowercased[matchRange]).trimmingCharacters(in: .whitespaces)
            var date: Date

            // Handle special cases
            switch matchedText {
            case "this weekend":
                date = nextWeekday(matching: "saturday", forceNextWeek: false)
            case "end of week", "eow":
                date = nextWeekday(matching: "friday", forceNextWeek: false)
            case let weekday where ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"].contains(weekday):
                date = nextWeekday(matching: weekday, forceNextWeek: false)
            default:
                date = calendar.date(byAdding: keyword.offset, value: keyword.value, to: Date()) ?? Date()
            }

            result.dueDate = calendar.startOfDay(for: date)

            // Remove from original text
            let originalMatchRange = Range(match.range, in: text)!
            result.cleanTitle = text.replacingCharacters(in: originalMatchRange, with: "")
            break
        }

        return result
    }

    /// Parse absolute dates like "Dec 15", "December 15th", "12/25"
    private static func parseAbsoluteDate(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let text = result.cleanTitle
        let calendar = Calendar.current

        // Month name patterns
        let monthNames = "(?:jan(?:uary)?|feb(?:ruary)?|mar(?:ch)?|apr(?:il)?|may|june?|july?|aug(?:ust)?|sep(?:tember)?|oct(?:ober)?|nov(?:ember)?|dec(?:ember)?)"

        let patterns: [(String, Bool)] = [
            // "Dec 15", "December 15th"
            (#"(\#(monthNames))\s+(\d{1,2})(?:st|nd|rd|th)?"#, true),
            // "15 Dec", "15th December"
            (#"(\d{1,2})(?:st|nd|rd|th)?\s+(\#(monthNames))"#, false),
            // "12/25" or "12-25"
            (#"(\d{1,2})[/\-](\d{1,2})(?![/\-]\d)"#, true)  // Month first for US format
        ]

        for (pattern, monthFirst) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            let firstRange = Range(match.range(at: 1), in: text)!
            let secondRange = Range(match.range(at: 2), in: text)!

            let first = String(text[firstRange])
            let second = String(text[secondRange])

            var month: Int?
            var day: Int?

            if monthFirst {
                month = parseMonth(from: first)
                day = Int(second)
            } else {
                day = Int(first)
                month = parseMonth(from: second)
            }

            guard let m = month, let d = day, m >= 1, m <= 12, d >= 1, d <= 31 else {
                continue
            }

            var components = calendar.dateComponents([.year], from: Date())
            components.month = m
            components.day = d

            // If the date is in the past, assume next year
            if let date = calendar.date(from: components) {
                let finalDate: Date
                if date < Date() {
                    finalDate = calendar.date(byAdding: .year, value: 1, to: date) ?? date
                } else {
                    finalDate = date
                }

                result.dueDate = calendar.startOfDay(for: finalDate)

                let matchRange = Range(match.range, in: text)!
                result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
                return result
            }
        }

        return result
    }

    // MARK: - Priority Parsing

    private static func parsePriority(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let text = result.cleanTitle

        for keyword in priorityKeywords {
            guard let regex = try? NSRegularExpression(pattern: keyword.pattern, options: .caseInsensitive),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
                continue
            }

            result.priority = keyword.priority

            // Remove matched text
            let matchRange = Range(match.range, in: text)!
            result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
            break
        }

        return result
    }

    // MARK: - List Parsing

    private static func parseList(from parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let text = result.cleanTitle

        // Look for #hashtag pattern with word boundary
        let pattern = #"#(\w+)"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {

            let tagRange = Range(match.range(at: 1), in: text)!
            result.listHint = String(text[tagRange])

            // Remove the hashtag from title
            let matchRange = Range(match.range, in: text)!
            result.cleanTitle = text.replacingCharacters(in: matchRange, with: "")
        }

        return result
    }

    // MARK: - Smart Date Defaults

    /// Apply smart defaults: if time is set but no date, infer today or tomorrow
    private static func applySmartDateDefaults(to parsed: ParsedTask) -> ParsedTask {
        var result = parsed
        let calendar = Calendar.current

        // If we have a time but no date
        if result.scheduledTime != nil && result.dueDate == nil {
            let now = Date()

            // Get the time components
            let timeComponents = calendar.dateComponents([.hour, .minute], from: result.scheduledTime!)

            // Create a date with today's date and the parsed time
            var todayComponents = calendar.dateComponents([.year, .month, .day], from: now)
            todayComponents.hour = timeComponents.hour
            todayComponents.minute = timeComponents.minute

            if let todayWithTime = calendar.date(from: todayComponents) {
                // If the time has already passed today, use tomorrow
                if todayWithTime < now {
                    result.dueDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
                    // Update scheduled time to tomorrow
                    var tomorrowComponents = calendar.dateComponents([.year, .month, .day],
                        from: calendar.date(byAdding: .day, value: 1, to: now)!)
                    tomorrowComponents.hour = timeComponents.hour
                    tomorrowComponents.minute = timeComponents.minute
                    result.scheduledTime = calendar.date(from: tomorrowComponents)

                    // Update end time if present
                    if let endTime = result.scheduledEndTime {
                        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                        var tomorrowEndComponents = tomorrowComponents
                        tomorrowEndComponents.hour = endComponents.hour
                        tomorrowEndComponents.minute = endComponents.minute
                        result.scheduledEndTime = calendar.date(from: tomorrowEndComponents)
                    }
                } else {
                    result.dueDate = calendar.startOfDay(for: now)
                }
            }
        }

        // If we have a date, ensure scheduled time uses that date
        if let dueDate = result.dueDate, let scheduledTime = result.scheduledTime {
            let timeComponents = calendar.dateComponents([.hour, .minute], from: scheduledTime)
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: dueDate)
            dateComponents.hour = timeComponents.hour
            dateComponents.minute = timeComponents.minute
            result.scheduledTime = calendar.date(from: dateComponents)

            // Update end time if present
            if let endTime = result.scheduledEndTime {
                let endTimeComponents = calendar.dateComponents([.hour, .minute], from: endTime)
                var endDateComponents = dateComponents
                endDateComponents.hour = endTimeComponents.hour
                endDateComponents.minute = endTimeComponents.minute
                result.scheduledEndTime = calendar.date(from: endDateComponents)
            }
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

            var timeText = formatter.string(from: time)

            // Add end time if present
            if let endTime = parsed.scheduledEndTime {
                timeText += " - " + formatter.string(from: endTime)
            }

            suggestions.append(Suggestion(
                type: .time,
                text: timeText,
                icon: "clock"
            ))
        }

        if let durationSeconds = parsed.durationSeconds, parsed.scheduledEndTime == nil || parsed.scheduledTime == nil {
            // Only show duration chip if we don't have a time range already shown
            let durationText = formatDuration(seconds: durationSeconds)
            suggestions.append(Suggestion(
                type: .duration,
                text: durationText,
                icon: "timer"
            ))
        }

        if parsed.priority > 0 {
            let priorityName = Constants.TaskPriority(rawValue: parsed.priority)?.displayName ?? "Priority"
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

        if let recurrence = parsed.recurrence {
            suggestions.append(Suggestion(
                type: .recurrence,
                text: recurrence.displayText,
                icon: "repeat"
            ))
        }

        return suggestions
    }

    // MARK: - Helper Methods

    /// Clean up title by removing extra whitespace
    private static func cleanTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Extract time from regex match
    private static func extractTime(from text: String, match: NSTextCheckingResult, format: String) -> Date? {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())

        if format == "12h" {
            let hourRange = Range(match.range(at: 1), in: text)!
            var hour = Int(text[hourRange]) ?? 0

            let minuteRange = match.range(at: 2)
            let minute = minuteRange.location != NSNotFound
                ? Int(text[Range(minuteRange, in: text)!]) ?? 0 : 0

            let ampmRange = Range(match.range(at: 3), in: text)!
            let ampm = text[ampmRange].lowercased()

            hour = convert12To24Hour(hour, ampm: ampm)

            components.hour = hour
            components.minute = minute
        } else {
            let hourRange = Range(match.range(at: 1), in: text)!
            let hour = Int(text[hourRange]) ?? 0

            let minuteRange = Range(match.range(at: 2), in: text)!
            let minute = Int(text[minuteRange]) ?? 0

            components.hour = hour
            components.minute = minute
        }

        return calendar.date(from: components)
    }

    /// Convert 12-hour format to 24-hour
    private static func convert12To24Hour(_ hour: Int, ampm: String) -> Int {
        if ampm == "pm" && hour != 12 {
            return hour + 12
        } else if ampm == "am" && hour == 12 {
            return 0
        }
        return hour
    }

    /// Get next occurrence of a weekday
    private static func nextWeekday(matching weekdayName: String, forceNextWeek: Bool = false) -> Date {
        let weekdays = [
            "sunday": 1, "monday": 2, "tuesday": 3, "wednesday": 4,
            "thursday": 5, "friday": 6, "saturday": 7
        ]
        guard let targetWeekday = weekdays[weekdayName.lowercased()] else { return Date() }

        let calendar = Calendar.current
        let today = Date()
        let currentWeekday = calendar.component(.weekday, from: today)

        var daysToAdd = targetWeekday - currentWeekday

        if forceNextWeek {
            // Always go to next week
            if daysToAdd <= 0 {
                daysToAdd += 7
            } else {
                daysToAdd += 7
            }
        } else {
            // Go to this week if day hasn't passed, otherwise next week
            if daysToAdd <= 0 {
                daysToAdd += 7
            }
        }

        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }

    /// Parse month from name or number
    private static func parseMonth(from string: String) -> Int? {
        // Try numeric first
        if let num = Int(string), num >= 1, num <= 12 {
            return num
        }

        // Try month names
        let months: [String: Int] = [
            "jan": 1, "january": 1,
            "feb": 2, "february": 2,
            "mar": 3, "march": 3,
            "apr": 4, "april": 4,
            "may": 5,
            "jun": 6, "june": 6,
            "jul": 7, "july": 7,
            "aug": 8, "august": 8,
            "sep": 9, "september": 9,
            "oct": 10, "october": 10,
            "nov": 11, "november": 11,
            "dec": 12, "december": 12
        ]

        return months[string.lowercased()]
    }

    /// Format duration in seconds to human-readable string
    private static func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours) hour\(hours > 1 ? "s" : "")"
        } else {
            return "\(minutes) min"
        }
    }
}
