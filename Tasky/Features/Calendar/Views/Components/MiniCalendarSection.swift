//
//  MiniCalendarSection.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Mini calendar component for upcoming view
struct MiniCalendarSection: View {
    @Binding var selectedDate: Date
    @Binding var selectedDateForFiltering: Date?
    let tasks: [TaskEntity]
    let tasksForDate: (Date) -> [TaskEntity]
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var monthDates: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfYear, for: monthInterval.start) else {
            return []
        }

        var dates: [Date?] = []

        for weekOffset in 0..<6 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: monthFirstWeek.start) else {
                continue
            }

            for dayOffset in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) {
                    dates.append(date)
                }
            }
        }

        return dates
    }

    private var weekdaySymbols: [String] {
        AppDateFormatters.shortWeekdaySymbols
    }

    var body: some View {
        VStack(spacing: 16) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(reduceMotion ? .none : .default) {
                        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .accessibilityLabel("Previous month")
                .accessibilityHint("Navigate to the previous month")

                Spacer()

                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)

                Spacer()

                Button {
                    withAnimation(reduceMotion ? .none : .default) {
                        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                    }
                    HapticManager.shared.lightImpact()
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .accessibilityLabel("Next month")
                .accessibilityHint("Navigate to the next month")
            }
            .padding(.horizontal)

            // Weekday headers
            HStack {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(monthDates, id: \.self) { date in
                    if let date = date {
                        miniCalendarDayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(Color(.secondarySystemBackground))
    }

    private func miniCalendarDayCell(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)

        let incompleteTasks = tasksForDate.filter { !$0.isCompleted }
        let incompleteCount = incompleteTasks.count
        let hasCompletedAllTasks = !tasksForDate.isEmpty && incompleteTasks.isEmpty

        return Button {
            withAnimation(reduceMotion ? .none : .default) {
                selectedDate = date
                selectedDateForFiltering = date
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 2) {
                Text(date, format: .dateTime.day())
                    .font(.system(size: 12, weight: isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                    )

                // Task indicators
                if hasCompletedAllTasks {
                    // Green checkmark for all tasks completed
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color.green)
                        )
                } else if incompleteCount > 0 {
                    // Orange circle with task count
                    Text("\(incompleteCount)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 16, height: 16)
                        .background(
                            Circle()
                                .fill(Color.orange)
                        )
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 40)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .accessibilityLabel(calendarDayAccessibilityLabel(for: date, isToday: isToday, isSelected: isSelected, tasksCount: tasksForDate.count, incompleteCount: incompleteCount, hasCompletedAllTasks: hasCompletedAllTasks))
        .accessibilityHint("Select to filter tasks for this date")
        .id(date)
    }

    private func calendarDayAccessibilityLabel(
        for date: Date,
        isToday: Bool,
        isSelected: Bool,
        tasksCount: Int,
        incompleteCount: Int,
        hasCompletedAllTasks: Bool
    ) -> String {
        let dateString = AppDateFormatters.dayMonthFormatter.string(from: date)
        var label = dateString

        if isToday {
            label += ", today"
        }

        if isSelected {
            label += ", selected"
        }

        if hasCompletedAllTasks {
            label += ", all \(tasksCount) tasks completed"
        } else if incompleteCount > 0 {
            label += ", \(incompleteCount) task\(incompleteCount == 1 ? "" : "s")"
        } else {
            label += ", no tasks"
        }

        return label
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()
        @State private var selectedDateForFiltering: Date?

        var body: some View {
            MiniCalendarSection(
                selectedDate: $selectedDate,
                selectedDateForFiltering: $selectedDateForFiltering,
                tasks: [],
                tasksForDate: { _ in [] }
            )
        }
    }

    return PreviewWrapper()
}
