//
//  DayCalendarContent.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Day view content for calendar showing hourly timeline
struct DayCalendarContent: View {
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel
    @Binding var selectedDate: Date

    private var scheduledTasks: [TaskEntity] {
        viewModel.tasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            return Calendar.current.isDate(scheduledTime, inSameDayAs: selectedDate)
        }
    }

    private var unscheduledTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.scheduledTime == nil && !$0.isCompleted }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date Picker
            datePicker

            Divider()

            // Timeline View
            ScrollView {
                VStack(spacing: 0) {
                    // Time slots (6 AM - 12 AM)
                    ForEach(6..<24) { hour in
                        timeSlot(for: hour)
                    }
                }
            }

            Divider()

            // Unscheduled Tasks Bottom Sheet
            if !unscheduledTasks.isEmpty {
                unscheduledTasksSheet
            }
        }
    }

    // MARK: - Date Picker
    private var datePicker: some View {
        HStack {
            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(selectedDate, style: .date)
                    .font(.headline)

                if Calendar.current.isDateInToday(selectedDate) {
                    Text("Today")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Spacer()

            Button {
                withAnimation {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3)
            }
        }
        .padding()
    }

    // MARK: - Time Slot
    private func timeSlot(for hour: Int) -> some View {
        let tasksInHour = scheduledTasks.filter { task in
            guard let scheduledTime = task.scheduledTime else { return false }
            let taskHour = Calendar.current.component(.hour, from: scheduledTime)
            return taskHour == hour
        }

        return HStack(alignment: .top, spacing: 12) {
            // Time Label
            Text(formatHour(hour))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .trailing)

            Divider()

            // Tasks in this hour
            VStack(alignment: .leading, spacing: 8) {
                if tasksInHour.isEmpty {
                    Color.clear
                        .frame(height: 60)
                } else {
                    ForEach(tasksInHour) { task in
                        taskBlock(for: task)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal)
    }

    // MARK: - Task Block
    private func taskBlock(for task: TaskEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(task.isCompleted ? Color.green : Color.blue)
                    .frame(width: 8, height: 8)

                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(task.isCompleted)
            }

            if let time = task.formattedScheduledTime {
                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(task.isCompleted ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(task.isCompleted ? Color.green : Color.blue, lineWidth: 2)
        )
    }

    // MARK: - Unscheduled Tasks Sheet
    private var unscheduledTasksSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Unscheduled")
                    .font(.headline)

                Spacer()

                Text("\(unscheduledTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(unscheduledTasks.prefix(5)) { task in
                        CompactTaskCard(task: task)
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Helper Methods
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var body: some View {
            DayCalendarContent(
                viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
                timerViewModel: FocusTimerViewModel(),
                selectedDate: $selectedDate
            )
        }
    }

    return PreviewWrapper()
}
