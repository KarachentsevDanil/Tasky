//
//  GoalEntity+CoreDataProperties.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

internal import CoreData
import Foundation

// MARK: - Core Data Properties
extension GoalEntity {

    @nonobjc class func fetchRequest() -> NSFetchRequest<GoalEntity> {
        return NSFetchRequest<GoalEntity>(entityName: "GoalEntity")
    }

    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var notes: String?
    @NSManaged var targetDate: Date?
    @NSManaged var status: String
    @NSManaged var colorHex: String?
    @NSManaged var iconName: String?
    @NSManaged var createdAt: Date
    @NSManaged var completedAt: Date?
    @NSManaged var sortOrder: Int16
    @NSManaged var tasks: NSSet?
}

// MARK: - Identifiable
extension GoalEntity: Identifiable {

}

// MARK: - Status Enum
enum GoalStatus: String, CaseIterable, Codable {
    case active
    case paused
    case completed
    case abandoned

    var displayName: String {
        switch self {
        case .active: return "Active"
        case .paused: return "Paused"
        case .completed: return "Completed"
        case .abandoned: return "Abandoned"
        }
    }

    var iconName: String {
        switch self {
        case .active: return "target"
        case .paused: return "pause.circle"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .active: return "007AFF"     // Blue
        case .paused: return "FF9500"     // Orange
        case .completed: return "34C759"  // Green
        case .abandoned: return "8E8E93"  // Gray
        }
    }
}

// MARK: - Computed Properties
extension GoalEntity {

    /// Type-safe status access
    var statusEnum: GoalStatus {
        get { GoalStatus(rawValue: status) ?? .active }
        set { status = newValue.rawValue }
    }

    /// Get linked tasks as array
    var linkedTasks: [TaskEntity] {
        guard let tasks = tasks as? Set<TaskEntity> else { return [] }
        return Array(tasks).sorted { $0.createdAt > $1.createdAt }
    }

    /// Count of all linked tasks
    var totalTaskCount: Int {
        linkedTasks.count
    }

    /// Count of completed linked tasks
    var completedTaskCount: Int {
        linkedTasks.filter { $0.isCompleted }.count
    }

    /// Count of pending (not completed) linked tasks
    var pendingTaskCount: Int {
        linkedTasks.filter { !$0.isCompleted }.count
    }

    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard totalTaskCount > 0 else { return 0 }
        return Double(completedTaskCount) / Double(totalTaskCount)
    }

    /// Progress as formatted percentage string
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// Formatted progress string (e.g., "3/10 tasks")
    var progressText: String {
        "\(completedTaskCount)/\(totalTaskCount) tasks"
    }

    /// Check if goal is active
    var isActive: Bool {
        statusEnum == .active
    }

    /// Check if goal is completed
    var isGoalCompleted: Bool {
        statusEnum == .completed
    }

    /// Days until target date (nil if no target)
    var daysUntilTarget: Int? {
        guard let targetDate = targetDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: targetDate).day
        return days
    }

    /// Formatted target date string
    var formattedTargetDate: String? {
        guard let targetDate = targetDate else { return nil }

        let calendar = Calendar.current
        if calendar.isDateInToday(targetDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(targetDate) {
            return "Tomorrow"
        } else {
            return targetDate.formatted(date: .abbreviated, time: .omitted)
        }
    }

    /// Check if goal is overdue (past target date and not completed)
    var isOverdue: Bool {
        guard let targetDate = targetDate, !isGoalCompleted else { return false }
        return targetDate < Date()
    }

    /// Velocity: tasks completed per day over the last 7 days
    var weeklyVelocity: Double {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date())!

        let completedThisWeek = linkedTasks.filter { task in
            guard task.isCompleted, let completedAt = task.completedAt else { return false }
            return completedAt >= weekAgo
        }.count

        return Double(completedThisWeek) / 7.0
    }

    /// Estimated completion date based on current velocity
    var estimatedCompletionDate: Date? {
        guard pendingTaskCount > 0, weeklyVelocity > 0 else { return nil }

        let daysToComplete = Double(pendingTaskCount) / weeklyVelocity
        return Calendar.current.date(byAdding: .day, value: Int(ceil(daysToComplete)), to: Date())
    }

    /// Formatted estimated completion string
    var estimatedCompletionText: String? {
        guard let estimatedDate = estimatedCompletionDate else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "Est. completion: \(formatter.string(from: estimatedDate))"
    }

    /// Days since last progress (task completion)
    var daysSinceProgress: Int? {
        let completedTasks = linkedTasks.filter { $0.isCompleted }
        guard let lastCompleted = completedTasks.compactMap({ $0.completedAt }).max() else {
            return nil
        }

        return Calendar.current.dateComponents([.day], from: lastCompleted, to: Date()).day
    }

    /// Check if goal is neglected (no progress in 7+ days)
    var isNeglected: Bool {
        guard isActive, pendingTaskCount > 0 else { return false }
        guard let daysSince = daysSinceProgress else {
            // No completed tasks yet, check creation date
            let daysSinceCreation = Calendar.current.dateComponents([.day], from: createdAt, to: Date()).day ?? 0
            return daysSinceCreation > 7
        }
        return daysSince > 7
    }
}

// MARK: - Generated accessors for tasks
extension GoalEntity {

    @objc(addTasksObject:)
    @NSManaged func addToTasks(_ value: TaskEntity)

    @objc(removeTasksObject:)
    @NSManaged func removeFromTasks(_ value: TaskEntity)

    @objc(addTasks:)
    @NSManaged func addToTasks(_ values: NSSet)

    @objc(removeTasks:)
    @NSManaged func removeFromTasks(_ values: NSSet)
}
