//
//  AIChatViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import Foundation
import Combine
import FoundationModels

/// ViewModel for AI chat with task creation capabilities
@MainActor
class AIChatViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isTyping = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var isAvailable = false

    // MARK: - Properties
    private let dataService: DataService
    private var session: LanguageModelSession?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
        checkAvailability()
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
            case .unavailable(let reason):
                isAvailable = false
                addUnavailableMessage(reason: String(describing: reason))
                print("Model unavailable: \(reason)")
            }
        }
    }

    // MARK: - Session Setup
    private func setupSession() {
        session = LanguageModelSession(
            model: SystemLanguageModel.default,
            tools: [CreateTasksTool(dataService: dataService)],
            instructions: """
            You are a helpful AI assistant for Tasky, a task management app.
            Help users create and organize their tasks through natural conversation.

            When users mention things they need to do, use the create_tasks tool.

            IMPORTANT DATE HANDLING:
            - When creating tasks, ALWAYS set the dueDate field
            - If the user doesn't specify a date, set dueDate to TODAY
            - Use ISO 8601 format for all dates: YYYY-MM-DDTHH:MM:SSZ
            - Examples: "2025-11-07T00:00:00Z" for today, "2025-11-08T00:00:00Z" for tomorrow
            - For specific times, use scheduledTime: "2025-11-07T14:30:00Z" for 2:30 PM today
            - Calculate the current date from the system time when generating dates

            Be friendly, concise, and action-oriented.
            Always confirm what tasks were created after using the tool.
            """
        )
    }

    private func addWelcomeMessage() {
        let welcomeMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Hi! I'm your AI task assistant powered by Apple Intelligence. Tell me what you need to do, and I'll help you create tasks.\n\nFor example:\n• \"Create a task to buy groceries\"\n• \"Add workout at 6pm tomorrow\"\n• \"Remind me to call mom on Friday\"",
            timestamp: Date()
        )
        messages.append(welcomeMessage)
    }

    private func addUnavailableMessage(reason: String) {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            content: "Apple Intelligence is not available on this device. Reason: \(reason)\n\nYou can still create tasks manually using the + button.",
            timestamp: Date()
        )
        messages.append(message)
    }

    // MARK: - Send Message
    func sendMessage(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let session = session else {
            handleError(ChatError.sessionNotAvailable)
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
                accumulatedContent = partial.content

                // Update the assistant message with accumulated content
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index].content = accumulatedContent
                }
            }

            // If no content was generated, show a default message
            if accumulatedContent.isEmpty {
                if let index = messages.firstIndex(where: { $0.id == assistantMessageId }) {
                    messages[index].content = "I've processed your request."
                }
            }

        } catch {
            handleError(error)
            // Remove the empty assistant message on error
            messages.removeAll { $0.content.isEmpty && $0.role == .assistant }

            // Add error message
            let errorMsg = ChatMessage(
                id: UUID(),
                role: .assistant,
                content: "Sorry, I encountered an error. Please try again.",
                timestamp: Date()
            )
            messages.append(errorMsg)
        }
    }

    // MARK: - Clear Chat
    func clearChat() {
        messages.removeAll()
        setupSession()
        addWelcomeMessage()
    }

    // MARK: - Error Handling
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
        print("AI Chat Error: \(error.localizedDescription)")
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

    var errorDescription: String? {
        switch self {
        case .sessionNotAvailable:
            return "AI session is not available. Please restart the app."
        }
    }
}
