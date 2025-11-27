//
//  AIChatView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import SwiftUI

/// AI Chat view for task creation via natural language
struct AIChatView: View {

    // MARK: - Properties
    @StateObject private var viewModel: AIChatViewModel
    @StateObject private var voiceInputManager = VoiceInputManager()
    @ObservedObject var taskListViewModel: TaskListViewModel
    @StateObject private var timerViewModel: FocusTimerViewModel
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showingPermissionAlert = false
    @State private var taskToEdit: TaskEntity?
    @State private var showingTaskDetail = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Initialization
    init(dataService: DataService, taskListViewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(dataService: dataService))
        self.taskListViewModel = taskListViewModel
        _timerViewModel = StateObject(wrappedValue: FocusTimerViewModel(dataService: dataService))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                switch viewModel.isAvailable {
                case .none:
                    // Still checking availability - show loading
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.2)
                    Spacer()

                case .some(true):
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Proactive suggestion banner (at top of chat)
                                if let suggestion = viewModel.proactiveSuggestion {
                                    ProactiveSuggestionBanner(
                                        suggestion: suggestion,
                                        onAction: {
                                            viewModel.handleProactiveSuggestionAction(suggestion)
                                        },
                                        onDismiss: {
                                            viewModel.dismissProactiveSuggestion(suggestion)
                                        },
                                        onSnooze: {
                                            viewModel.snoozeProactiveSuggestion(suggestion)
                                        }
                                    )
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }

                                ForEach(viewModel.messages) { message in
                                    // Don't show empty assistant messages (placeholder during streaming)
                                    if !message.content.isEmpty {
                                        MessageBubble(message: message)
                                            .id(message.id)
                                    }
                                }

