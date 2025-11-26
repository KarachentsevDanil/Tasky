//
//  QuickAddSheet.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// Enhanced quick add sheet with smart date context and time scheduling
struct QuickAddSheet: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @Binding var isPresented: Bool
    var onShowFullForm: (() -> Void)?
    var preselectedDate: Date?
    var preselectedTime: Date?

    // MARK: - State
    @State private var taskTitle = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedDateOption: DateOption = .today
    @State private var selectedPriority: Constants.TaskPriority = .none
    @State private var showRepeatOptions = false
    @State private var selectedRepeatOption: RepeatOption = .none
    @State private var showTimePicker = false
    @State private var hasScheduledTime = false
    @State private var scheduledStartTime: Date = Date()
    @State private var scheduledEndTime: Date = Date()
    @State private var showDatePicker = false
    @State private var voiceInputError: String?
    @State private var parsedTask: NaturalLanguageParser.ParsedTask?
    @State private var currentPlaceholderIndex: Int = 0
    @State private var placeholderTimer: Timer?
    @FocusState private var isFocused: Bool
    @StateObject private var voiceManager = VoiceInputManager()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Placeholder Examples
    private let placeholderExamples = [
        "Try: Call mom tomorrow at 3pm",
        "Try: Meeting 2-3pm #work",
        "Try: Buy groceries urgent",
        "Try: Report for 2 hours",
        "Try: Dentist Dec 15 at noon"
    ]

    // MARK: - Date Option Enum
    enum DateOption: Equatable {
        case today
        case tomorrow
        case calendar(Date)
        case custom(Date)

        var displayName: String {
            switch self {
            case .today: return "Today"
            case .tomorrow: return "Tomorrow"
            case .calendar(let date):
                return Self.formatShortDate(date)
            case .custom(let date):
                return Self.formatShortDate(date)
            }
        }

        var icon: String {
            switch self {
            case .today: return "sun.max"
            case .tomorrow: return "sunrise"
            case .calendar: return "calendar"
            case .custom: return "calendar.badge.plus"
            }
        }

        var date: Date {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date())) ?? Date()
            case .calendar(let date), .custom(let date):
                return calendar.startOfDay(for: date)
            }
        }

        static func formatShortDate(_ date: Date) -> String {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE, MMM d"
                return formatter.string(from: date)
            }
        }
    }

    // MARK: - Repeat Option Enum
    enum RepeatOption: String, CaseIterable {
        case none = "None"
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var displayName: String { rawValue }

        var icon: String {
            switch self {
            case .none: return "xmark"
            case .daily: return "sun.max"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
            }
        }
    }

    // MARK: - Duration Presets
    private let durationPresets: [(label: String, minutes: Int)] = [
        ("15m", 15),
        ("30m", 30),
        ("1h", 60),
        ("2h", 120)
    ]

    // MARK: - Computed Properties
    private var hasCalendarContext: Bool {
        guard let preselectedDate else { return false }
        let calendar = Calendar.current
        return !calendar.isDateInToday(preselectedDate) && !calendar.isDateInTomorrow(preselectedDate)
    }

    private var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: scheduledStartTime)) - \(formatter.string(from: scheduledEndTime))"
    }

    // MARK: - Initialization
    init(viewModel: TaskListViewModel, isPresented: Binding<Bool>, onShowFullForm: (() -> Void)? = nil, preselectedDate: Date? = nil, preselectedTime: Date? = nil) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self.onShowFullForm = onShowFullForm
        self.preselectedDate = preselectedDate
        self.preselectedTime = preselectedTime

        // Initialize state based on preselected values
        if let preselectedTime {
            _hasScheduledTime = State(initialValue: true)
            _scheduledStartTime = State(initialValue: preselectedTime)
            _scheduledEndTime = State(initialValue: preselectedTime.addingTimeInterval(3600))
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator
            dragIndicator

            VStack(spacing: Constants.Spacing.md) {
                // Input row with voice and send buttons
                inputRow

                // Parsed suggestions (shown when NLP detects something)
                if let parsed = parsedTask, !parsed.suggestions.isEmpty {
                    parsedSuggestionsRow(parsed.suggestions)
                }

                // Date chips row
                dateChipsRow

                // Time section (expandable)
                if showTimePicker {
                    timePickerSection
                }

                // Repeat options (conditional)
                if showRepeatOptions {
                    repeatOptionsView
                }

                // More options button
                if onShowFullForm != nil {
                    moreOptionsButton
                }
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.bottom, Constants.Spacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .presentationDetents([.height(calculateSheetHeight())])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Color(.systemBackground))
        .onAppear {
            setupInitialState()
            startPlaceholderRotation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isFocused = true
            }
        }
        .onDisappear {
            stopPlaceholderRotation()
        }
        .onChange(of: voiceManager.transcribedText) { _, newValue in
            if !newValue.isEmpty {
                taskTitle = newValue
            }
        }
        .onChange(of: taskTitle) { _, newValue in
            // Stop placeholder rotation when user starts typing
            if !newValue.isEmpty {
                stopPlaceholderRotation()
                let parsed = NaturalLanguageParser.parse(newValue)
                parsedTask = parsed
                applyParsedValues(parsed)
            } else {
                parsedTask = nil
                // Resume rotation when field is cleared
                startPlaceholderRotation()
            }
        }
        .sheet(isPresented: $showDatePicker) {
            customDatePickerSheet
        }
        .alert("Voice Input Error", isPresented: .constant(voiceInputError != nil)) {
            Button("OK") {
                voiceInputError = nil
            }
        } message: {
            if let error = voiceInputError {
                Text(error)
            }
        }
    }

    // MARK: - Drag Indicator
    private var dragIndicator: some View {
        RoundedRectangle(cornerRadius: 2.5)
            .fill(Color(.systemGray4))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, 20)
    }

    // MARK: - Input Row
    private var inputRow: some View {
        HStack(spacing: 8) {
            // Text field with rotating placeholder
            TextField(placeholderExamples[currentPlaceholderIndex], text: $taskTitle)
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
            .accessibilityLabel(voiceManager.isRecording ? "Stop recording" : "Voice input")
            .accessibilityHint(voiceManager.isRecording ? "Tap to stop recording" : "Tap to dictate your task")

            // Send button
            Button {
                addTask()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            .accessibilityLabel("Add task")
            .accessibilityHint("Tap to create this task")
        }
    }

    // MARK: - Date Chips Row
    private var dateChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Calendar date chip (if from calendar context)
                if hasCalendarContext, let calendarDate = preselectedDate {
                    dateChip(
                        option: .calendar(calendarDate),
                        isSelected: selectedDateOption == .calendar(calendarDate)
                    ) {
                        selectedDateOption = .calendar(calendarDate)
                        selectedDate = calendarDate
                    }
                }

                // Today chip
                dateChip(
                    option: .today,
                    isSelected: selectedDateOption == .today
                ) {
                    selectedDateOption = .today
                    selectedDate = DateOption.today.date
                }

                // Tomorrow chip
                dateChip(
                    option: .tomorrow,
                    isSelected: selectedDateOption == .tomorrow
                ) {
                    selectedDateOption = .tomorrow
                    selectedDate = DateOption.tomorrow.date
                }

                // Custom date chip
                Button {
                    showDatePicker = true
                    HapticManager.shared.lightImpact()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                        if case .custom = selectedDateOption {
                            Text(DateOption.formatShortDate(selectedDate))
                                .font(.system(size: 15, weight: .medium))
                        } else {
                            Text("Pick date")
                                .font(.system(size: 15, weight: .medium))
                        }
                    }
                    .foregroundStyle(isCustomDateSelected ? Color.accentColor : .primary)
                    .chipStyle(isSelected: isCustomDateSelected)
                }
                .buttonStyle(.plain)

                // Time chip
                timeChip

                // Repeat chip
                quickChip(
                    icon: "repeat",
                    label: selectedRepeatOption == .none ? "Repeat" : selectedRepeatOption.displayName,
                    isSelected: showRepeatOptions || selectedRepeatOption != .none
                ) {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
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

    // MARK: - Date Chip
    @ViewBuilder
    private func dateChip(option: DateOption, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(option.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .chipStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Chip
    private var timeChip: some View {
        Button {
            withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                showTimePicker.toggle()
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: hasScheduledTime ? "clock.fill" : "clock")
                    .font(.system(size: 14, weight: .semibold))
                if hasScheduledTime {
                    Text(formatShortTime(scheduledStartTime))
                        .font(.system(size: 15, weight: .medium))
                } else {
                    Text("Time")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .foregroundStyle(showTimePicker || hasScheduledTime ? Color.accentColor : .primary)
            .chipStyle(isSelected: showTimePicker || hasScheduledTime)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Time Picker Section
    private var timePickerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with toggle
            HStack {
                Text("Schedule time")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if hasScheduledTime {
                    Button {
                        withAnimation {
                            hasScheduledTime = false
                        }
                        HapticManager.shared.lightImpact()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove scheduled time")
                }
            }

            // Duration presets
            HStack(spacing: 8) {
                ForEach(durationPresets, id: \.minutes) { preset in
                    durationPresetButton(label: preset.label, minutes: preset.minutes)
                }
            }

            // Time pickers (shown when time is set)
            if hasScheduledTime {
                VStack(spacing: 8) {
                    HStack {
                        Text("Start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        DatePicker("", selection: $scheduledStartTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .onChange(of: scheduledStartTime) { _, newValue in
                                // Ensure end time is always after start time
                                if scheduledEndTime <= newValue {
                                    scheduledEndTime = newValue.addingTimeInterval(1800) // +30 min
                                }
                            }

                        Spacer()
                    }

                    HStack {
                        Text("End")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        DatePicker("", selection: $scheduledEndTime, in: scheduledStartTime.addingTimeInterval(900)..., displayedComponents: .hourAndMinute)
                            .labelsHidden()

                        Spacer()
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Duration Preset Button
    private func durationPresetButton(label: String, minutes: Int) -> some View {
        Button {
            let now = roundToNearest15(Date())
            scheduledStartTime = now
            scheduledEndTime = now.addingTimeInterval(TimeInterval(minutes * 60))
            withAnimation {
                hasScheduledTime = true
            }
            HapticManager.shared.selectionChanged()
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
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
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .chipStyle(isSelected: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Priority Chip
    private var priorityChip: some View {
        Menu {
            ForEach([Constants.TaskPriority.none, .medium, .high], id: \.rawValue) { priority in
                Button {
                    selectedPriority = priority
                    HapticManager.shared.selectionChanged()
                } label: {
                    Label(
                        priority == .none ? "None" : priority.displayName,
                        systemImage: selectedPriority == priority ? "checkmark" : (priority == .none ? "" : "flag.fill")
                    )
                }
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
            .chipStyle(isSelected: selectedPriority != .none)
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
                ForEach([RepeatOption.daily, .weekly, .monthly], id: \.rawValue) { option in
                    repeatOptionButton(option)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Repeat Option Button
    private func repeatOptionButton(_ option: RepeatOption) -> some View {
        Button {
            if selectedRepeatOption == option {
                selectedRepeatOption = .none
            } else {
                selectedRepeatOption = option
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: option.icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(option.displayName)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(selectedRepeatOption == option ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(selectedRepeatOption == option ? Color.accentColor : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - More Options Button
    private var moreOptionsButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            isPresented = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onShowFullForm?()
            }
        } label: {
            HStack(spacing: Constants.Spacing.xs) {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.medium))
                Text("More options")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.sm)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More options")
        .accessibilityHint("Opens full task creation form with all options")
    }

    // MARK: - Parsed Suggestions Row
    @ViewBuilder
    private func parsedSuggestionsRow(_ suggestions: [NaturalLanguageParser.Suggestion]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(suggestions) { suggestion in
                    parsedSuggestionChip(suggestion)
                }
            }
        }
        .frame(height: 28)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    @ViewBuilder
    private func parsedSuggestionChip(_ suggestion: NaturalLanguageParser.Suggestion) -> some View {
        HStack(spacing: 4) {
            Image(systemName: suggestion.icon)
                .font(.system(size: 10))
            Text(suggestion.text)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(suggestionChipColor(for: suggestion.type))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(suggestionChipColor(for: suggestion.type).opacity(0.15))
        )
    }

    private func suggestionChipColor(for type: NaturalLanguageParser.Suggestion.SuggestionType) -> Color {
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
        }
    }

    // MARK: - Apply Parsed Values
    private func applyParsedValues(_ parsed: NaturalLanguageParser.ParsedTask) {
        // Apply parsed date
        if let date = parsed.dueDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                selectedDateOption = .today
            } else if calendar.isDateInTomorrow(date) {
                selectedDateOption = .tomorrow
            } else {
                selectedDateOption = .custom(date)
            }
            selectedDate = date
        }

        // Apply parsed time and end time
        if let time = parsed.scheduledTime {
            scheduledStartTime = time

            // Use parsed end time if available, otherwise calculate from duration or default to 1 hour
            if let endTime = parsed.scheduledEndTime {
                scheduledEndTime = endTime
            } else if let durationSeconds = parsed.durationSeconds {
                scheduledEndTime = time.addingTimeInterval(Double(durationSeconds))
            } else {
                scheduledEndTime = time.addingTimeInterval(3600) // Default 1 hour
            }

            hasScheduledTime = true
            showTimePicker = true
        }

        // Apply parsed priority
        if parsed.priority > 0 {
            selectedPriority = Constants.TaskPriority(rawValue: parsed.priority) ?? .none
        }
    }

    // MARK: - Custom Date Picker Sheet
    private var customDatePickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick date buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.Spacing.sm) {
                        quickDatePickerButton(label: "Today", date: Date())
                        quickDatePickerButton(label: "Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                        quickDatePickerButton(label: "+3 Days", date: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date())
                        quickDatePickerButton(label: "Next Week", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Constants.Spacing.sm)
                }

                Divider()

                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            selectedDate = newDate
                            selectedDateOption = .custom(newDate)
                            showDatePicker = false
                            HapticManager.shared.selectionChanged()
                        }
                    ),
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Select Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func quickDatePickerButton(label: String, date: Date) -> some View {
        Button {
            selectedDate = date
            selectedDateOption = .custom(date)
            showDatePicker = false
            HapticManager.shared.lightImpact()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                .padding(.horizontal, Constants.Spacing.md)
                .padding(.vertical, Constants.Spacing.sm)
                .background(
                    Capsule()
                        .fill(Calendar.current.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Properties
    private var isCustomDateSelected: Bool {
        if case .custom = selectedDateOption {
            return true
        }
        return false
    }

    // MARK: - Sheet Height Calculation
    private func calculateSheetHeight() -> CGFloat {
        var height: CGFloat = 214 // Base height
        if let parsed = parsedTask, !parsed.suggestions.isEmpty {
            height += 44 // Suggestions row
        }
        if showTimePicker {
            height += hasScheduledTime ? 180 : 100
        }
        if showRepeatOptions {
            height += 80
        }
        if onShowFullForm != nil {
            height += 44
        }
        return height
    }

    // MARK: - Setup Initial State
    private func setupInitialState() {
        // Set initial date based on context
        if let preselectedDate {
            let calendar = Calendar.current
            if calendar.isDateInToday(preselectedDate) {
                selectedDateOption = .today
                selectedDate = DateOption.today.date
            } else if calendar.isDateInTomorrow(preselectedDate) {
                selectedDateOption = .tomorrow
                selectedDate = DateOption.tomorrow.date
            } else {
                selectedDateOption = .calendar(preselectedDate)
                selectedDate = preselectedDate
            }
        } else {
            selectedDateOption = .today
            selectedDate = DateOption.today.date
        }

        // Set initial time if provided
        if let preselectedTime {
            hasScheduledTime = true
            scheduledStartTime = roundToNearest15(preselectedTime)
            scheduledEndTime = scheduledStartTime.addingTimeInterval(3600)
            showTimePicker = true
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

    // MARK: - Helper Methods
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
                        await MainActor.run {
                            voiceInputError = "Unable to start voice input. Please check your microphone permissions in Settings."
                        }
                    }
                } else {
                    await MainActor.run {
                        voiceInputError = "Voice input requires microphone and speech recognition permissions. Please enable them in Settings."
                    }
                }
            }
        }
        HapticManager.shared.lightImpact()
    }

    private func addTask() {
        // Use cleaned title from parser if available, otherwise use raw input
        let cleanedTitle = parsedTask?.cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            ?? taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        Task {
            let finalDate = selectedDate
            let startTime = hasScheduledTime ? combineDateAndTime(date: finalDate, time: scheduledStartTime) : nil
            let endTime = hasScheduledTime ? combineDateAndTime(date: finalDate, time: scheduledEndTime) : nil

            await viewModel.createTask(
                title: cleanedTitle,
                dueDate: finalDate,
                scheduledTime: startTime,
                scheduledEndTime: endTime,
                priority: selectedPriority.rawValue,
                isRecurring: selectedRepeatOption != .none
            )

            await MainActor.run {
                HapticManager.shared.success()
                isPresented = false
                resetState()
            }
        }
    }

    private func resetState() {
        taskTitle = ""
        selectedDateOption = .today
        selectedDate = DateOption.today.date
        selectedPriority = .none
        showRepeatOptions = false
        selectedRepeatOption = .none
        showTimePicker = false
        hasScheduledTime = false
        parsedTask = nil
        voiceManager.reset()
    }

    private func roundToNearest15(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let roundedMinute = ((minute + 7) / 15) * 15
        var newComponents = components
        newComponents.minute = roundedMinute % 60
        if roundedMinute >= 60 {
            newComponents.hour = (components.hour ?? 0) + 1
        }
        return calendar.date(from: newComponents) ?? date
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }

    private func formatShortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Chip Style Modifier
extension View {
    func chipStyle(isSelected: Bool) -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
    }
}

// MARK: - Preview
#Preview("Default") {
    QuickAddSheet(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        isPresented: .constant(true)
    )
}

#Preview("With Calendar Date") {
    QuickAddSheet(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        isPresented: .constant(true),
        preselectedDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())
    )
}

#Preview("With Time") {
    QuickAddSheet(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        isPresented: .constant(true),
        preselectedTime: Date()
    )
}
