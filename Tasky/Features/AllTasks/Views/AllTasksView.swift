//
//  AllTasksView.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// All tasks view - shows complete AI-prioritized task list
struct AllTasksView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @State private var selectedTaskForDetail: TaskEntity?
    @State private var showAddTask = false
    @State private var undoAction: UndoAction?

    enum UndoAction {
        case deletion
        case completion

        var message: String {
            switch self {
            case .deletion: return "Task deleted"
            case .completion: return "Task completed"
            }
        }

        var icon: String {
            switch self {
            case .deletion: return "trash"
            case .completion: return "checkmark.circle.fill"
            }
        }
    }

    // MARK: - Computed Properties
    private var allIncompleteTasks: [TaskEntity] {
        viewModel.tasks.filter { !$0.isCompleted }
            .sorted { $0.aiPriorityScore > $1.aiPriorityScore }
    }

    private var completedTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.isCompleted }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Constants.Spacing.md) {
                    // Header stats
                    statsHeader

                    // All incomplete tasks
                    if allIncompleteTasks.isEmpty {
                        emptyStateView
                    } else {
                        tasksSection
                    }

                    // Completed tasks section
                    if !completedTasks.isEmpty {
                        completedSection
                    }
                }
                .padding(.horizontal, Constants.Spacing.lg)
                .padding(.vertical, Constants.Spacing.sm)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                }
            }
            .navigationDestination(isPresented: $showAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .sheet(item: $selectedTaskForDetail) { task in
                NavigationStack {
                    TaskDetailView(
                        viewModel: viewModel,
                        timerViewModel: FocusTimerViewModel(),
                        task: task
                    )
                }
            }
            .undoToast(
                isPresented: Binding(
                    get: { undoAction != nil },
                    set: { if !$0 { undoAction = nil } }
                ),
                icon: undoAction?.icon ?? "trash",
                message: undoAction?.message ?? "",
                onUndo: {
                    let actionToUndo = undoAction
                    Task {
                        switch actionToUndo {
                        case .deletion:
                            await viewModel.undoDelete()
                        case .completion:
                            await viewModel.undoCompletion()
                        case .none:
                            break
                        }
                        HapticManager.shared.lightImpact()
                    }
                }
            )
            .task {
                viewModel.currentFilter = .all
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Header Stats
    private var statsHeader: some View {
        HStack(spacing: Constants.Spacing.lg) {
            VStack(alignment: .leading, spacing: Constants.Spacing.xxs) {
                Text("\(allIncompleteTasks.count)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Active")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(height: 40)

            VStack(alignment: .leading, spacing: Constants.Spacing.xxs) {
                Text("\(completedTasks.count)")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.green)

                Text("Completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .shadow(color: .black.opacity(0.02), radius: 2, y: 1)
    }

    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Prioritized Tasks")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Constants.Spacing.xs)

            ForEach(Array(allIncompleteTasks.enumerated()), id: \.element.id) { index, task in
                taskRow(for: task, isTopPriority: index == 0)
            }
        }
    }

    // MARK: - Task Row
    @ViewBuilder
    private func taskRow(for task: TaskEntity, isTopPriority: Bool) -> some View {
        ModernTaskCardView(
            task: task,
            onToggleCompletion: {
                Task {
                    await toggleTaskCompletion(task)
                }
            },
            showDoThisFirstBadge: isTopPriority,
            useHumanReadableLabels: true
        )
        .onTapGesture {
            selectedTaskForDetail = task
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button {
                Task {
                    await toggleTaskCompletion(task)
                }
            } label: {
                Label("Complete", systemImage: "checkmark")
            }
            .tint(.green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                Task {
                    await viewModel.deleteTaskWithUndo(task)
                    undoAction = .deletion
                    HapticManager.shared.mediumImpact()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Completed Section
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(completedTasks.count) Completed")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, Constants.Spacing.xs)

            ForEach(completedTasks.prefix(10)) { task in
                ModernTaskCardView(
                    task: task,
                    onToggleCompletion: {
                        Task {
                            await toggleTaskCompletion(task)
                        }
                    }
                )
                .opacity(0.7)
                .onTapGesture {
                    selectedTaskForDetail = task
                }
            }

            if completedTasks.count > 10 {
                Text("+ \(completedTasks.count - 10) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Constants.Spacing.md)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            VStack(spacing: Constants.Spacing.xs) {
                Text("All Done!")
                    .font(.title2.weight(.bold))

                Text("You have no active tasks")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            Button {
                showAddTask = true
            } label: {
                Text("Add New Task")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Constants.Spacing.xl)
                    .padding(.vertical, Constants.Spacing.md)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.xxl)
    }

    // MARK: - Methods
    private func toggleTaskCompletion(_ task: TaskEntity) async {
        let wasCompleted = task.isCompleted

        await viewModel.toggleTaskCompletionWithUndo(task)

        await MainActor.run {
            if !wasCompleted {
                HapticManager.shared.success()
                undoAction = .completion
            } else {
                HapticManager.shared.mediumImpact()
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AllTasksView(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        )
    )
}
