//
//  TodayView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Enhanced Today view with prioritization and completion tracking
struct TodayView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()

    // MARK: - State
    @State private var showingAddTask = false
    @State private var showConfetti = false
    @State private var celebrationMessage = ""

    // MARK: - Computed Properties
    private var todayTasks: [TaskEntity] {
        viewModel.tasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.isCompleted }
    }

    private var completionCount: Int {
        completedTasks.count
    }

    private var totalCount: Int {
        viewModel.tasks.count
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Completion Ring Header
                    completionHeader

                    // Priority Tasks Section
                    if !todayTasks.isEmpty {
                        priorityTasksSection
                    }

                    // Completed Tasks Section
                    if !completedTasks.isEmpty {
                        completedTasksSection
                    }

                    // Empty State
                    if todayTasks.isEmpty && completedTasks.isEmpty {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .confetti(isPresented: $showConfetti)
            .task {
                viewModel.currentFilter = .today
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Completion Header
    private var completionHeader: some View {
        VStack(spacing: 16) {
            // Completion Ring
            CompletionRingView(completed: completionCount, total: max(totalCount, 1))
                .frame(width: 100, height: 100)

            // Motivational Text
            VStack(spacing: 4) {
                Text(motivationalTitle)
                    .font(.title3.weight(.semibold))

                Text(motivationalSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
        )
    }

    // MARK: - Priority Tasks Section
    private var priorityTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .font(.title2.weight(.bold))
                .padding(.horizontal, 4)

            List {
                ForEach(todayTasks) { task in
                    NavigationLink {
                        TaskDetailView(viewModel: viewModel, task: task)
                    } label: {
                        EnhancedTaskRowView(task: task, timerViewModel: timerViewModel) {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTask(task)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        .tint(.green)
                    }
                }
                .onMove { from, to in
                    moveTasks(from: from, to: to)
                }
            }
            .listStyle(.plain)
            .frame(minHeight: max(CGFloat(todayTasks.count) * 100, 300))
            .id(todayTasks.map { "\($0.id)-\($0.isCompleted)" }.joined())
        }
    }

    // MARK: - Completed Tasks Section
    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Completed")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(completedTasks.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ForEach(completedTasks) { task in
                NavigationLink {
                    TaskDetailView(viewModel: viewModel, task: task)
                } label: {
                    EnhancedTaskRowView(task: task, timerViewModel: timerViewModel) {
                        Task {
                            await toggleTaskCompletion(task)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)

            Text("All Done!")
                .font(.title2.weight(.bold))

            Text("You've completed all your tasks for today.\nTake a well-deserved break!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60)
    }

    // MARK: - Methods

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var tasks = todayTasks
        tasks.move(fromOffsets: source, toOffset: destination)

        // Update priority order
        Task {
            await viewModel.reorderTasks(tasks)
            HapticManager.shared.selectionChanged()
        }
    }

    private func toggleTaskCompletion(_ task: TaskEntity) async {
        let wasCompleted = task.isCompleted

        // Toggle completion
        await viewModel.toggleTaskCompletion(task)

        // If task was just completed, celebrate!
        if !wasCompleted {
            celebrateCompletion()
        } else {
            // Just haptic for un-completing
            HapticManager.shared.mediumImpact()
        }
    }

    private func celebrateCompletion() {
        // Haptic feedback
        HapticManager.shared.success()

        // Show confetti
        showConfetti = true

        // Update motivational message
        celebrationMessage = celebrationMessages.randomElement() ?? "Great job!"
    }

    // MARK: - Motivational Copy
    private var motivationalTitle: String {
        if completionCount == 0 {
            return "Let's get started!"
        } else if completionCount == totalCount && totalCount > 0 {
            return "All done for today!"
        } else {
            return "Keep it up!"
        }
    }

    private var motivationalSubtitle: String {
        if totalCount == 0 {
            return "No tasks yet"
        } else if completionCount == totalCount {
            return "All tasks completed!"
        } else {
            let tasksLeft = totalCount - completionCount
            return "\(tasksLeft) task\(tasksLeft == 1 ? "" : "s") left"
        }
    }

    private let celebrationMessages = [
        "Great work!",
        "You're on fire!",
        "Awesome!",
        "Well done!",
        "Keep going!",
        "Crushing it!",
        "Amazing!",
        "You're unstoppable!"
    ]
}

// MARK: - Enhanced Task Row
struct EnhancedTaskRowView: View {
    let task: TaskEntity
    @ObservedObject var timerViewModel: FocusTimerViewModel
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // Completion Button
            Button(action: onToggleCompletion) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(task.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)

            // Task Content
            VStack(alignment: .leading, spacing: 8) {
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                // Metadata Pills
                HStack(spacing: 8) {
                    // Focus Timer Pill (tappable)
                    if !task.isCompleted {
                        FocusTimerView(viewModel: timerViewModel, task: task)
                    }

                    // Recurrence Pill
                    if task.isRecurring, let recurrenceDesc = task.recurrenceDescription {
                        HStack(spacing: 4) {
                            Image(systemName: "repeat")
                                .font(.caption2)
                            Text(recurrenceDesc)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.purple.opacity(0.15))
                        )
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // Priority Pill
                    if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                        Text(priority.displayName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(priority.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(priority.color.opacity(0.15))
                            )
                            .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // List Pill
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
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }

                    // Scheduled Time Pill
                    if let formattedTime = task.formattedScheduledTime {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(formattedTime)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.15))
                        )
                        .opacity(task.isCompleted ? 0.5 : 1.0)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview
#Preview {
    TodayView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
