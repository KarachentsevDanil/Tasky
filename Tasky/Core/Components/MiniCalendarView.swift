//
//  MiniCalendarView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Mini calendar component for date selection
struct MiniCalendarView: View {

    // MARK: - Properties
    @Binding var selectedDate: Date
    let tasks: [TaskEntity]
    let onDateSelected: (Date) -> Void
    @State private var displayedMonth: Date = Date()

    // MARK: - Computed Properties
    private var monthYearText: String {
        AppDateFormatters.monthYearFormatter.string(from: displayedMonth)
    }

    private var weekdaySymbols: [String] {
        AppDateFormatters.veryShortWeekdaySymbols
    }

    private var daysInMonth: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
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
                    // Only include dates that are in the displayed month or within range
                    if calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
                        dates.append(date)
                    } else if dates.count < 7 {
                        // Add empty slots for previous month
                        dates.append(nil)
                    } else if dates.count >= 28 {
                        // Stop after we've shown enough of next month
                        break
                    } else {
                        dates.append(date)
                    }
                }
            }
        }

        return dates
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            // Month navigation
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Text(monthYearText)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button {
                    withAnimation(.spring(response: 0.3)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 8)

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        dayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
        )
        .onAppear {
            displayedMonth = selectedDate
        }
    }

    // MARK: - Day Cell
    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: displayedMonth, toGranularity: .month)

        // Get tasks for this date
        let tasksForDate = tasksForDate(date)
        let completedCount = tasksForDate.filter { $0.isCompleted }.count
        let totalCount = tasksForDate.count
        let allCompleted = completedCount == totalCount && totalCount > 0

        return Button {
            withAnimation(.spring(response: 0.3)) {
                selectedDate = date
                onDateSelected(date)
            }
            HapticManager.shared.selectionChanged()
        } label: {
            ZStack {
                Text(date, format: .dateTime.day())
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .foregroundStyle(
                        isSelected ? .white :
                        isToday ? .red :
                        isCurrentMonth ? .primary : .secondary
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.clear)
                    )
                    .overlay(
                        Circle()
                            .stroke(isToday && !isSelected ? Color.red : Color.clear, lineWidth: 1)
                    )

                // Task indicator dot
                if totalCount > 0 {
                    VStack {
                        Spacer()
                        Circle()
                            .fill(allCompleted ? Color.green : Color.orange)
                            .frame(width: 4, height: 4)
                            .offset(y: -2)
                    }
                    .frame(width: 32, height: 32)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Methods
    private func tasksForDate(_ date: Date) -> [TaskEntity] {
        tasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: date)
            }
            if let scheduledTime = task.scheduledTime {
                return Calendar.current.isDate(scheduledTime, inSameDayAs: date)
            }
            // For inbox tasks (no date), show them only on today
            if task.dueDate == nil && task.scheduledTime == nil && !task.isCompleted {
                return Calendar.current.isDateInToday(date)
            }
            return false
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        MiniCalendarView(selectedDate: .constant(Date()), tasks: []) { date in
            print("Selected: \(date)")
        }
        Spacer()
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
