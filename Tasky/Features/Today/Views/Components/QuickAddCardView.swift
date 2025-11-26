//
//  QuickAddCardView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Quick task input card with add button and advanced options
struct QuickAddCardView: View {
    @Binding var taskTitle: String
    @FocusState.Binding var isFocused: Bool
    let onAdd: () -> Void
    let onShowAdvanced: () -> Void
    let onShowAIChat: () -> Void

    @StateObject private var voiceManager = VoiceInputManager()
    @AppStorage("preferredInputMode") private var preferredMode: InputMode = .type

    @State private var parsedTask: NaturalLanguageParser.ParsedTask?
    @State private var showModeSelector = false
    @State private var currentMode: InputMode = .type
    @State private var currentPlaceholderIndex: Int = 0
    @State private var placeholderTimer: Timer?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Placeholder Examples
    private let placeholderExamples = [
        "Try: Call mom tomorrow at 3pm",
        "Try: Meeting 2-3pm #work",
        "Try: Buy groceries urgent",
        "Try: Report for 2 hours",
        "Try: Dentist Dec 15 at noon"
    ]

    enum InputMode: String, CaseIterable {
        case type
        case voice

        var icon: String {
            switch self {
            case .type: return "keyboard"
            case .voice: return "mic.fill"
            }
        }

        var title: String {
            switch self {
            case .type: return "Type"
            case .voice: return "Voice"
            }
        }

