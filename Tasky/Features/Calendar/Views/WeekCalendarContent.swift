//
//  WeekCalendarContent.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Week view content showing tasks grouped by day
struct WeekCalendarContent: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel
    @Binding var selectedDate: Date

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    private var weekRangeText: String {
        let calendar = Calendar.current
        guard let firstDay = weekDates.first,
              let lastDay = weekDates.last else {
            return ""
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let firstString = formatter.string(from: firstDay)
        let lastString = formatter.string(from: lastDay)

        // Add year if different
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        let firstYear = yearFormatter.string(from: firstDay)
        let lastYear = yearFormatter.string(from: lastDay)

        if firstYear != lastYear {
            return "\(firstString), \(firstYear) - \(lastString), \(lastYear)"
        } else {
            return "\(firstString) - \(lastString)"
        }
    }

    private var isCurrentWeek: Bool {
        let calendar = Calendar.current
        return calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Week Navigation
                weekNavigationHeader

                // Week Days Grid
                LazyVGrid(columns: [GridItem(.flexible())], spacing: 16) {
                    ForEach(weekDates, id: \.self) { date in
                        weekDayCard(for: date)
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Week Navigation Header
    private var weekNavigationHeader: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(weekRangeText)
                    .font(.headline)

                if isCurrentWeek {
                    Text("This Week")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Week Day Card
    private func weekDayCard(for date: Date) -> some View {
        let tasksForDate = tasksForDate(date)
        let isToday = Calendar.current.isDateInToday(date)

        // Calculate task status
        let completedCount = tasksForDate.filter { $0.isCompleted }.count
        let totalCount = tasksForDate.count
        let allCompleted = completedCount == totalCount && totalCount > 0

        return VStack(alignment: .leading, spacing: 12) {
            // Date Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(date, format: .dateTime.weekday(.wide))
                        .font(.headline)
                        .foregroundStyle(isToday ? .blue : .primary)

                    Text(date, format: .dateTime.day().month(.abbreviated))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !tasksForDate.isEmpty {
                    ZStack {
                        Circle()
                            .fill(allCompleted ? Color.green : Color.orange)
                            .frame(width: 28, height: 28)

                        if allCompleted {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(totalCount - completedCount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            Divider()

            // Tasks for this day
            if tasksForDate.isEmpty {
                Text("No tasks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                ForEach(tasksForDate.prefix(3)) { task in
                    NavigationLink {
                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                    } label: {
                        CompactWeekTaskRow(task: task, timerViewModel: timerViewModel)
                    }
                    .buttonStyle(.plain)
                }

                if tasksForDate.count > 3 {
                    Text("+\(tasksForDate.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isToday ? Color.accentColor.opacity(0.05) : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
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
            WeekCalendarContent(
                viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
                timerViewModel: FocusTimerViewModel(),
                selectedDate: $selectedDate
            )
        }
    }

    return PreviewWrapper()
}
