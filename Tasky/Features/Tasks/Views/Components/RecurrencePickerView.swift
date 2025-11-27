//
//  RecurrencePickerView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI

/// View for selecting recurrence pattern
struct RecurrencePickerView: View {

    @Binding var isRecurring: Bool
    @Binding var pattern: RecurrencePattern

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Recurrence type selector
            recurrenceTypeSection

            if isRecurring {
                // Interval
                intervalSection

                // Type-specific options
                switch pattern.type {
                case .weekly:
                    weekdaySection
                case .monthly:
                    monthlySection
                default:
                    EmptyView()
                }

                // End condition
                endConditionSection
            }
        }
    }

    // MARK: - Recurrence Type Section

    private var recurrenceTypeSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.Spacing.sm) {
                ForEach(RecurrenceType.allCases) { type in
                    RecurrenceTypeChip(
                        type: type,
                        isSelected: isRecurring && pattern.type == type,
                        action: {
                            withAnimation(.spring(response: 0.3)) {
                                if isRecurring && pattern.type == type {
                                    // Deselect - turn off recurrence
                                    isRecurring = false
                                } else {
                                    isRecurring = true
                                    pattern.type = type
                                    // Reset type-specific settings
                                    if type == .weekly && pattern.weekdays.isEmpty {
                                        // Default to current weekday
                                        let weekday = Calendar.current.component(.weekday, from: Date())
                                        let adjustedWeekday = weekday == 1 ? 7 : weekday - 1
                                        pattern.weekdays = [adjustedWeekday]
                                    }
                                    if type == .monthly && pattern.dayOfMonth == 0 {
                                        pattern.dayOfMonth = Int16(Calendar.current.component(.day, from: Date()))
                                    }
                                }
                            }
                            HapticManager.shared.selectionChanged()
                        }
                    )
                }
            }
        }
    }

    // MARK: - Interval Section

    private var intervalSection: some View {
        HStack {
            Text("Every")
                .font(.subheadline)

            Stepper(value: $pattern.interval, in: 1...99) {
                Text("\(pattern.interval)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .monospacedDigit()
            }
            .labelsHidden()
            .frame(width: 120)

            Text(intervalUnit)
                .font(.subheadline)
        }
        .padding(.top, Constants.Spacing.sm)
    }

    private var intervalUnit: String {
        let value = Int(pattern.interval)
        switch pattern.type {
        case .daily:
            return value == 1 ? "day" : "days"
        case .weekly:
            return value == 1 ? "week" : "weeks"
        case .monthly:
            return value == 1 ? "month" : "months"
        case .yearly:
            return value == 1 ? "year" : "years"
        case .afterCompletion:
            return value == 1 ? "day" : "days"
        }
    }

    // MARK: - Weekday Section

    private var weekdaySection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("On")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Spacing.xs) {
                ForEach(1...7, id: \.self) { day in
                    WeekdayButton(
                        day: day,
                        isSelected: pattern.weekdays.contains(day),
                        action: {
                            withAnimation(.spring(response: 0.25)) {
                                if pattern.weekdays.contains(day) {
                                    pattern.weekdays.remove(day)
                                } else {
                                    pattern.weekdays.insert(day)
                                }
                            }
                            HapticManager.shared.selectionChanged()
                        }
                    )
                }
            }

            // Quick presets
            HStack(spacing: Constants.Spacing.sm) {
                WeekdayPresetButton(title: "Weekdays", isSelected: isWeekdaysSelected) {
                    pattern.weekdays = [1, 2, 3, 4, 5]
                }
                WeekdayPresetButton(title: "Weekends", isSelected: isWeekendsSelected) {
                    pattern.weekdays = [6, 7]
                }
                WeekdayPresetButton(title: "Every day", isSelected: isEverydaySelected) {
                    pattern.weekdays = [1, 2, 3, 4, 5, 6, 7]
                }
            }
        }
    }

    private var isWeekdaysSelected: Bool {
        pattern.weekdays == [1, 2, 3, 4, 5]
    }

    private var isWeekendsSelected: Bool {
        pattern.weekdays == [6, 7]
    }

    private var isEverydaySelected: Bool {
        pattern.weekdays == [1, 2, 3, 4, 5, 6, 7]
    }

    // MARK: - Monthly Section

    private var monthlySection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("On")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Day of month picker
            HStack {
                Text("Day")
                    .font(.subheadline)

                Picker("Day", selection: $pattern.dayOfMonth) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)").tag(Int16(day))
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - End Condition Section

    private var endConditionSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Ends")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Spacing.md) {
                EndConditionChip(
                    title: "Never",
                    isSelected: pattern.endDate == nil && pattern.maxOccurrences == 0,
                    action: {
                        pattern.endDate = nil
                        pattern.maxOccurrences = 0
                    }
                )

                EndConditionChip(
                    title: "On date",
                    isSelected: pattern.endDate != nil,
                    action: {
                        pattern.endDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())
                        pattern.maxOccurrences = 0
                    }
                )

                EndConditionChip(
                    title: "After",
                    isSelected: pattern.maxOccurrences > 0,
                    action: {
                        pattern.endDate = nil
                        pattern.maxOccurrences = 10
                    }
                )
            }

            // Show date picker if "On date" selected
            if pattern.endDate != nil {
                DatePicker(
                    "End date",
                    selection: Binding(
                        get: { pattern.endDate ?? Date() },
                        set: { pattern.endDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
            }

            // Show count stepper if "After" selected
            if pattern.maxOccurrences > 0 {
                HStack {
                    Text("After")
                        .font(.subheadline)

                    Stepper(value: Binding(
                        get: { Int(pattern.maxOccurrences) },
                        set: { pattern.maxOccurrences = Int16($0) }
                    ), in: 1...100) {
                        Text("\(pattern.maxOccurrences) times")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .labelsHidden()
                }
            }
        }
        .padding(.top, Constants.Spacing.sm)
    }
}

// MARK: - Supporting Views

struct RecurrenceTypeChip: View {

    let type: RecurrenceType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: type.icon)
                    .font(.system(size: 14))
                Text(type.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }
}

struct WeekdayButton: View {

    let day: Int
    let isSelected: Bool
    let action: () -> Void

    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        Button(action: action) {
            Text(dayLetters[day - 1])
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

struct WeekdayPresetButton: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.selectionChanged()
        }) {
            Text(title)
                .font(.caption)
                .foregroundStyle(isSelected ? .white : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

struct EndConditionChip: View {

    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            action()
            HapticManager.shared.selectionChanged()
        }) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview("Recurrence Picker") {
    struct PreviewWrapper: View {
        @State var isRecurring = true
        @State var pattern = RecurrencePattern(type: .weekly)

        var body: some View {
            RecurrencePickerView(isRecurring: $isRecurring, pattern: $pattern)
                .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Recurrence Picker - Monthly") {
    struct PreviewWrapper: View {
        @State var isRecurring = true
        @State var pattern = RecurrencePattern(type: .monthly)

        var body: some View {
            RecurrencePickerView(isRecurring: $isRecurring, pattern: $pattern)
                .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Not Recurring") {
    struct PreviewWrapper: View {
        @State var isRecurring = false
        @State var pattern = RecurrencePattern()

        var body: some View {
            RecurrencePickerView(isRecurring: $isRecurring, pattern: $pattern)
                .padding()
        }
    }

    return PreviewWrapper()
}
