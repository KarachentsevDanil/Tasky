//
//  ContextExtractionService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
internal import CoreData

/// Service for extracting user context from tasks created from any source
/// Runs in background to passively learn from user behavior
@MainActor
class ContextExtractionService {

    // MARK: - Singleton
    static let shared = ContextExtractionService()

    // MARK: - Dependencies
    private let contextService: ContextService
    private let dataService: DataService

    // MARK: - Extraction Patterns

    /// Common person name indicators
    private let personIndicators = [
        "for ", "with ", "from ", "call ", "email ", "meet ", "meeting with ",
        "talk to ", "contact ", "remind ", "ask ", "tell ", "@"
    ]

    /// Common goal indicators
    private let goalIndicators = [
        "fitness", "health", "exercise", "workout", "gym",
        "learn", "study", "course", "class", "practice",
        "save", "budget", "invest", "financial",
        "career", "promotion", "job", "interview",
        "project", "launch", "build", "create",
        "clean", "organize", "declutter",
        "read", "book", "chapter"
    ]

    /// Schedule pattern indicators
    private let scheduleIndicators = [
        "every ", "daily", "weekly", "monthly", "always ",
        "morning", "afternoon", "evening", "night",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"
    ]

    // MARK: - Initialization
    init(contextService: ContextService = .shared, dataService: DataService = DataService()) {
        self.contextService = contextService
        self.dataService = dataService
        setupNotificationObservers()
    }

    // MARK: - Notification Observers

    private func setupNotificationObservers() {
        // Listen for task creation from any source
        NotificationCenter.default.addObserver(
            forName: .taskCreated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let taskId = notification.userInfo?["taskId"] as? UUID {
                    await self?.extractContextFromTaskId(taskId)
                }
            }
        }

