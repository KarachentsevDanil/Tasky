//
//  ScheduleTaskSheet.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Sheet for scheduling tasks to specific times
struct ScheduleTaskSheet: View {
    @StateObject var viewModel: TaskListViewModel
    let selectedTime: Date
    let selectedEndTime: Date?
    let selectedTimeRange: String?
    let unscheduledTasks: [TaskEntity]
    let onDismiss: () -> Void

    @State private var showingCreateNew = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected time header
                VStack(spacing: 8) {
                    Text("Schedule for")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let timeRange = selectedTimeRange {
                        // Show time range if selected
                        Text(timeRange)
                            .font(.title2.weight(.bold))
                    } else {
                        // Show single time
                        Text(selectedTime, style: .time)
                            .font(.title.weight(.bold))
                    }

                    Text(selectedTime, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemBackground))

                // Create new task button
                Button {
                    showingCreateNew = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)

                        Text("Create new task")
                            .font(.body.weight(.medium))

                        Spacer()
                    }
                    .padding()
                    .background(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Create new task")
                .accessibilityHint("Create a new task for the selected time")

                Divider()

                // Unscheduled tasks list
                if unscheduledTasks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 50))
                            .foregroundStyle(.secondary)

                        Text("No unscheduled tasks")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Or schedule existing task")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                            .padding(.top, 12)

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(unscheduledTasks) { task in
                                    Button {
                                        Task {
                                            await scheduleTask(task)
                                        }
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "circle")
                                                .font(.title3)
                                                .foregroundStyle(.gray)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(task.title)
                                                    .font(.body)
                                                    .foregroundStyle(.primary)

                                                if let list = task.taskList {
                                                    HStack(spacing: 4) {
                                                        Image(systemName: list.iconName ?? "list.bullet")
                                                            .font(.caption2)
                                                        Text(list.name)
                                                            .font(.caption2.weight(.medium))
                                                    }
                                                    .foregroundStyle(list.color)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule()
                                                            .fill(list.color.opacity(0.15))
                                                    )
                                                }
                                            }

                                            Spacer()

                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding()
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(.secondarySystemBackground))
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Schedule \(task.title)")
                                    .accessibilityHint("Schedule this task for the selected time")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Schedule Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                    .accessibilityLabel("Cancel")
                    .accessibilityHint("Dismiss without scheduling a task")
                }
            }
            .sheet(isPresented: $showingCreateNew) {
                AddTaskView(viewModel: viewModel, preselectedScheduledTime: selectedTime, preselectedScheduledEndTime: selectedEndTime)
            }
        }
    }

    private func scheduleTask(_ task: TaskEntity) async {
        await viewModel.scheduleTask(
            task,
            startTime: selectedTime,
            endTime: selectedEndTime
        )
        HapticManager.shared.success()
        onDismiss()
    }
}

#Preview {
    ScheduleTaskSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        selectedTime: Date(),
        selectedEndTime: nil,
        selectedTimeRange: nil,
        unscheduledTasks: [],
        onDismiss: {}
    )
}
