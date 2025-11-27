//
//  UserContextEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

internal import CoreData
import Foundation

// MARK: - Core Data Properties
extension UserContextEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<UserContextEntity> {
        return NSFetchRequest<UserContextEntity>(entityName: "UserContextEntity")
    }

    @NSManaged public var id: UUID
    @NSManaged var category: String
    @NSManaged var key: String
    @NSManaged var value: String
    @NSManaged var confidence: Float
    @NSManaged var source: String
    @NSManaged var createdAt: Date
    @NSManaged var updatedAt: Date
    @NSManaged var lastAccessedAt: Date?
    @NSManaged var accessCount: Int32
    @NSManaged var reinforcementCount: Int32
    @NSManaged var metadata: Data?
}

// MARK: - Identifiable
extension UserContextEntity: Identifiable {

}

// MARK: - Category Enum
enum ContextCategory: String, CaseIterable, Codable {
    case person
    case preference
    case schedule
    case goal
    case constraint
    case pattern
    case other

    var displayName: String {
        switch self {
        case .person: return "People"
        case .preference: return "Preferences"
        case .schedule: return "Schedule"
        case .goal: return "Goals"
        case .constraint: return "Constraints"
        case .pattern: return "Patterns"
        case .other: return "Other"
        }
    }

    var iconName: String {
        switch self {
        case .person: return "person.2.fill"
        case .preference: return "slider.horizontal.3"
        case .schedule: return "calendar"
        case .goal: return "target"
        case .constraint: return "exclamationmark.triangle"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Source Enum
enum ContextSource: String, CaseIterable, Codable {
    case explicit   // User directly said "remember this"
    case extracted  // Parsed from task creation or conversation
    case inferred   // Derived from behavior patterns

    var displayName: String {
        switch self {
        case .explicit: return "You told me"
        case .extracted: return "Learned from tasks"
        case .inferred: return "Inferred pattern"
        }
    }

    var baseConfidence: Float {
        switch self {
        case .explicit: return 0.85
        case .extracted: return 0.50
        case .inferred: return 0.30
        }
    }

    var boostFactor: Float {
        switch self {
        case .explicit: return 0.15
        case .extracted: return 0.10
        case .inferred: return 0.05
        }
    }

    /// Half-life in days for confidence decay
    var halfLifeDays: Double {
        switch self {
        case .explicit: return 180  // 6 months
        case .extracted: return 60  // 2 months
        case .inferred: return 30   // 1 month
        }
    }
}

// MARK: - Computed Properties
extension UserContextEntity {

    /// Type-safe category access
    var categoryEnum: ContextCategory {
        get { ContextCategory(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }

    /// Type-safe source access
    var sourceEnum: ContextSource {
        get { ContextSource(rawValue: source) ?? .extracted }
        set { source = newValue.rawValue }
    }

    /// Calculate effective confidence with decay applied
    /// Formula: effectiveConfidence = storedConfidence × decayFactor
    /// decayFactor = max(0.1, 0.5^(daysSinceUpdate / halfLife))
    var effectiveConfidence: Float {
        let halfLifeDays = sourceEnum.halfLifeDays
        let daysSinceUpdate = Date().timeIntervalSince(updatedAt) / (24 * 3600)
        let decayFactor = max(0.1, pow(0.5, daysSinceUpdate / halfLifeDays))
        return confidence * Float(decayFactor)
    }

    /// Days since last update
    var daysSinceUpdate: Int {
        Int(Date().timeIntervalSince(updatedAt) / (24 * 3600))
    }

    /// Days since last access (or since creation if never accessed)
    var daysSinceAccess: Int {
        let referenceDate = lastAccessedAt ?? createdAt
        return Int(Date().timeIntervalSince(referenceDate) / (24 * 3600))
    }

    /// Whether this context item is considered stale
    var isStale: Bool {
        return effectiveConfidence < 0.1 && daysSinceAccess > 90
    }

    /// Decode metadata as dictionary
    var metadataDict: [String: Any]? {
        guard let data = metadata else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    /// Encode dictionary to metadata
    func setMetadata(_ dict: [String: Any]?) {
        guard let dict = dict else {
            metadata = nil
            return
        }
        metadata = try? JSONSerialization.data(withJSONObject: dict)
    }

    /// Formatted display for UI
    var formattedConfidence: String {
        let percentage = Int(effectiveConfidence * 100)
        return "\(percentage)%"
    }

    /// Short description for prompt injection
    var promptDescription: String {
        switch categoryEnum {
        case .person:
            return "\(key): \(value)"
        case .schedule:
            return "Schedule: \(value)"
        case .goal:
            return "Goal: \(value)"
        case .preference:
            return "Prefers: \(value)"
        case .constraint:
            return "Constraint: \(value)"
        case .pattern:
            return "Pattern: \(value)"
        case .other:
            return "\(key): \(value)"
        }
    }
}

// MARK: - Person Metadata
struct PersonMetadata: Codable {
    var relationship: PersonRelationship?
    var importance: ImportanceLevel?
    var associatedLists: [String]?
    var lastMentionedTaskId: UUID?

    enum PersonRelationship: String, Codable, CaseIterable {
        case manager, colleague, report, client
        case family, friend, partner
        case serviceProvider, other

        var displayName: String {
            switch self {
            case .manager: return "Manager"
            case .colleague: return "Colleague"
            case .report: return "Report"
            case .client: return "Client"
            case .family: return "Family"
            case .friend: return "Friend"
            case .partner: return "Partner"
            case .serviceProvider: return "Service Provider"
            case .other: return "Other"
            }
        }
    }

    enum ImportanceLevel: String, Codable, CaseIterable {
        case high, medium, low

        var displayName: String {
            rawValue.capitalized
        }
    }
}

// MARK: - Schedule Metadata
struct ScheduleMetadata: Codable {
    var scheduleType: ScheduleType?
    var timeReference: String?
    var daysOfWeek: [Int]?
    var isBlocking: Bool?

    enum ScheduleType: String, Codable, CaseIterable {
        case recurringEvent
        case preferredTime
        case blockedTime
        case constraint

        var displayName: String {
            switch self {
            case .recurringEvent: return "Recurring Event"
            case .preferredTime: return "Preferred Time"
            case .blockedTime: return "Blocked Time"
            case .constraint: return "Constraint"
            }
        }
    }
}

// MARK: - Goal Metadata
struct GoalMetadata: Codable {
    var status: GoalStatus?
    var targetDate: String?
    var relatedLists: [String]?
    var relatedKeywords: [String]?

    enum GoalStatus: String, Codable, CaseIterable {
        case active, paused, completed, abandoned

        var displayName: String {
            rawValue.capitalized
        }
    }
}

// MARK: - Pattern Metadata
struct PatternMetadata: Codable {
    var patternType: PatternType?
    var dataPoints: Int
    var lastObserved: Date?
    var hourDistribution: [Int: Int]?  // hour -> count
    var dayDistribution: [Int: Int]?   // weekday -> count

    enum PatternType: String, Codable, CaseIterable {
        case productivityPeak
        case completionHabit
        case taskDuration
        case procrastination

        var displayName: String {
            switch self {
            case .productivityPeak: return "Productivity Peak"
            case .completionHabit: return "Completion Habit"
            case .taskDuration: return "Task Duration"
            case .procrastination: return "Procrastination"
            }
        }
    }
}