        // Listen for AI-created tasks (may have additional metadata)
        NotificationCenter.default.addObserver(
            forName: .aiTasksCreated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let tasks = notification.userInfo?["tasks"] as? [CreatedTaskInfo] {
                    for task in tasks {
                        if let taskId = task.taskEntityId {
                            await self?.extractContextFromTaskId(taskId)
                        }
                    }
                }
            }
        }

        // Listen for task completion
        NotificationCenter.default.addObserver(
            forName: .taskCompleted,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                if let taskId = notification.userInfo?["taskId"] as? UUID {
                    await self?.trackCompletionPattern(taskId: taskId)
                }
            }
        }
    }

    // MARK: - Extraction Methods

    /// Extract context from a task by ID
    func extractContextFromTaskId(_ taskId: UUID) async {
        guard let task = try? dataService.fetchTaskById(taskId) else {
            print("⚠️ ContextExtractionService: Task not found for ID \(taskId)")
            return
        }

        await extractContextFromTask(task)
    }

    /// Extract context from a task entity
    func extractContextFromTask(_ task: TaskEntity) async {
        print("🧠 ContextExtractionService: Analyzing task '\(task.title)'")

        // Extract person mentions
        await extractPersonMentions(from: task)

        // Extract goal alignment
        await extractGoalAlignment(from: task)

        // Extract schedule patterns
        await extractSchedulePatterns(from: task)

        // Extract list preferences
        await extractListPreferences(from: task)
    }

    /// Batch extract from multiple tasks
    func extractContextFromTasks(_ tasks: [TaskEntity]) async {
        for task in tasks {
            await extractContextFromTask(task)
        }
    }

    // MARK: - Person Extraction

    private func extractPersonMentions(from task: TaskEntity) async {
        let text = "\(task.title) \(task.notes ?? "")"
        let lowercased = text.lowercased()

        for indicator in personIndicators {
            if let range = lowercased.range(of: indicator) {
                let afterIndicator = String(text[range.upperBound...])
                if let personName = extractPersonName(from: afterIndicator) {
                    await savePersonContext(name: personName, taskId: task.id)
                }
            }
        }
    }

    private func extractPersonName(from text: String) -> String? {
        // Get the first 1-3 words that look like a name
        let words = text.components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .prefix(3)

        guard let firstWord = words.first else { return nil }

        // Check if it starts with capital letter (likely a name)
        if firstWord.first?.isUppercase == true {
            // Could be "John" or "John Smith" or "John from work"
            var nameParts: [String] = []

            for word in words {
                let cleanWord = word.trimmingCharacters(in: .punctuationCharacters)

                // Stop at prepositions or lowercase words after first
                if nameParts.count > 0 && !cleanWord.first!.isUppercase {
                    break
                }

                // Skip common non-name words
                let skipWords = ["the", "a", "an", "to", "for", "from", "with", "about"]
                if skipWords.contains(cleanWord.lowercased()) {
                    break
                }

                nameParts.append(cleanWord)
            }

            if !nameParts.isEmpty {
                return nameParts.joined(separator: " ")
            }
        }

        return nil
    }

    private func savePersonContext(name: String, taskId: UUID) async {
        do {
            let metadata: [String: Any] = [
                "lastMentionedTaskId": taskId.uuidString
            ]
            try contextService.saveContext(
                category: .person,
                key: name.lowercased(),
                value: name,
                source: .extracted,
                metadata: metadata
            )
            print("🧠 ContextExtractionService: Extracted person '\(name)'")
        } catch {
            print("⚠️ Failed to save person context: \(error)")
        }
    }

    // MARK: - Goal Extraction

    private func extractGoalAlignment(from task: TaskEntity) async {
        let text = "\(task.title) \(task.notes ?? "")".lowercased()
        let listName = task.taskList?.name.lowercased() ?? ""

        for goal in goalIndicators {
            if text.contains(goal) || listName.contains(goal) {
                await saveGoalContext(goal: goal, taskId: task.id)
            }
        }
    }

    private func saveGoalContext(goal: String, taskId: UUID) async {
        do {
            try contextService.saveContext(
                category: .goal,
                key: goal,
                value: "User has tasks related to \(goal)",
                source: .inferred
            )
            print("🧠 ContextExtractionService: Inferred goal '\(goal)'")
        } catch {
            print("⚠️ Failed to save goal context: \(error)")
        }
    }

    // MARK: - Schedule Pattern Extraction

    private func extractSchedulePatterns(from task: TaskEntity) async {
        let text = "\(task.title) \(task.notes ?? "")".lowercased()

        // Check for recurring patterns in text
        for indicator in scheduleIndicators {
            if text.contains(indicator) {
                await saveSchedulePattern(pattern: indicator, task: task)
            }
        }

        // Check if task is recurring
        if task.isRecurring, let recurrenceDays = task.recurrenceDays {
            await saveRecurrencePattern(days: recurrenceDays, task: task)
        }

        // Extract time preference from scheduled time
        if let scheduledTime = task.scheduledTime {
            await saveTimePreference(time: scheduledTime, task: task)
        }
    }

    private func saveSchedulePattern(pattern: String, task: TaskEntity) async {
        do {
            try contextService.saveContext(
                category: .schedule,
                key: "pattern_\(pattern.replacingOccurrences(of: " ", with: "_"))",
                value: "Has tasks with '\(pattern)' pattern",
                source: .inferred
            )
        } catch {
            print("⚠️ Failed to save schedule pattern: \(error)")
        }
    }

    private func saveRecurrencePattern(days: String, task: TaskEntity) async {
        do {
            let metadata: [String: Any] = [
                "scheduleType": "recurringEvent",
                "daysOfWeek": days.components(separatedBy: ",").compactMap { Int($0) }
            ]
            try contextService.saveContext(
                category: .schedule,
                key: "recurring_\(task.title.lowercased().prefix(20))",
                value: "Recurring task: \(task.title)",
                source: .extracted,
                metadata: metadata
            )
        } catch {
            print("⚠️ Failed to save recurrence pattern: \(error)")
        }
    }

    private func saveTimePreference(time: Date, task: TaskEntity) async {
        let hour = Calendar.current.component(.hour, from: time)

        // Categorize time of day
        let timeCategory: String
        switch hour {
        case 5..<9: timeCategory = "early_morning"
        case 9..<12: timeCategory = "morning"
        case 12..<14: timeCategory = "midday"
        case 14..<17: timeCategory = "afternoon"
        case 17..<20: timeCategory = "evening"
        default: timeCategory = "night"
        }

        do {
            if let existing = try contextService.fetchContext(category: .pattern, key: "preferred_time_\(timeCategory)") {
                try contextService.reinforceContext(existing)
            } else {
                let metadata: [String: Any] = [
                    "patternType": "preferredTime",
                    "dataPoints": 1
                ]
                try contextService.saveContext(
                    category: .pattern,
                    key: "preferred_time_\(timeCategory)",
                    value: "Often schedules tasks in the \(timeCategory.replacingOccurrences(of: "_", with: " "))",
                    source: .inferred,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ Failed to save time preference: \(error)")
        }
    }

    // MARK: - List Preference Extraction

    private func extractListPreferences(from task: TaskEntity) async {
        guard let list = task.taskList else { return }

        do {
            let key = "list_usage_\(list.name.lowercased())"
            if let existing = try contextService.fetchContext(category: .preference, key: key) {
                try contextService.reinforceContext(existing)
            } else {
                try contextService.saveContext(
                    category: .preference,
                    key: key,
                    value: "Uses '\(list.name)' list",
                    source: .inferred
                )
            }
        } catch {
            print("⚠️ Failed to save list preference: \(error)")
        }
    }

    // MARK: - Completion Pattern Tracking

    private func trackCompletionPattern(taskId: UUID) async {
        guard let task = try? dataService.fetchTaskById(taskId),
              let completedAt = task.completedAt else { return }

        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: completedAt)
        let weekday = calendar.component(.weekday, from: completedAt)

        // Track hourly completion pattern
        do {
            let hourKey = "completion_hour_\(hour)"
            if let existing = try contextService.fetchContext(category: .pattern, key: hourKey) {
                var metadata = existing.metadataDict ?? [:]
                let dataPoints = (metadata["dataPoints"] as? Int ?? 0) + 1
                metadata["dataPoints"] = dataPoints
                existing.setMetadata(metadata)
                try contextService.reinforceContext(existing)
            } else {
                let metadata: [String: Any] = [
                    "patternType": "productivityPeak",
                    "dataPoints": 1
                ]
                try contextService.saveContext(
                    category: .pattern,
                    key: hourKey,
                    value: "Productive around \(hour):00",
                    source: .inferred,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ Failed to track completion pattern: \(error)")
        }

        // Track weekday pattern
        do {
            let weekdayNames = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let dayKey = "completion_day_\(weekday)"
            if let existing = try contextService.fetchContext(category: .pattern, key: dayKey) {
                var metadata = existing.metadataDict ?? [:]
                let dataPoints = (metadata["dataPoints"] as? Int ?? 0) + 1
                metadata["dataPoints"] = dataPoints
                existing.setMetadata(metadata)
                try contextService.reinforceContext(existing)
            } else {
                let metadata: [String: Any] = [
                    "patternType": "completionHabit",
                    "dataPoints": 1
                ]
                try contextService.saveContext(
                    category: .pattern,
                    key: dayKey,
                    value: "Active on \(weekdayNames[weekday])s",
                    source: .inferred,
                    metadata: metadata
                )
            }
        } catch {
            print("⚠️ Failed to track weekday pattern: \(error)")
        }

        print("🧠 ContextExtractionService: Tracked completion patterns for '\(task.title)'")
    }

    // MARK: - Batch Processing

    /// Process all existing tasks to extract initial context
    /// Should be called once during first launch or settings reset
    func processAllExistingTasks() async {
        guard let allTasks = try? dataService.fetchAllTasks() else { return }

        print("🧠 ContextExtractionService: Processing \(allTasks.count) existing tasks...")

        // Process in batches to avoid overwhelming the system
        let batchSize = 20
        for batch in stride(from: 0, to: allTasks.count, by: batchSize) {
            let endIndex = min(batch + batchSize, allTasks.count)
            let batchTasks = Array(allTasks[batch..<endIndex])

            for task in batchTasks {
                await extractContextFromTask(task)
            }

            // Small delay between batches
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }

        print("🧠 ContextExtractionService: Completed processing all tasks")
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let taskCreated = Notification.Name("taskCreated")
    static let taskCompleted = Notification.Name("taskCompleted")
}
