//
//  SmartPrioritizeTool.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Foundation
import FoundationModels

/// Notification posted when tasks are prioritized
extension Notification.Name {
    static let aiTasksPrioritized = Notification.Name("aiTasksPrioritized")
}

/// Tool for intelligent task prioritization based on context and patterns
struct SmartPrioritizeTool: Tool {
    let name = "smartPrioritize"

    let description = "Intelligently prioritize tasks based on urgency, importance, user goals, and patterns. Triggers: prioritize, what's most important, what should I focus on, rank my tasks."

    let dataService: DataService
    let contextService: ContextService

    init(dataService: DataService = DataService(), contextService: ContextService = .shared) {
        self.dataService = dataService
        self.contextService = contextService
    }

    @Generable
    struct Arguments {
        @Guide(description: "Scope of prioritization")
        @Guide(.anyOf(["today", "this_week", "all", "list"]))
        let scope: String?

        @Guide(description: "List name if scope is 'list'")
        let listName: String?

        @Guide(description: "Number of top tasks to return")
        let topN: Int?

        @Guide(description: "Factor to prioritize by")
        @Guide(.anyOf(["urgency", "importance", "quick_wins", "goals", "balanced"]))
        let prioritizeBy: String?
    }

    func call(arguments: Arguments) async throws -> GeneratedContent {
        await AIUsageTracker.shared.trackToolCall("smartPrioritize")
        let result = try await executePrioritize(arguments: arguments)
        return GeneratedContent(result)
    }

    @MainActor
    private func executePrioritize(arguments: Arguments) async throws -> String {
        let scope = arguments.scope ?? "today"
        let topN = min(arguments.topN ?? 5, 10)
        let prioritizeBy = arguments.prioritizeBy ?? "balanced"

        // Fetch tasks based on scope
        var tasks: [TaskEntity] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch scope {
        case "today":
            let allTasks = (try? dataService.fetchAllTasks()) ?? []
            tasks = allTasks.filter { task in
                guard !task.isCompleted else { return false }
                if let dueDate = task.dueDate {
                    return dueDate <= calendar.date(byAdding: .day, value: 1, to: today)!
                }
                if let scheduledTime = task.scheduledTime {
                    return calendar.isDateInToday(scheduledTime)
                }
                return false
            }
        case "this_week":
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: today)!
            let allTasks = (try? dataService.fetchAllTasks()) ?? []
            tasks = allTasks.filter { task in
                guard !task.isCompleted else { return false }
                if let dueDate = task.dueDate {
                    return dueDate <= weekEnd
                }
                return false
            }
        case "list":
            if let listName = arguments.listName,
               let list = AIToolHelpers.findList(listName, dataService: dataService) {
                let allTasks = (try? dataService.fetchAllTasks()) ?? []
                tasks = allTasks.filter { !$0.isCompleted && $0.taskList?.id == list.id }
            }
        default: // "all"
            let allTasks = (try? dataService.fetchAllTasks()) ?? []
            tasks = allTasks.filter { !$0.isCompleted }
        }

        guard !tasks.isEmpty else {
            return "No incomplete tasks found for the selected scope."
        }

        // Fetch user context for goals
        var userGoals: [String] = []
        do {
            let goalContext = try contextService.fetchAllContext(category: .goal, minConfidence: 0.3)
            userGoals = goalContext.map { $0.key }
        } catch {
            print("⚠️ Failed to fetch goal context: \(error)")
        }

        // Score and prioritize tasks
        let scoredTasks = tasks.map { task -> (TaskEntity, Double) in
            var score = 0.0

            switch prioritizeBy {
            case "urgency":
                score = calculateUrgencyScore(task, today: today)
            case "importance":
                score = calculateImportanceScore(task)
            case "quick_wins":
                score = calculateQuickWinScore(task)
            case "goals":
                score = calculateGoalAlignmentScore(task, goals: userGoals)
            default: // "balanced"
                let urgency = calculateUrgencyScore(task, today: today)
                let importance = calculateImportanceScore(task)
                let quickWin = calculateQuickWinScore(task)
                let goalAlignment = calculateGoalAlignmentScore(task, goals: userGoals)
                score = (urgency * 0.35) + (importance * 0.30) + (quickWin * 0.15) + (goalAlignment * 0.20)
            }

            return (task, score)
        }

        // Sort by score and take top N
        let prioritized = scoredTasks
            .sorted { $0.1 > $1.1 }
            .prefix(topN)