                                // Typing indicator
                                if viewModel.isTyping {
                                    TypingIndicator()
                                }
                            }
                            .padding()
                        }
                        .onAppear {
                            scrollProxy = proxy
                        }
                        .onChange(of: viewModel.messages.count) {
                            scrollToBottom()
                        }
                    }

                    // Suggestion chips (show when chat has only welcome message)
                    if showSuggestions {
                        SuggestionChipsView(
                            suggestions: viewModel.suggestions,
                            onSuggestionTapped: { suggestion in
                                handleSuggestionTap(suggestion)
                            }
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }

                    Divider()

                    // Input area
                    inputArea

                case .some(false):
                    unavailableView
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isAvailable == true {
                        Menu {
                            Button(role: .destructive) {
                                viewModel.clearChat()
                            } label: {
                                Label("Clear Chat", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .alert("Microphone Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Tasky needs access to your microphone and speech recognition to use voice input. Please enable these permissions in Settings.")
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: Constants.Spacing.sm) {
                    // Undo toast for AI task operations
                    AIUndoToastView(undoManager: viewModel.undoManager)

                    // Task preview card for created tasks
                    if viewModel.showTaskPreview {
                        TaskPreviewCard(
                            createdTasks: viewModel.createdTasksForPreview,
                            onEdit: { taskInfo in
                                if let task = viewModel.getTaskForEditing(taskInfo) {
                                    taskToEdit = task
                                    showingTaskDetail = true
                                }
                                viewModel.dismissTaskPreview()
                            },
                            onUndo: {
                                viewModel.undoCreatedTasks()
                            },
                            onDone: {
                                viewModel.dismissTaskPreview()
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.showTaskPreview)
                    }
                }
                .padding(.bottom, Constants.Spacing.md)
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = taskToEdit {
                    NavigationStack {
                        TaskDetailView(
                            viewModel: taskListViewModel,
                            timerViewModel: timerViewModel,
                            task: task
                        )
                    }
                }
            }
            .task {
                // Load proactive suggestions on view appear
                await viewModel.loadProactiveSuggestion()
            }
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if voiceInputManager.isRecording {
                recordingIndicator
            }

            HStack(spacing: 8) {
                // Text field (matching QuickAddSheet style)
                TextField("Add a task...", text: $inputText)
                    .textFieldStyle(.plain)
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        if canSend { sendMessage() }
                    }
                    .padding(.vertical, 12)
                    .padding(.horizontal, 16)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .onChange(of: voiceInputManager.transcribedText) { oldValue, newValue in
                        if !newValue.isEmpty && oldValue != newValue {
                            inputText = newValue
                        }
                    }

                // Voice button (purple gradient - matching QuickAddSheet)
                Button {
                    toggleVoiceInput()
                } label: {
                    Image(systemName: voiceInputManager.isRecording ? "waveform" : "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.5, blue: 0.95),
                                    Color(red: 0.5, green: 0.4, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isAvailable != true)
                .accessibilityLabel(voiceInputManager.isRecording ? "Stop recording" : "Voice input")
                .accessibilityHint(voiceInputManager.isRecording ? "Tap to stop recording" : "Tap to dictate your task")

                // Send button (blue circle - matching QuickAddSheet)
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.5)
                .accessibilityLabel("Send message")
                .accessibilityHint("Tap to send your message")
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.vertical, Constants.Spacing.md)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Recording Indicator
    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            // Animated recording circle
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                        .scaleEffect(voiceInputManager.isRecording ? 1.5 : 1.0)
                        .opacity(voiceInputManager.isRecording ? 0.0 : 1.0)
                        .animation(reduceMotion ? .none : .easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: voiceInputManager.isRecording)
                )

            Text("Listening...")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)

            Spacer()

            Text(voiceInputManager.transcribedText.isEmpty ? "Speak now" : voiceInputManager.transcribedText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
    }

    // MARK: - Unavailable View
    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            Text("AI Not Available")
                .font(.title2.weight(.bold))

            Text("Apple Intelligence with on-device language models requires:\n• iOS 26 or later\n• Apple Intelligence enabled in Settings\n• Compatible device\n\nYou can still create tasks manually using the + button in other tabs.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Computed Properties
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    /// Show suggestions only when chat has just the welcome message
    private var showSuggestions: Bool {
        viewModel.messages.count <= 1 && !viewModel.suggestions.isEmpty && !viewModel.isLoading
    }

    // MARK: - Methods
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.sendMessage(text)
        inputText = ""
        voiceInputManager.reset()
        isInputFocused = true

        // Scroll to bottom after sending
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            scrollToBottom()
        }
    }

    private func toggleVoiceInput() {
        if voiceInputManager.isRecording {
            // Stop recording
            voiceInputManager.stopRecording()
            HapticManager.shared.lightImpact()

            // Auto-send if we have transcribed text
            if !voiceInputManager.transcribedText.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    sendMessage()
                }
            }
        } else {
            // Start recording
            Task {
                let authorized = await voiceInputManager.requestAuthorization()
                if authorized {
                    do {
                        try await voiceInputManager.startRecording()
                        HapticManager.shared.lightImpact()
                    } catch {
                        print("Failed to start recording: \(error)")
                        showingPermissionAlert = true
                    }
                } else {
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func scrollToBottom() {
        guard let lastMessage = viewModel.messages.last else { return }
        withAnimation(reduceMotion ? .none : .default) {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }

    private func handleSuggestionTap(_ suggestion: SuggestionEngine.Suggestion) {
        HapticManager.shared.lightImpact()

        switch suggestion.type {
        case .query, .contextual:
            // For queries and contextual suggestions, send the prompt directly
            viewModel.sendMessage(suggestion.prompt)
        case .action:
            // For actions, put the prompt in the text field for user to complete
            inputText = suggestion.prompt
            isInputFocused = true
        }
    }
}

// MARK: - Preview
#Preview {
    let dataService = DataService(persistenceController: .preview)
    AIChatView(
        dataService: dataService,
        taskListViewModel: TaskListViewModel(dataService: dataService)
    )
}