        var color: Color {
            switch self {
            case .type: return .blue
            case .voice: return .green
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Mode selector (shows when showModeSelector is true)
            if showModeSelector {
                modeSelector
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                // Blue + button (clickable to create task)
                Button {
                    if !taskTitle.isEmpty {
                        onAdd()
                    } else {
                        // If empty, focus the text field
                        isFocused = true
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 20, height: 20)

                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add quick task")

                // Main input area
                mainInputArea

                // Mode toggle and advanced options
                HStack(spacing: 4) {
                    // Mode indicator button
                    Button {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showModeSelector.toggle()
                        }
                    } label: {
                        Image(systemName: currentMode.icon)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(currentMode.color)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Change input mode")

                    // Advanced options
                    Button {
                        HapticManager.shared.lightImpact()
                        onShowAdvanced()
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Advanced task options")
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            // NLP Suggestions
            if let parsed = parsedTask, !parsed.suggestions.isEmpty {
                Divider()
                    .padding(.horizontal, 14)

                HStack(spacing: 6) {
                    ForEach(parsed.suggestions) { suggestion in
                        suggestionChip(suggestion)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        .onAppear {
            setupInitialMode()
            startPlaceholderRotation()
        }
        .onDisappear {
            stopPlaceholderRotation()
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        HStack(spacing: 12) {
            ForEach(InputMode.allCases, id: \.self) { mode in
                Button {
                    HapticManager.shared.lightImpact()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        switchToMode(mode)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.caption)
                        Text(mode.title)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(currentMode == mode ? .white : mode.color)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(currentMode == mode ? mode.color : mode.color.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Main Input Area

    @ViewBuilder
    private var mainInputArea: some View {
        switch currentMode {
        case .type:
            typeInputField
        case .voice:
            voiceInputArea
        }
    }

    private var typeInputField: some View {
        TextField(placeholderExamples[currentPlaceholderIndex], text: $taskTitle)
            .focused($isFocused)
            .submitLabel(.done)
            .onSubmit {
                onAdd()
            }
            .onChange(of: taskTitle) { _, newValue in
                if !newValue.isEmpty {
                    stopPlaceholderRotation()
                    parsedTask = NaturalLanguageParser.parse(newValue)
                } else {
                    parsedTask = nil
                    startPlaceholderRotation()
                }
            }
    }

    private var voiceInputArea: some View {
        HStack(spacing: 8) {
            if voiceManager.isRecording {
                // Recording indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)

                    Text(voiceManager.transcribedText.isEmpty ? "Listening..." : voiceManager.transcribedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    stopVoiceRecording()
                } label: {
                    Image(systemName: "stop.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    startVoiceRecording()
                } label: {
                    Text("Tap to speak")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
    }

    // MARK: - Suggestion Chip

    @ViewBuilder
    private func suggestionChip(_ suggestion: NaturalLanguageParser.Suggestion) -> some View {
        HStack(spacing: 4) {
            Image(systemName: suggestion.icon)
                .font(.system(size: 10))
            Text(suggestion.text)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(chipColor(for: suggestion.type))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(chipColor(for: suggestion.type).opacity(0.15))
        )
    }

    private func chipColor(for type: NaturalLanguageParser.Suggestion.SuggestionType) -> Color {
        switch type {
        case .date:
            return .blue
        case .time:
            return .orange
        case .duration:
            return .green
        case .priority:
            return .red
        case .list:
            return .purple
        case .recurrence:
            return .teal
        }
    }

    // MARK: - Mode Switching

    private func switchToMode(_ mode: InputMode) {
        currentMode = mode
        preferredMode = mode

        // Clean up previous mode
        if mode != .voice {
            voiceManager.stopRecording()
        }

        // Always collapse menu when switching modes
        showModeSelector = false

        // Activate new mode
        switch mode {
        case .type:
            // Focus text field for immediate typing
            isFocused = true
        case .voice:
            // Voice mode ready, user will tap "Tap to speak" to start
            break
        }
    }

    // MARK: - Voice Recording

    private func startVoiceRecording() {
        // Close mode selector when starting recording
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showModeSelector = false
        }

        Task {
            let authorized = await voiceManager.requestAuthorization()
            guard authorized else {
                // Show error or permission alert
                return
            }

            do {
                try await voiceManager.startRecording()
                HapticManager.shared.mediumImpact()
            } catch {
                print("Voice recording error: \(error)")
            }
        }
    }

    private func stopVoiceRecording() {
        voiceManager.stopRecording()
        HapticManager.shared.mediumImpact()

        // Transfer transcribed text to taskTitle
        if !voiceManager.transcribedText.isEmpty {
            taskTitle = voiceManager.transcribedText
            voiceManager.reset()

            // Switch back to type mode after successful recording
            currentMode = .type

            // Auto-submit
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onAdd()
            }
        }
    }

    // MARK: - Placeholder Rotation

    private func startPlaceholderRotation() {
        // Don't rotate if user prefers reduced motion
        guard !reduceMotion else { return }
        // Don't start if already running or user has typed something
        guard placeholderTimer == nil, taskTitle.isEmpty else { return }

        placeholderTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                currentPlaceholderIndex = (currentPlaceholderIndex + 1) % placeholderExamples.count
            }
        }
    }

    private func stopPlaceholderRotation() {
        placeholderTimer?.invalidate()
        placeholderTimer = nil
    }

    // MARK: - Lifecycle

    private func setupInitialMode() {
        currentMode = preferredMode
    }
}

// MARK: - Preview Helper
extension QuickAddCardView {
    init(
        taskTitle: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        onAdd: @escaping () -> Void,
        onShowAdvanced: @escaping () -> Void
    ) {
        self._taskTitle = taskTitle
        self._isFocused = isFocused
        self.onAdd = onAdd
        self.onShowAdvanced = onShowAdvanced
        self.onShowAIChat = {}
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var taskTitle = ""
    @Previewable @FocusState var isFocused: Bool

    return QuickAddCardView(
        taskTitle: $taskTitle,
        isFocused: $isFocused,
        onAdd: { print("Add task") },
        onShowAdvanced: { print("Show advanced") }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("With Text") {
    @Previewable @State var taskTitle = "Buy groceries"
    @Previewable @FocusState var isFocused: Bool

    return QuickAddCardView(
        taskTitle: $taskTitle,
        isFocused: $isFocused,
        onAdd: { print("Add task") },
        onShowAdvanced: { print("Show advanced") }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
