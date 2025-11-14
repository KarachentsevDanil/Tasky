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
    @State private var inputText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @FocusState private var isInputFocused: Bool
    @State private var showingPermissionAlert = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Initialization
    init(dataService: DataService) {
        _viewModel = StateObject(wrappedValue: AIChatViewModel(dataService: dataService))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isAvailable {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.messages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
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

                    Divider()

                    // Input area
                    inputArea
                } else {
                    unavailableView
                }
            }
            .navigationTitle("AI Assistant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.isAvailable {
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
        }
    }

    // MARK: - Input Area
    private var inputArea: some View {
        VStack(spacing: 0) {
            // Recording indicator
            if voiceInputManager.isRecording {
                recordingIndicator
            }

            HStack(spacing: 12) {
                // Voice input button
                Button {
                    toggleVoiceInput()
                } label: {
                    Image(systemName: voiceInputManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(voiceInputManager.isRecording ? .red : .blue)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!viewModel.isAvailable)

                TextField("Ask me to create tasks...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color(.systemGray6))
                    )
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                    .onChange(of: voiceInputManager.transcribedText) { oldValue, newValue in
                        if !newValue.isEmpty && oldValue != newValue {
                            inputText = newValue
                        }
                    }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? .blue : .gray)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(!canSend)
            }
            .padding()
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
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(message.role == .user ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundStyle(message.role == .user ? .white : .primary)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
            }

            if message.role == .assistant {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Typing Indicator
struct TypingIndicator: View {
    @State private var animationPhase = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .opacity(animationPhase == index ? 1.0 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5))
            )

            Spacer()
        }
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            withAnimation(reduceMotion ? .none : .default) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AIChatView(dataService: DataService(persistenceController: .preview))
}
