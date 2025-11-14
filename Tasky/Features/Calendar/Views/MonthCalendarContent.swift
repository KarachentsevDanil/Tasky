//
//  MonthCalendarContent.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Month view content showing calendar grid with tasks
struct MonthCalendarContent: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel
    @Binding var selectedDate: Date

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
        let formatter = DateFormatter()
        return formatter.shortWeekdaySymbols
    }

    private var isCurrentMonth: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .month)
    }

    private var selectedDayTasks: [TaskEntity] {
        tasksForDate(selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Month Navigation
                monthNavigationHeader

                // Calendar Grid
                VStack(spacing: 16) {
                    // Weekday Headers
                    weekdayHeaders

                    // Calendar Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                        ForEach(monthDates, id: \.self) { date in
                            if let date = date {
                                monthDayCell(for: date)
                            } else {
                                Color.clear
                                    .frame(height: 80)
                            }
                        }
                    }
                }
                .padding()

                // Selected Day Tasks
                if !selectedDayTasks.isEmpty {
                    selectedDayTasksSection
                }
            }
        }
    }

    // MARK: - Month Navigation Header
    private var monthNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate, format: .dateTime.month(.wide).year())
                    .font(.headline)

                if isCurrentMonth {
                    Text("This Month")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Weekday Headers
    private var weekdayHeaders: some View {
        HStack {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Month Day Cell
    private func monthDayCell(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isCurrentMonth = Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month)

        // Calculate task status for this date
        let completedCount = tasksForDate.filter { $0.isCompleted }.count
        let totalCount = tasksForDate.count
        let allCompleted = completedCount == totalCount && totalCount > 0

        return Button {
            withAnimation {
                selectedDate = date
            }
            HapticManager.shared.selectionChanged()
        } label: {
            VStack(spacing: 6) {
                Text(date, format: .dateTime.day())
                    .font(.body.weight(isToday ? .bold : .regular))
                    .foregroundStyle(
                        isToday ? .blue :
                        isCurrentMonth ? .primary : .secondary
                    )

                // Task status indicator
                if totalCount > 0 {
                    ZStack {
                        // Background circle
                        Circle()
                            .fill(allCompleted ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .frame(width: 20, height: 20)

                        // Count or checkmark
                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(totalCount - completedCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isToday ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .id(date)
    }

    // MARK: - Selected Day Tasks Section
    private var selectedDayTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(selectedDate, format: .dateTime.weekday(.wide).month().day())
                    .font(.title2.weight(.bold))

                Spacer()

                Text("\(selectedDayTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ForEach(selectedDayTasks) { task in
                ModernTaskCardView(task: task) {
                    Task {
                        await viewModel.toggleTaskCompletion(task)
                        HapticManager.shared.success()
                    }
                }
                .onTapGesture {
                    // Navigate to task detail
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
        )
        .padding()
    }

    // MARK: - Helper Methods
    private func tasksForDate(_ date: Date) -> [TaskEntity] {
        viewModel.tasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: date)
            }
            if let scheduledTime = task.scheduledTime {
                return Calendar.current.isDate(scheduledTime, inSameDayAs: date)
            }
            return false
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var body: some View {
            MonthCalendarContent(
                viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
                timerViewModel: FocusTimerViewModel(),
                selectedDate: $selectedDate
            )
        }
    }

    return PreviewWrapper()
}
