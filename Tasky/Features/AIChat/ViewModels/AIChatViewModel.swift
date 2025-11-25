//
//  AIChatViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import Foundation
import Combine
import FoundationModels
import SwiftUI

/// ViewModel for AI chat with comprehensive task management capabilities
/// Supports: create, query, complete, update, reschedule, delete, lists, analytics, focus
@MainActor
class AIChatViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isTyping = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isAvailable = false
    @Published var suggestions: [SuggestionEngine.Suggestion] = []
    @Published var createdTasksForPreview: [CreatedTaskInfo] = []
    @Published var showTaskPreview = false

    /// Undo manager for 5-second undo window
    @Published var undoManager = AIUndoManager()

    // MARK: - Properties
    private let dataService: DataService
    private let suggestionEngine: SuggestionEngine
    private var session: LanguageModelSession?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Context Window Management
    /// Estimated token count for current session (4096 limit)
    private var estimatedTokenCount: Int = 0
    /// Token limit threshold to trigger reset (leave buffer for response)
    private let tokenLimit = 3500
    /// Cached system prompt for token calculation
    private var systemPromptCache: String = ""

    /// User preference for showing task preview (read from AppStorage)
    @AppStorage("aiTaskPreview") private var aiTaskPreviewEnabled = true

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
        self.suggestionEngine = SuggestionEngine(dataService: dataService)
        checkAvailability()
        setupNotificationObserver()
    }

    // MARK: - Notification Observers
    private func setupNotificationObserver() {
        // Task created notification
        NotificationCenter.default.publisher(for: .aiTasksCreated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTasksCreated(notification)
            }
            .store(in: &cancellables)

        // Task completed notification
        NotificationCenter.default.publisher(for: .aiTaskCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTaskCompleted(notification)
            }
            .store(in: &cancellables)

        // Task updated notification
        NotificationCenter.default.publisher(for: .aiTaskUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTaskUpdated(notification)
            }
            .store(in: &cancellables)

        // Task rescheduled notification
        NotificationCenter.default.publisher(for: .aiTaskRescheduled)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTaskRescheduled(notification)
            }
            .store(in: &cancellables)

        // Task deleted notification
        NotificationCenter.default.publisher(for: .aiTaskDeleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleTaskDeleted(notification)
            }
            .store(in: &cancellables)
    }

    private func handleTasksCreated(_ notification: Notification) {
        guard let tasks = notification.userInfo?["tasks"] as? [CreatedTaskInfo] else { return }

        // Subtle celebration: success haptic when tasks are created
        HapticManager.shared.success()

        // Show preview if enabled
        if aiTaskPreviewEnabled {
            createdTasksForPreview = tasks
            showTaskPreview = true
        }
    }

    private func handleTaskCompleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let taskId = userInfo["taskId"] as? UUID,
              let taskTitle = userInfo["taskTitle"] as? String,
              let completed = userInfo["completed"] as? Bool,
              let _ = userInfo["previousState"] as? Bool,
              let undoAvailable = userInfo["undoAvailable"] as? Bool,
              undoAvailable else { return }

        let action = AIUndoManager.createCompletionUndo(
            taskId: taskId,
            taskTitle: taskTitle,
            wasCompleted: completed,
            dataService: dataService
        )
        undoManager.registerUndo(action)
    }

    private func handleTaskUpdated(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let taskId = userInfo["taskId"] as? UUID,
              let taskTitle = userInfo["taskTitle"] as? String,
              let previousState = userInfo["previousState"] as? TaskPreviousState,
              let undoAvailable = userInfo["undoAvailable"] as? Bool,
              undoAvailable else { return }

        let action = AIUndoManager.createUpdateUndo(
            taskId: taskId,
            taskTitle: taskTitle,
            previousState: previousState,
            dataService: dataService
        )
        undoManager.registerUndo(action)
    }

    private func handleTaskRescheduled(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let taskId = userInfo["taskId"] as? UUID,
              let taskTitle = userInfo["taskTitle"] as? String,
              let undoAvailable = userInfo["undoAvailable"] as? Bool,
              undoAvailable else { return }

        let previousDueDate = userInfo["previousDueDate"] as? Date
        let previousScheduledTime = userInfo["previousScheduledTime"] as? Date
        let previousScheduledEndTime = userInfo["previousScheduledEndTime"] as? Date

        let action = AIUndoManager.createRescheduleUndo(
            taskId: taskId,
            taskTitle: taskTitle,
            previousDueDate: previousDueDate,
            previousScheduledTime: previousScheduledTime,
            previousScheduledEndTime: previousScheduledEndTime,
            dataService: dataService
        )
        undoManager.registerUndo(action)
    }

    private func handleTaskDeleted(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let deletedInfo = userInfo["deletedTaskInfo"] as? DeletedTaskInfo,
              let undoAvailable = userInfo["undoAvailable"] as? Bool,
              undoAvailable else { return }

        let action = AIUndoManager.createDeleteUndo(
            deletedInfo: deletedInfo,
            dataService: dataService
        )
        undoManager.registerUndo(action)
    }

    // MARK: - Preview Actions

    /// Dismiss the task preview card
    func dismissTaskPreview() {
        showTaskPreview = false
        createdTasksForPreview = []
    }

    /// Undo all tasks shown in preview
    func undoCreatedTasks() {
        for taskInfo in createdTasksForPreview {
            if let taskId = taskInfo.taskEntityId {
                do {
                    try dataService.deleteTaskById(taskId)
                    print("✅ Undone task: \(taskInfo.title)")
                } catch {
                    print("❌ Failed to undo task: \(error)")
                }
            }
        }
        dismissTaskPreview()
    }

    /// Get task entity for editing (returns nil if not found)
    func getTaskForEditing(_ taskInfo: CreatedTaskInfo) -> TaskEntity? {
        guard let taskId = taskInfo.taskEntityId else { return nil }
        return try? dataService.fetchTaskById(taskId)
    }

    // MARK: - Availability Check
    private func checkAvailability() {
        Task {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                isAvailable = true
                setupSession()
                addWelcomeMessage()

            case .unavailable(.modelNotReady):
                isAvailable = false
                addUnavailableMessage(
                    title: "Model Loading",
                    message: "Apple Intelligence is preparing. Please wait a moment and try again.",
                    suggestion: "This usually takes a few seconds on first use."
                )
                print("Model unavailable: modelNotReady")

            case .unavailable(.deviceNotEligible):
                isAvailable = false
                addUnavailableMessage(
                    title: "Device Not Supported",
                    message: "Apple Intelligence requires iPhone 15 Pro or later, iPad with M1 or later, or Mac with Apple Silicon.",
                    suggestion: "You can still create tasks manually using the + button."
                )
                print("Model unavailable: deviceNotEligible")

            case .unavailable(.appleIntelligenceNotEnabled):
                isAvailable = false
                addUnavailableMessage(
                    title: "Apple Intelligence Disabled",
                    message: "Enable Apple Intelligence in Settings > Apple Intelligence & Siri to use AI features.",
                    suggestion: "After enabling, restart the app."
                )
                print("Model unavailable: appleIntelligenceNotEnabled")

            case .unavailable(let reason):
                isAvailable = false
                addUnavailableMessage(
                    title: "AI Not Available",
                    message: "Apple Intelligence is not available on this device.",
                    suggestion: "You can still create tasks manually using the + button."
                )
                print("Model unavailable: \(reason)")
            }
        }
    }

    // MARK: - Session Setup
    private func setupSession() {
        // Fetch available lists for the system prompt
        let listNames = fetchAvailableListNames()
        let listsInfo = listNames.isEmpty ? "Inbox only" : listNames.joined(separator: ", ")

        // Get current date for the prompt
        let todayDateString = ISO8601DateFormatter().string(from: Date())

        // Build and cache system prompt
        systemPromptCache = buildSystemPrompt(todayDate: todayDateString, lists: listsInfo)

        session = LanguageModelSession(
            model: SystemLanguageModel.default,
            tools: [
                // Core task tools
                CreateTasksTool(dataService: dataService),
                QueryTasksTool(dataService: dataService),
                CompleteTaskTool(dataService: dataService),
                UpdateTaskTool(dataService: dataService),
                RescheduleTaskTool(dataService: dataService),
                DeleteTaskTool(dataService: dataService),
                // Organization tools
                ManageListTool(dataService: dataService),
                // Productivity tools
                TaskAnalyticsTool(dataService: dataService),
                FocusSessionTool(dataService: dataService),
                // Help tool
                ListActionsTool()
            ],
            instructions: systemPromptCache
        )

        // Initialize token count with system prompt + tool definitions (~50 tokens per tool)
        estimatedTokenCount = estimateTokens(systemPromptCache) + (10 * 50)

        // Prewarm session for faster first response
        session?.prewarm()
    }

    /// Build optimized system prompt for local LLM
    /// Condensed to ~100 tokens per Apple Foundation Models recommendations
    private func buildSystemPrompt(todayDate: String, lists: String) -> String {
        """
        Role: Task assistant for Tasky.
        Today: \(todayDate)
        Lists: \(lists)

        Rules:
        - Use tools for all actions, never describe
        - Default: priority=medium, list=Inbox, dueDate=today
        - Dates: ISO 8601 (YYYY-MM-DDTHH:MM:SSZ)
        - Keep responses under 2 sentences
        - Match tasks by partial title
        """
    }

    /// Fetch available list names for the system prompt
    private func fetchAvailableListNames() -> [String] {
        do {
            let lists = try dataService.fetchAllTaskLists()
            return lists.compactMap { $0.name }
        } catch {
            print("⚠️ Could not fetch lists for AI prompt: \(error)")
            return []
        }
    }

    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Hi! I'm your AI task assistant. I can help you:\n\n• Create, complete, reschedule, or delete tasks\n• Check what's due and view your progress\n• Manage lists and start focus sessions\n\nTry: \"What's due today?\" or \"Done with groceries\"",
            timestamp: Date()
        )
        messages.append(welcomeMessage)

        // Load suggestions after welcome message
        Task {
            await loadSuggestions()
        }
    }

    // MARK: - Suggestions
    func loadSuggestions() async {
        suggestions = await suggestionEngine.generateSuggestions()
    }

    private func addUnavailableMessage(title: String, message: String, suggestion: String) {
        let chatMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "**\(title)**\n\n\(message)\n\n\(suggestion)",
            timestamp: Date()
        )
        messages.append(chatMessage)
    }

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let session = session else {
            handleError(ChatError.sessionNotAvailable)
            return
        }

        // Check if session is already responding (prevents rate limiting)
        guard !session.isResponding else {
            print("⚠️ Session is already responding, ignoring request")
            return
        }

        // Add user message
        let userMessage = ChatMessage(
            id: UUID(),
            role: .user,
            content: text,
            timestamp: Date()
        )
        messages.append(userMessage)

        // Track token usage
        estimatedTokenCount += estimateTokens(text)

        // Start generating response
        Task {
            await generateResponse(session: session, userMessage: text)
        }
    }

    // MARK: - Generate Response
    private func generateResponse(session: LanguageModelSession, userMessage: String) async {
        isLoading = true
        isTyping = true
        defer {
            isLoading = false
            isTyping = false
        }

        // Check if we need to reset session due to context window limit
        if shouldResetSession() {
            await resetSessionWithSummary()
        }

        do {
            // Create assistant message placeholder
            let assistantMessageId = UUID()
            let assistantMessage = ChatMessage(
                id: assistantMessageId,
                role: .assistant,
                content: "",
                timestamp: Date()
            )
            messages.append(assistantMessage)

            var accumulatedContent = ""

            // Stream the response
            let stream = session.streamResponse(to: userMessage)

            for try await partial in stream {
                let content = partial.content

                // Filter out "null" and empty intermediate values
                guard !content.isEmpty,
                      content.lowercased() != "null",
                      content != "nil" else {
                    continue
                }

                accumulatedContent = content

                // Update the assistant message with accumulated content
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index].content = accumulatedContent
                }
            }

            // If no content was generated, show a default message
            if accumulatedContent.isEmpty || accumulatedContent.lowercased() == "null" {
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index].content = "I've processed your request."
                }
            }

            // Track response tokens
            estimatedTokenCount += estimateTokens(accumulatedContent)

        } catch LanguageModelSession.GenerationError.guardrailViolation {
            // Content triggered safety filters - show generic message
            handleGuardrailViolation()
            removeEmptyAssistantMessages()
            addAssistantMessage("I'm not able to help with that particular request. Could you try rephrasing?")

        } catch LanguageModelSession.GenerationError.rateLimited {
            // Session was busy - should not happen with isResponding check
            handleError(ChatError.rateLimited)
            removeEmptyAssistantMessages()
            addAssistantMessage("I'm still processing your previous request. Please wait a moment.")

        } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
            // Context window exceeded - reset and retry
            removeEmptyAssistantMessages()
            await resetSessionWithSummary()
            addAssistantMessage("I've refreshed our conversation to keep things running smoothly. Could you repeat your last request?")

        } catch let error as LanguageModelSession.ToolCallError {
            // Tool execution failed
            print("❌ Tool call error: \(error.tool) - \(error.underlyingError)")
            handleError(error)
            removeEmptyAssistantMessages()
            addAssistantMessage("I had trouble completing that action. Please try again.")

        } catch {
            // Generic fallback
            handleError(error)
            removeEmptyAssistantMessages()
            addAssistantMessage("Sorry, I encountered an error. Please try again.")
        }
    }

    // MARK: - Context Window Management

    /// Estimate tokens for a given text (~4 chars per token for English)
    private func estimateTokens(_ text: String) -> Int {
        return text.count / 4
    }

    /// Check if session should be reset due to approaching token limit
    private func shouldResetSession() -> Bool {
        return estimatedTokenCount > tokenLimit
    }

    /// Reset session while preserving key context through summarization
    private func resetSessionWithSummary() async {
        // Build summary of key context
        let summary = buildConversationSummary()

        // Recreate session
        setupSession()

        // Prime with summary context if we have meaningful history
        if !summary.isEmpty {
            let primeMessage = "Previous context: \(summary)"
            _ = try? await session?.respond(to: primeMessage)
            estimatedTokenCount = estimateTokens(systemPromptCache) + estimateTokens(primeMessage)
        } else {
            estimatedTokenCount = estimateTokens(systemPromptCache)
        }

        // Notify user subtly
        addSystemMessage("Chat context refreshed to maintain performance.")
    }

    /// Build a brief summary of the conversation for context preservation
    private func buildConversationSummary() -> String {
        // Extract key info from recent assistant messages
        let recentActions = messages.suffix(10)
            .filter { $0.role == .assistant }
            .map { $0.content }
            .joined(separator: " ")

        // Keep it brief (~50 tokens / 200 chars)
        let truncated = String(recentActions.prefix(200))
        return truncated.isEmpty ? "" : truncated
    }

    // MARK: - Helper Methods

    private func removeEmptyAssistantMessages() {
        messages.removeAll { $0.content.isEmpty && $0.role == .assistant }
    }

    private func addAssistantMessage(_ content: String) {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: content,
            timestamp: Date()
        )
        messages.append(message)
    }

    private func addSystemMessage(_ content: String) {
        // System messages appear as assistant messages with special styling
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "ℹ️ \(content)",
            timestamp: Date()
        )
        messages.append(message)
    }

    private func handleGuardrailViolation() {
        HapticManager.shared.warning()
        print("⚠️ Guardrail violation triggered")
    }

    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        estimatedTokenCount = 0  // Reset token count
        setupSession()
        addWelcomeMessage()
    }

    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        // Error haptic feedback
        HapticManager.shared.error()

        // Create user-friendly error message with suggestions
        let (title, message) = formatError(error)
        errorMessage = message
        showError = true
        print("AI Chat Error [\(title)]: \(error.localizedDescription)")
    }

    /// Format error into user-friendly title and message
    private func formatError(_ error: Error) -> (title: String, message: String) {
        if let chatError = error as? ChatError {
            switch chatError {
            case .sessionNotAvailable:
                return (
                    "Session Error",
                    "AI assistant is not available. Please try closing and reopening the app."
                )
            case .rateLimited:
                return (
                    "Rate Limited",
                    "Too many requests. Please wait a moment and try again."
                )
            }
        }

        // Handle common AI/network errors
        let description = error.localizedDescription.lowercased()

        if description.contains("network") || description.contains("connection") {
            return (
                "Connection Error",
                "Unable to connect. Please check your internet connection and try again."
            )
        }

        if description.contains("timeout") {
            return (
                "Timeout",
                "The request took too long. Please try again with a shorter message."
            )
        }

        if description.contains("rate limit") || description.contains("too many") {
            return (
                "Rate Limited",
                "Too many requests. Please wait a moment and try again."
            )
        }

        // Default error message
        return (
            "Error",
            "Something went wrong. Please try again. If the problem persists, restart the app."
        )
    }
}

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    enum Role {
        case user
        case assistant
    }
}

// MARK: - Chat Error
enum ChatError: LocalizedError {
    case sessionNotAvailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "AI session is not available. Please restart the app."
        case .rateLimited:
            return "Too many requests. Please wait a moment."
        }
    }
}
