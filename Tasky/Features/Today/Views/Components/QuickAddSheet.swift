//
//  QuickAddSheet.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// Todoist-style quick add bottom sheet with inline send button
struct QuickAddSheet: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @Binding var isPresented: Bool

    // MARK: - State
    @State private var taskTitle = ""
    @State private var selectedDate: QuickDate = .today
    @State private var selectedPriority: Constants.TaskPriority = .none
    @State private var showRepeatOptions = false
    @State private var selectedRepeatOption: RepeatOption = .none
    @FocusState private var isFocused: Bool
    @StateObject private var voiceManager = VoiceInputManager()

    enum QuickDate: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"

        var icon: String {
            switch self {
            case .today: return "calendar"
            case .tomorrow: return "sun.max"
            }
        }

        var date: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
            }
        }
    }

    enum RepeatOption: String {
        case none = "None"
        case day = "Day"
        case week = "Week"
        case month = "Month"

        var displayName: String {
            switch self {
            case .none: return "None"
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            }
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 20)

            VStack(spacing: Constants.Spacing.md) {
                // Input row with voice and send buttons
                inputRow

                // Quick action chips
                quickActionChips

                // Repeat options (conditional)
                if showRepeatOptions {
                    repeatOptionsView
                }
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.bottom, Constants.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .presentationDetents([.height(showRepeatOptions ? 280 : 214)])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color.white)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                taskTitle = newValue
            }
        }
    }

    // MARK: - Input Row
    private var inputRow: some View {
        HStack(spacing: 8) {
            // Text field
            TextField("Add a task...", text: $taskTitle)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    addTask()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            // Voice button
            Button {
                handleVoiceInput()
            } label: {
                Image(systemName: voiceManager.isRecording ? "waveform" : "mic.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.4, green: 0.5, blue: 0.95), Color(red: 0.5, green: 0.4, blue: 0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Send button
            Button {
                addTask()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
    }

    // MARK: - Quick Action Chips
    private var quickActionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Today chip
                quickChip(
                    icon: "calendar",
                    label: "Today",
                    isSelected: selectedDate == .today
                ) {
                    selectedDate = .today
                    HapticManager.shared.selectionChanged()
                }

                // Tomorrow chip
                quickChip(
                    icon: "sun.max",
                    label: "Tomorrow",
                    isSelected: selectedDate == .tomorrow
                ) {
                    selectedDate = .tomorrow
                    HapticManager.shared.selectionChanged()
                }

                // Repeat chip
                quickChip(
                    icon: "repeat",
                    label: "Repeat",
                    isSelected: showRepeatOptions
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        showRepeatOptions.toggle()
                    }
                    HapticManager.shared.selectionChanged()
                }

                // Priority chip
                priorityChip
            }
        }
        .frame(height: 44)
    }

    // MARK: - Quick Chip
    @ViewBuilder
    private func quickChip(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .blue : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Priority Chip
    private var priorityChip: some View {
        Menu {
            Button {
                selectedPriority = .none
                HapticManager.shared.selectionChanged()
            } label: {
                Label("None", systemImage: selectedPriority == .none ? "checkmark" : "")
            }

            Button {
                selectedPriority = .medium
                HapticManager.shared.selectionChanged()
            } label: {
                Label("Medium", systemImage: selectedPriority == .medium ? "checkmark" : "flag.fill")
            }

            Button {
                selectedPriority = .high
                HapticManager.shared.selectionChanged()
            } label: {
                Label("High", systemImage: selectedPriority == .high ? "checkmark" : "flag.fill")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(selectedPriority == .none ? "Priority" : selectedPriority.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(selectedPriority != .none ? selectedPriority.color : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Repeat Options View
    private var repeatOptionsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repeat every")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            HStack(spacing: 8) {
                repeatOptionButton(.day)
                repeatOptionButton(.week)
                repeatOptionButton(.month)
            }
        }
    }

    // MARK: - Repeat Option Button
    @ViewBuilder
    private func repeatOptionButton(_ option: RepeatOption) -> some View {
        Button {
            selectedRepeatOption = option
            HapticManager.shared.selectionChanged()
        } label: {
            Text(option.displayName)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(selectedRepeatOption == option ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedRepeatOption == option ? Color.blue : Color(.systemGray6))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Methods
    private func handleVoiceInput() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
        } else {
            Task {
                let authorized = await voiceManager.requestAuthorization()
                if authorized {
                    do {
                        try await voiceManager.startRecording()
                    } catch {
                        print("Failed to start recording: \(error)")
                    }
                }
            }
        }
        HapticManager.shared.lightImpact()
    }

    private func addTask() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        Task {
            // Determine if task should be recurring
            let isRecurring = selectedRepeatOption != .none

            await viewModel.createTask(
                title: trimmedTitle,
                dueDate: selectedDate.date,
                priority: selectedPriority.rawValue,
                isRecurring: isRecurring
            )

            await MainActor.run {
                HapticManager.shared.success()
                isPresented = false
                // Reset state
                taskTitle = ""
                selectedDate = .today
                selectedPriority = .none
                showRepeatOptions = false
                selectedRepeatOption = .none
                voiceManager.reset()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QuickAddSheet(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        isPresented: .constant(true)
    )
}