        // Build response
        let scopeLabel: String
        switch scope {
        case "today": scopeLabel = "today"
        case "this_week": scopeLabel = "this week"
        case "list": scopeLabel = "'\(arguments.listName ?? "list")'"
        default: scopeLabel = "all tasks"
        }

        let strategyLabel: String
        switch prioritizeBy {
        case "urgency": strategyLabel = "most urgent"
        case "importance": strategyLabel = "most important"
        case "quick_wins": strategyLabel = "quick wins"
        case "goals": strategyLabel = "goal-aligned"
        default: strategyLabel = "balanced priority"
        }

        var response = "🎯 **Top \(prioritized.count) tasks for \(scopeLabel)** (\(strategyLabel)):\n\n"

        for (index, (task, score)) in prioritized.enumerated() {
            let rank = index + 1
            let priorityEmoji = AIToolHelpers.priorityEmoji(Int(task.priority))
            let scorePercent = Int(score * 100)

            var details: [String] = []
            if let dueDate = task.dueDate {
                let dueStr = AIToolHelpers.formatRelativeDate(dueDate)
                details.append("due \(dueStr)")
            }
            if task.estimatedDuration > 0 {
                details.append("~\(task.estimatedDuration)m")
            }

            let detailStr = details.isEmpty ? "" : " (\(details.joined(separator: ", ")))"

            response += "\(rank). \(task.title)\(detailStr) \(priorityEmoji)\n"
        }

        // Add suggestion based on top task
        if let topTask = prioritized.first?.0 {
            response += "\n💡 **Suggestion:** Start with \"\(topTask.title)\" - "
            if let dueDate = topTask.dueDate, dueDate < today {
                response += "it's overdue!"
            } else if topTask.priority >= 2 {
                response += "it's high priority."
            } else if topTask.estimatedDuration > 0 && topTask.estimatedDuration <= 15 {
                response += "it's a quick win you can knock out fast."
            } else {
                response += "it has the highest priority score."
            }
        }

        // Post notification
        let taskIds = prioritized.map { $0.0.id }
        NotificationCenter.default.post(
            name: .aiTasksPrioritized,
            object: nil,
            userInfo: [
                "taskIds": taskIds,
                "scope": scope,
                "strategy": prioritizeBy
            ]
        )

        HapticManager.shared.success()

        return response
    }

    // MARK: - Scoring Functions

    private func calculateUrgencyScore(_ task: TaskEntity, today: Date) -> Double {
        guard let dueDate = task.dueDate else { return 0.2 }

        let daysUntilDue = Calendar.current.dateComponents([.day], from: today, to: dueDate).day ?? 0

        if daysUntilDue < 0 { return 1.0 }      // Overdue
        if daysUntilDue == 0 { return 0.95 }   // Due today
        if daysUntilDue == 1 { return 0.85 }   // Due tomorrow
        if daysUntilDue <= 3 { return 0.7 }    // Due within 3 days
        if daysUntilDue <= 7 { return 0.5 }    // Due this week

        return max(0.1, 1.0 - (Double(daysUntilDue) * 0.05))
    }

    private func calculateImportanceScore(_ task: TaskEntity) -> Double {
        // Base score from explicit priority
        let priorityScore: Double
        switch task.priority {
        case 3: priorityScore = 1.0   // High
        case 2: priorityScore = 0.7   // Medium
        case 1: priorityScore = 0.4   // Low
        default: priorityScore = 0.2  // None
        }

        return priorityScore
    }

    private func calculateQuickWinScore(_ task: TaskEntity) -> Double {
        let duration = task.estimatedDuration

        if duration == 0 { return 0.3 }  // Unknown duration
        if duration <= 5 { return 1.0 }  // Very quick
        if duration <= 15 { return 0.85 }
        if duration <= 30 { return 0.6 }
        if duration <= 60 { return 0.4 }

        return 0.2  // Long tasks
    }

    private func calculateGoalAlignmentScore(_ task: TaskEntity, goals: [String]) -> Double {
        guard !goals.isEmpty else { return 0.3 }

        let titleLower = task.title.lowercased()
        let notesLower = (task.notes ?? "").lowercased()

        for goal in goals {
            if titleLower.contains(goal) || notesLower.contains(goal) {
                return 1.0
            }
        }

        // Check if task is in a list that might relate to goals
        if let listName = task.taskList?.name.lowercased() {
            for goal in goals {
                if listName.contains(goal) || goal.contains(listName) {
                    return 0.7
                }
            }
        }

        return 0.2
    }
}
