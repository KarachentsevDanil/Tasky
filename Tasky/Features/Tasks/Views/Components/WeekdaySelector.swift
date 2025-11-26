//
//  WeekdaySelector.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI

/// Recurrence frequency and weekday selection
struct WeekdaySelector: View {

    // MARK: - Properties
    @Binding var isRecurring: Bool
    @Binding var selectedDays: Set<Int>
    @Binding var frequency: RecurrenceFrequency

    // MARK: - Types
    enum RecurrenceFrequency: String, CaseIterable {
        case daily = "Daily"
        case weekly = "Weekly"
        case monthly = "Monthly"

        var icon: String {
            switch self {
            case .daily: return "sun.max"
            case .weekly: return "calendar.badge.clock"
            case .monthly: return "calendar"
            }
        }
    }

    // MARK: - Private
    private let weekdays: [(day: Int, label: String)] = [
        (1, "M"), (2, "T"), (3, "W"), (4, "T"), (5, "F"), (6, "S"), (7, "S")
    ]

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Frequency chips - scrollable to prevent wrapping
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.sm) {
                    ForEach(RecurrenceFrequency.allCases, id: \.rawValue) { freq in
                        frequencyChip(freq)
                    }
                }
            }

            // Weekday selector (only for weekly)
            if frequency == .weekly {
                VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
                    Text("Repeat on")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: Constants.Spacing.sm) {
                        ForEach(weekdays, id: \.day) { day in
                            weekdayCircle(day: day.day, label: day.label)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Frequency Chip
    @ViewBuilder
    private func frequencyChip(_ freq: RecurrenceFrequency) -> some View {
        let isSelected = frequency == freq

        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                if isSelected {
                    // Deselect = no recurrence
                    isRecurring = false
                    selectedDays.removeAll()
                } else {
                    frequency = freq
                    isRecurring = true

                    // Set default days for weekly
                    if freq == .weekly && selectedDays.isEmpty {
                        selectedDays = [1, 2, 3, 4, 5] // Weekdays by default
                    }
                }
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: freq.icon)
                    .font(.system(size: 14, weight: .medium))
                Text(freq.rawValue)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: true, vertical: false)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Weekday Circle
    @ViewBuilder
    private func weekdayCircle(day: Int, label: String) -> some View {
        let isSelected = selectedDays.contains(day)

        Button {
            if isSelected {
                selectedDays.remove(day)
            } else {
                selectedDays.insert(day)
            }
            HapticManager.shared.selectionChanged()
        } label: {
            Text(label)
                .font(.subheadline.weight(.semibold))
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

// MARK: - Recurrence Display Helper
extension WeekdaySelector {
    /// Format recurrence for display
    static func formatRecurrence(isRecurring: Bool, frequency: RecurrenceFrequency, days: Set<Int>) -> String? {
        guard isRecurring else { return nil }

        switch frequency {
        case .daily:
            return "Daily"
        case .weekly:
            if days.count == 7 {
                return "Every day"
            } else if days == Set([1, 2, 3, 4, 5]) {
                return "Weekdays"
            } else if days == Set([6, 7]) {
                return "Weekends"
            } else {
                let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]
                let selected = days.sorted().compactMap { day -> String? in
                    guard day >= 1 && day <= 7 else { return nil }
                    return dayLabels[day - 1]
                }
                return "Weekly: \(selected.joined(separator: ", "))"
            }
        case .monthly:
            return "Monthly"
        }
    }
}

// MARK: - Preview
#Preview("Not Recurring") {
    struct PreviewWrapper: View {
        @State private var isRecurring = false
        @State private var selectedDays: Set<Int> = []
        @State private var frequency: WeekdaySelector.RecurrenceFrequency = .weekly

        var body: some View {
            VStack(spacing: 20) {
                Text("Recurrence: \(WeekdaySelector.formatRecurrence(isRecurring: isRecurring, frequency: frequency, days: selectedDays) ?? "None")")
                    .font(.headline)

                WeekdaySelector(
                    isRecurring: $isRecurring,
                    selectedDays: $selectedDays,
                    frequency: $frequency
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("Weekly Selected") {
    struct PreviewWrapper: View {
        @State private var isRecurring = true
        @State private var selectedDays: Set<Int> = [1, 2, 3, 4, 5]
        @State private var frequency: WeekdaySelector.RecurrenceFrequency = .weekly

        var body: some View {
            WeekdaySelector(
                isRecurring: $isRecurring,
                selectedDays: $selectedDays,
                frequency: $frequency
            )
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
