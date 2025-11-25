//
//  AIUsageTracker.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import Foundation
import Combine

/// Tracks AI tool usage for personalized suggestions
/// Persists to UserDefaults and enables data-driven personalization after threshold
@MainActor
final class AIUsageTracker: ObservableObject {

    // MARK: - Singleton
    static let shared = AIUsageTracker()

    // MARK: - Constants
    private let storageKey = "aiToolUsageStats"
    private let minimumCallsForPersonalization = 50

    // MARK: - Usage Stats Model
    struct ToolUsageStats: Codable, Identifiable {
        var id: String { toolName }
        var toolName: String
        var totalCalls: Int
        var lastUsed: Date

        /// Map tool to suggestion configuration
        var suggestionMapping: SuggestionMapping? {
            SuggestionMapping(rawValue: toolName)
        }
    }

    // MARK: - Suggestion Mapping
    /// Maps tool names to suggestion configurations
    enum SuggestionMapping: String, CaseIterable {
        case createTasks
        case queryTasks
        case completeTask
        case updateTask
        case rescheduleTask
        case deleteTask
        case manageList
        case taskAnalytics
        case focusSession
        case listActions

        var toolName: String { rawValue }

        var suggestionText: String {
            switch self {
            case .createTasks: return "Add a task"
            case .queryTasks: return "What's due today?"
            case .completeTask: return "Mark task done"
            case .updateTask: return "Update a task"
            case .rescheduleTask: return "Reschedule task"
            case .deleteTask: return "Delete a task"
            case .manageList: return "Manage lists"
            case .taskAnalytics: return "My progress"
            case .focusSession: return "Start focus"
            case .listActions: return "What can I do?"
            }
        }

        var icon: String {
            switch self {
            case .createTasks: return "plus.circle"
            case .queryTasks: return "calendar"
            case .completeTask: return "checkmark.circle"
            case .updateTask: return "pencil"
            case .rescheduleTask: return "arrow.uturn.forward"
            case .deleteTask: return "trash"
            case .manageList: return "folder"
            case .taskAnalytics: return "chart.bar"
            case .focusSession: return "timer"
            case .listActions: return "questionmark.circle"
            }
        }

        var prompt: String {
            switch self {
            case .createTasks: return ""  // Opens text field for user input
            case .queryTasks: return "What's due today?"
            case .completeTask: return "Mark as done: "
            case .updateTask: return "Update task: "
            case .rescheduleTask: return "Reschedule: "
            case .deleteTask: return "Delete: "
            case .manageList: return "Manage my lists"
            case .taskAnalytics: return "How am I doing?"
            case .focusSession: return "Start 25-minute focus"
            case .listActions: return "What can you do?"
            }
        }

        /// Determine suggestion type based on prompt
        var suggestionType: SuggestionType {
            // Actions have empty or partial prompts that need user completion
            switch self {
            case .createTasks, .completeTask, .updateTask, .rescheduleTask, .deleteTask:
                return .action
            default:
                return .query
            }
        }

        enum SuggestionType {
            case query
            case action
        }
    }

    // MARK: - Published Properties
    @Published private(set) var usageStats: [ToolUsageStats] = []

    // MARK: - Computed Properties

    /// Total number of tool calls across all tools
    var totalCalls: Int {
        usageStats.reduce(0) { $0 + $1.totalCalls }
    }

    /// Whether we have enough data to enable personalization
    var hasEnoughDataForPersonalization: Bool {
        totalCalls >= minimumCallsForPersonalization
    }

    /// Progress towards personalization threshold (0.0 - 1.0)
    var personalizationProgress: Double {
        min(Double(totalCalls) / Double(minimumCallsForPersonalization), 1.0)
    }

    // MARK: - Initialization

    private init() {
        loadFromStorage()
    }

    // MARK: - Public API

    /// Track a tool call - call this when any AI tool is invoked
    /// - Parameter toolName: The name of the tool (e.g., "createTasks", "queryTasks")
    func trackToolCall(_ toolName: String) {
        if let index = usageStats.firstIndex(where: { $0.toolName == toolName }) {
            // Update existing entry
            usageStats[index].totalCalls += 1
            usageStats[index].lastUsed = Date()
        } else {
            // Create new entry
            usageStats.append(ToolUsageStats(
                toolName: toolName,
                totalCalls: 1,
                lastUsed: Date()
            ))
        }
        saveToStorage()

        #if DEBUG
        print("📊 AIUsageTracker: \(toolName) called (total: \(totalCalls)/\(minimumCallsForPersonalization))")
        #endif
    }

    /// Get top tools sorted by usage frequency
    /// - Parameter limit: Maximum number of tools to return
    /// - Returns: Array of tool stats sorted by usage (most used first)
    func topToolsByUsage(limit: Int = 6) -> [ToolUsageStats] {
        Array(
            usageStats
                .sorted { $0.totalCalls > $1.totalCalls }
                .prefix(limit)
        )
    }

    /// Get usage count for a specific tool
    /// - Parameter toolName: The tool name to query
    /// - Returns: Number of times the tool was called, or 0 if never used
    func usageCount(for toolName: String) -> Int {
        usageStats.first { $0.toolName == toolName }?.totalCalls ?? 0
    }

    /// Reset all usage statistics (for testing or user preference)
    func resetStatistics() {
        usageStats = []
        saveToStorage()

        #if DEBUG
        print("📊 AIUsageTracker: Statistics reset")
        #endif
    }

    // MARK: - Persistence

    private func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return
        }

        do {
            usageStats = try JSONDecoder().decode([ToolUsageStats].self, from: data)
            #if DEBUG
            print("📊 AIUsageTracker: Loaded \(usageStats.count) tool stats (total: \(totalCalls) calls)")
            #endif
        } catch {
            print("⚠️ AIUsageTracker: Failed to decode stats: \(error)")
            usageStats = []
        }
    }

    private func saveToStorage() {
        do {
            let data = try JSONEncoder().encode(usageStats)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("⚠️ AIUsageTracker: Failed to encode stats: \(error)")
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    /// Posted when an AI tool is called - userInfo contains "toolName": String
    static let aiToolCalled = Notification.Name("aiToolCalled")
}
