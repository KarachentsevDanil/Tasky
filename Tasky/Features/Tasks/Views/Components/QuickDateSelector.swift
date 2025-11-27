//
//  QuickDateSelector.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI

/// Quick date selection chips with optional calendar picker
struct QuickDateSelector: View {

    // MARK: - Properties
    @Binding var selectedDate: Date?
    @Binding var showCalendar: Bool
    var onDateSelected: ((Date?) -> Void)?

    // MARK: - Private State
    @State private var calendarDate: Date = Date()

    // MARK: - Computed Properties
    private var todayDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private var tomorrowDate: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: todayDate) ?? todayDate
    }

    private var threeDaysDate: Date {
        Calendar.current.date(byAdding: .day, value: 3, to: todayDate) ?? todayDate
    }

    private var nextWeekDate: Date {
        Calendar.current.date(byAdding: .weekOfYear, value: 1, to: todayDate) ?? todayDate
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Quick chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.sm) {
                    dateChip("Today", date: todayDate, icon: "sun.max")
                    dateChip("Tomorrow", date: tomorrowDate, icon: "sunrise")
                    dateChip("+3 Days", date: threeDaysDate, icon: "calendar.badge.plus")
                    pickDateChip
                }
            }

            // Calendar picker
            if showCalendar {
                DatePicker(
                    "Select date",
                    selection: $calendarDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .onChange(of: calendarDate) { _, newValue in
                    selectDate(Calendar.current.startOfDay(for: newValue))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }

    // MARK: - Pick Date Chip
    private var pickDateChip: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCalendar.toggle()
            }
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                Text("Pick")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(showCalendar ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(showCalendar ? Color.accentColor : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Date Chip
    @ViewBuilder
    private func dateChip(_ label: String, date: Date, icon: String) -> some View {
        let isSelected = isDateSelected(date)

        Button {
            selectDate(date)
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                Text(label)
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

    // MARK: - Helpers
    private func isDateSelected(_ date: Date?) -> Bool {
        guard let selected = selectedDate else {
            return date == nil
        }
        guard let checkDate = date else {
            return false
        }
        return Calendar.current.isDate(selected, inSameDayAs: checkDate)
    }

    private func selectDate(_ date: Date?) {
        selectedDate = date
        onDateSelected?(date)

        // Hide calendar after selection
        if showCalendar && date != nil {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showCalendar = false
            }
        }
    }
}

// MARK: - Date Display Helper
extension QuickDateSelector {
    /// Format date for display in row value
    static func formatDate(_ date: Date?) -> String? {
        guard let date else { return nil }

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

// MARK: - Preview
#Preview("Quick Date Selector") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = Date()
        @State private var showCalendar = false

        var body: some View {
            VStack(spacing: 20) {
                Text("Selected: \(QuickDateSelector.formatDate(selectedDate) ?? "None")")
                    .font(.headline)

                QuickDateSelector(
                    selectedDate: $selectedDate,
                    showCalendar: $showCalendar
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("With Calendar") {
    struct PreviewWrapper: View {
        @State private var selectedDate: Date? = Date()
        @State private var showCalendar = true

        var body: some View {
            QuickDateSelector(
                selectedDate: $selectedDate,
                showCalendar: $showCalendar
            )
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
