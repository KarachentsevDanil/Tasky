//
//  ReviewUpcomingStep.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Step 4: Preview upcoming tasks for next week
struct ReviewUpcomingStep: View {

    // MARK: - Properties
    let tasks: [TaskEntity]
    let onContinue: () -> Void

    // MARK: - State
    @State private var groupedTasks: [Date: [TaskEntity]] = [:]

    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.Spacing.lg) {
            // Header
            headerView

            if tasks.isEmpty {
                emptyStateView
            } else {
                // Task list grouped by day
                ScrollView {
                    LazyVStack(spacing: Constants.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                        ForEach(sortedDates, id: \.self) { date in
                            Section {
                                ForEach(groupedTasks[date] ?? [], id: \.id) { task in
                                    ReviewUpcomingTaskRow(task: task)
                                }
                            } header: {
                                dayHeader(for: date)
                            }
                        }
                    }
                    .padding(.horizontal, Constants.Spacing.lg)
                }
            }

            // Continue Button
            Button {
                onContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.bottom, Constants.Spacing.xl)
        }
        .onAppear {
            groupTasksByDay()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: Constants.Spacing.sm) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 40))
                .foregroundStyle(.purple)

            Text("Upcoming Week")
                .font(.title2.weight(.bold))

            Text("\(tasks.count) tasks scheduled")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Constants.Spacing.md)
                .padding(.vertical, Constants.Spacing.xs)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
        .padding(.top, Constants.Spacing.xl)
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            Spacer()

            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Clear Week Ahead!")
                .font(.title3.weight(.semibold))

            Text("No tasks scheduled for next week yet. Enjoy the flexibility!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xl)

            Spacer()
        }
    }

    // MARK: - Day Header
    private func dayHeader(for date: Date) -> some View {
        HStack {
            Text(formatDayHeader(date))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(groupedTasks[date]?.count ?? 0) tasks")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, Constants.Spacing.sm)
        .padding(.horizontal, Constants.Spacing.sm)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sorted Dates
    private var sortedDates: [Date] {
        groupedTasks.keys.sorted()
    }

    // MARK: - Helpers
    private func groupTasksByDay() {
        let calendar = Calendar.current
        var grouped: [Date: [TaskEntity]] = [:]

        for task in tasks {
            guard let dueDate = task.dueDate else { continue }
            let dayStart = calendar.startOfDay(for: dueDate)

            if grouped[dayStart] != nil {
                grouped[dayStart]?.append(task)
            } else {
                grouped[dayStart] = [task]
            }
        }

        groupedTasks = grouped
    }

    private func formatDayHeader(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Review Upcoming Task Row
private struct ReviewUpcomingTaskRow: View {
    let task: TaskEntity

    var body: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Priority indicator
            Circle()
                .fill(priorityColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)

                if let listName = task.taskList?.name {
                    Text(listName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Scheduled time if exists
            if let scheduledTime = task.scheduledTime {
                Text(scheduledTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Constants.Spacing.sm)
        .padding(.horizontal, Constants.Spacing.md)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
    }

    private var priorityColor: Color {
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray.opacity(0.5)
        }
    }
}

// MARK: - Preview
#Preview {
    ReviewUpcomingStep(
        tasks: [],
        onContinue: {}
    )
}
