//
//  SuggestionEngine.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation

/// Engine for generating contextual, data-driven suggestions for AI chat
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

    // MARK: - Generate Suggestions
    func generateSuggestions() async -> [Suggestion] {
        var suggestions: [Suggestion] = []

        // Data-driven suggestions (highest priority)
        await addInboxSuggestion(&suggestions)
        await addOverdueSuggestion(&suggestions)

        // Time-based suggestions
        addTimeBasedSuggestions(&suggestions)

        // Productivity suggestions (analytics, focus)
        await addProductivitySuggestions(&suggestions)

        // User's lists suggestions
        await addListSuggestions(&suggestions)

        // Limit to 4 suggestions max
        return Array(suggestions.prefix(4))
    }

    // MARK: - Data-Driven Suggestions

    private func addInboxSuggestion(_ suggestions: inout [Suggestion]) async {
        do {
            let allTasks = try dataService.fetchAllTasks()
            let inboxCount = allTasks.filter { $0.taskList == nil && !$0.isCompleted }.count

            if inboxCount > 3 {
                suggestions.append(Suggestion(
                    text: "Process inbox (\(inboxCount))",
                    prompt: "What's in my inbox?",
                    icon: "tray.full",
                    type: .query
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch inbox count: \(error)")
        }
    }

    private func addOverdueSuggestion(_ suggestions: inout [Suggestion]) async {
        do {
            let allTasks = try dataService.fetchAllTasks()
            let startOfToday = Calendar.current.startOfDay(for: Date())
            let overdueCount = allTasks.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate < startOfToday && !task.isCompleted
            }.count

            if overdueCount > 0 {
                suggestions.append(Suggestion(
                    text: "Review overdue (\(overdueCount))",
                    prompt: "Show my overdue tasks",
                    icon: "exclamationmark.circle",
                    type: .query
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch overdue count: \(error)")
        }
    }

    // MARK: - Time-Based Suggestions

    private func addTimeBasedSuggestions(_ suggestions: inout [Suggestion]) {
        let hour = Calendar.current.component(.hour, from: Date())

        switch hour {
        case 5..<10:
            // Morning - focus on planning
            suggestions.append(Suggestion(
                text: "Plan my day",
                prompt: "What's due today?",
                icon: "sun.horizon",
                type: .query
            ))
        case 10..<14:
            // Late morning/early afternoon - productive time
            suggestions.append(Suggestion(
                text: "High priority tasks",
                prompt: "Show my high priority tasks",
                icon: "flag.fill",
                type: .query
            ))
        case 14..<17:
            // Afternoon
            suggestions.append(Suggestion(
                text: "What's left today?",
                prompt: "What's due today?",
                icon: "checklist",
                type: .query
            ))
        case 17..<22:
            // Evening - plan ahead
            suggestions.append(Suggestion(
                text: "Plan tomorrow",
                prompt: "What's due tomorrow?",
                icon: "moon.stars",
                type: .query
            ))
        default:
            // Late night - quick add
            suggestions.append(Suggestion(
                text: "Add quick task",
                prompt: "",
                icon: "plus.circle",
                type: .action
            ))
        }
    }

    // MARK: - Productivity Suggestions

    private func addProductivitySuggestions(_ suggestions: inout [Suggestion]) async {
        // Only add if we don't have too many suggestions already
        guard suggestions.count < 3 else { return }

        do {
            let allTasks = try dataService.fetchAllTasks()
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

            // Calculate completions this week
            let completedThisWeek = allTasks.filter { task in
                guard let completedAt = task.completedAt else { return false }
                return completedAt >= weekAgo
            }.count

            // If user has been active, suggest analytics
            if completedThisWeek >= 5 {
                suggestions.append(Suggestion(
                    text: "My progress",
                    prompt: "How am I doing today?",
                    icon: "chart.bar",
                    type: .query
                ))
            }

            // Suggest focus session if there are high priority incomplete tasks
            let highPriorityTasks = allTasks.filter { !$0.isCompleted && $0.priority >= 2 }
            if let firstTask = highPriorityTasks.first {
                suggestions.append(Suggestion(
                    text: "Focus time",
                    prompt: "Start 25-minute focus on \(firstTask.title)",
                    icon: "timer",
                    type: .action
                ))
            }

            // Suggest streak check on weekends or after completing tasks
            let weekday = calendar.component(.weekday, from: Date())
            if weekday == 1 || weekday == 7 { // Weekend
                suggestions.append(Suggestion(
                    text: "My streak",
                    prompt: "What's my productivity streak?",
                    icon: "flame",
                    type: .query
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to generate productivity suggestions: \(error)")
        }
    }

    // MARK: - List-Based Suggestions

    private func addListSuggestions(_ suggestions: inout [Suggestion]) async {
        // Only add if we don't have too many suggestions already
        guard suggestions.count < 3 else { return }

        do {
            let lists = try dataService.fetchAllTaskLists()
            // Add up to 1 list suggestion if we have room
            if let firstList = lists.first {
                suggestions.append(Suggestion(
                    text: "Add to \(firstList.name)",
                    prompt: "Add task to \(firstList.name) list: ",
                    icon: "folder",
                    type: .action
                ))
            }
        } catch {
            print("SuggestionEngine: Failed to fetch lists: \(error)")
        }
    }
}
