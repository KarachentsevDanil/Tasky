//
//  SuggestionEngine.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation

/// Engine for generating contextual, data-driven suggestions for AI chat
/// Supports personalization based on user's actual tool usage patterns
@MainActor
class SuggestionEngine {

    // MARK: - Properties
    private let dataService: DataService

    // MARK: - Initialization
    init(dataService: DataService) {
        self.dataService = dataService
    }

    // MARK: - Suggestion Model
    struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let prompt: String
        let icon: String
        let type: SuggestionType

        enum SuggestionType {
            case query      // Questions about tasks
            case action     // Create/modify actions
            case contextual // Time/data-based suggestions
        }
    }

    // MARK: - Generate Suggestions (Main Entry Point)

    func generateSuggestions() async -> [Suggestion] {
        let tracker = AIUsageTracker.shared

        // PERSONALIZED PATH: Use actual user preferences after threshold
        if tracker.hasEnoughDataForPersonalization {
            return await generatePersonalizedSuggestions(tracker: tracker)
        }

        // DEFAULT PATH: Use smart defaults with creation suggestions
        return await generateDefaultSuggestions()
    }

    // MARK: - Personalized Suggestions (50+ calls)

    private func generatePersonalizedSuggestions(tracker: AIUsageTracker) async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // 1. ALWAYS start with urgent data-driven suggestions (regardless of preferences)
        await addOverdueSuggestion(&suggestions)
        await addInboxSuggestion(&suggestions)

        // 2. Add user's top tools by actual usage (up to 4)
        let topTools = tracker.topToolsByUsage(limit: 4)
        for toolStats in topTools {
            guard suggestions.count < 5 else { break }

            if let mapping = toolStats.suggestionMapping {
                // Avoid duplicating urgent suggestions
                let isDuplicate = suggestions.contains { $0.prompt == mapping.prompt }
                guard !isDuplicate else { continue }

                suggestions.append(Suggestion(
                    text: mapping.suggestionText,
                    prompt: mapping.prompt,
                    icon: mapping.icon,
                    type: mapping.suggestionType == .action ? .action : .query
                ))
            }
        }

        // 3. Fill remaining slots with contextual suggestions if needed
        if suggestions.count < 6 {
            addTimeBasedCreationSuggestion(&suggestions)
        }

        return Array(suggestions.prefix(6))
    }

    // MARK: - Default Suggestions (Before 50 calls)

    private func generateDefaultSuggestions() async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // 1. Urgent data-driven suggestions (highest priority)
        await addOverdueSuggestion(&suggestions)
        await addInboxSuggestion(&suggestions)

        // 2. Creation suggestions (NEW - task creation is #1 action)
        addTimeBasedCreationSuggestion(&suggestions)

        // 3. Time-based query suggestions
        addTimeBasedQuerySuggestions(&suggestions)

        // 4. Productivity suggestions (analytics, focus)
        await addProductivitySuggestions(&suggestions)

        // 5. User's lists suggestions
        await addListSuggestions(&suggestions)

        return Array(suggestions.prefix(6))
    }

    // MARK: - Creation Suggestions (NEW)

    /// Add time-appropriate task creation suggestion
    private func addTimeBasedCreationSuggestion(_ suggestions: inout [Suggestion]) {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<12:
            // Morning: Add for today
            suggestions.append(Suggestion(
                text: "Add tasks for today",
                prompt: "Add tasks for today: ",
                icon: "sun.max.fill",
                type: .action
            ))
        case 17..<24, 0..<5:
            // Evening/Night: Add for tomorrow
            suggestions.append(Suggestion(
                text: "Add tasks for tomorrow",
                prompt: "Add tasks for tomorrow: ",
                icon: "moon.fill",
                type: .action
            ))
        default:
            // Afternoon: Generic add
            suggestions.append(Suggestion(
                text: "Add tasks",
                prompt: "Add tasks: ",
                icon: "plus.circle.fill",
                type: .action
            ))
        }
    }

    // MARK: - Data-Driven Suggestions

    private func addInboxSuggestion(_ suggestions: inout [Suggestion]) async {
        do {
            let allTasks = try dataService.fetchAllTasks()
            let inboxTasks = allTasks.filter { $0.taskList == nil && !$0.isCompleted }
            let inboxCount = inboxTasks.count

            if inboxCount > 3 {
                suggestions.append(Suggestion(
                    text: "Complete inbox (\(inboxCount))",
                    prompt: "Complete all inbox tasks",
                    icon: "tray.full.fill",
                    type: .action
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch inbox count: \(error)")
        }
    }

    private func addOverdueSuggestion(_ suggestions: inout [Suggestion]) async {
        do {
            let overdueTasks = try dataService.fetchOverdueTasks()
            let overdueCount = overdueTasks.count

            if overdueCount > 0 {
                suggestions.append(Suggestion(
                    text: "Reschedule overdue (\(overdueCount))",
                    prompt: "Clean up overdue tasks",
                    icon: "exclamationmark.circle.fill",
                    type: .action
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch overdue count: \(error)")
        }
    }

    // MARK: - Time-Based Smart Suggestions

    private func addTimeBasedQuerySuggestions(_ suggestions: inout [Suggestion]) {
        // Only add if we don't have too many suggestions
        guard suggestions.count < 4 else { return }

        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<10:
            // Morning - use planMyDay tool
            suggestions.append(Suggestion(
                text: "Plan my day",
                prompt: "Plan my day",
                icon: "sun.horizon.fill",
                type: .query
            ))
        case 10..<14:
            // Late morning/early afternoon - bulk complete high priority
            suggestions.append(Suggestion(
                text: "Complete urgent tasks",
                prompt: "Complete all high priority tasks",
                icon: "flag.fill",
                type: .action
            ))
        case 14..<17:
            // Afternoon - check what's left
            suggestions.append(Suggestion(
                text: "Show today's plan",
                prompt: "Plan my day",
                icon: "checklist",
                type: .query
            ))
        case 17..<22:
            // Evening - reschedule incomplete to tomorrow
            suggestions.append(Suggestion(
                text: "Move tasks to tomorrow",
                prompt: "Move today's incomplete tasks to tomorrow",
                icon: "moon.stars.fill",
                type: .action
            ))
        default:
            // Late night - already covered by creation suggestion
            break
        }
    }

    // MARK: - Productivity Suggestions

    private func addProductivitySuggestions(_ suggestions: inout [Suggestion]) async {
        // Only add if we don't have too many suggestions already
        guard suggestions.count < 5 else { return }

        do {
            let allTasks = try dataService.fetchAllTasks()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) else { return }

            // Calculate completions this week
            let completedThisWeek = allTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= weekAgo
            }.count

            // On weekends or if active, suggest weekly review
            let weekday = calendar.component(.weekday, from: Date())
            if (weekday == 1 || weekday == 7 || completedThisWeek >= 5) && suggestions.count < 5 {
                suggestions.append(Suggestion(
                    text: "See weekly summary",
                    prompt: "How was my week?",
                    icon: "chart.bar.fill",
                    type: .query
                ))
            }

            // If there are high priority tasks, suggest bulk complete
            let highPriorityTasks = allTasks.filter { !$0.isCompleted && $0.priority >= 2 }
            if highPriorityTasks.count > 1 && suggestions.count < 5 {
                suggestions.append(Suggestion(
                    text: "Complete urgent (\(highPriorityTasks.count))",
                    prompt: "Complete all high priority tasks",
                    icon: "flag.fill",
                    type: .action
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to generate productivity suggestions: \(error)")
        }
    }

    // MARK: - List-Based Suggestions

    private func addListSuggestions(_ suggestions: inout [Suggestion]) async {
        // Only add if we don't have too many suggestions already
        guard suggestions.count < 5 else { return }

        do {
            let lists = try dataService.fetchAllTaskLists()
            let allTasks = try dataService.fetchAllTasks()

            // Find list with most incomplete tasks for bulk completion
            var listWithMostTasks: (name: String, count: Int)?
            for list in lists {
                let incompleteTasks = allTasks.filter { $0.taskList?.id == list.id && !$0.isCompleted }
                if incompleteTasks.count > 2 {
                    if listWithMostTasks == nil || incompleteTasks.count > listWithMostTasks!.count {
                        listWithMostTasks = (list.name, incompleteTasks.count)
                    }
                }
            }

            // Suggest completing tasks in the busiest list
            if let busyList = listWithMostTasks {
                suggestions.append(Suggestion(
                    text: "Complete \(busyList.name) (\(busyList.count))",
                    prompt: "Complete all tasks in \(busyList.name)",
                    icon: "folder.fill",
                    type: .action
                ))
            } else if let firstList = lists.first {
                // Fallback: suggest adding to first list
                suggestions.append(Suggestion(
                    text: "Add tasks to \(firstList.name)",
                    prompt: "Add tasks to \(firstList.name): ",
                    icon: "folder.fill",
                    type: .action
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch lists: \(error)")
        }
    }
}
