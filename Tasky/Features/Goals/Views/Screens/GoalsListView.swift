//
//  GoalsListView.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Main view for displaying all goals with progress
struct GoalsListView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - ViewModel
    @StateObject private var viewModel = GoalsViewModel()

    // MARK: - State
    @State private var showingAddGoal = false
    @State private var selectedGoalForDetail: GoalEntity?
    @State private var selectedGoalForEdit: GoalEntity?
    @State private var showingArchived = false

    // MARK: - Body
    var body: some View {
        Group {
            switch viewModel.loadingState {
            case .loading:
                loadingView

            case .loaded(let goals) where goals.isEmpty:
                emptyStateView

            case .loaded:
                goalsListContent

            case .error(let error):
                errorView(error)
            }
        }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddGoal = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button {
                        showingArchived.toggle()
                        Task {
                            if showingArchived {
                                await viewModel.loadArchivedGoals()
                            } else {
                                await viewModel.loadGoals()
                            }
                        }
                    } label: {
                        Label(
                            showingArchived ? "Show Active" : "Show Archived",
                            systemImage: showingArchived ? "target" : "archivebox"
                        )
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddGoal) {
            GoalEditorSheet(existingGoal: nil) { name, notes, targetDate, colorHex, iconName in
                await viewModel.createGoal(
                    name: name,
                    notes: notes,
                    targetDate: targetDate,
                    colorHex: colorHex,
                    iconName: iconName
                )
            }
        }
        .sheet(item: $selectedGoalForEdit) { goal in
            GoalEditorSheet(existingGoal: goal) { name, notes, targetDate, colorHex, iconName in
                await viewModel.updateGoal(
                    goal,
                    name: name,
                    notes: notes,
                    targetDate: targetDate,
                    colorHex: colorHex,
                    iconName: iconName
                )
            }
        }
        .navigationDestination(item: $selectedGoalForDetail) { goal in
            GoalDetailView(goal: goal, viewModel: viewModel)
        }
        .task {
            await viewModel.loadGoals()
        }
        .refreshable {
            if showingArchived {
                await viewModel.loadArchivedGoals()
            } else {
                await viewModel.loadGoals()
            }
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            ProgressView()
            Text("Loading goals...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                showingArchived ? "No Archived Goals" : "No Goals Yet",
                systemImage: showingArchived ? "archivebox" : "target"
            )
        } description: {
            Text(showingArchived
                 ? "Completed and abandoned goals will appear here."
                 : "Goals help you track progress on larger projects. Create one to get started!"
            )
        } actions: {
            if !showingArchived {
                Button {
                    showingAddGoal = true
                } label: {
                    Label("Create Goal", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("Try Again") {
                Task { await viewModel.loadGoals() }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Goals List Content
    private var goalsListContent: some View {
        List {
            // Neglected goals warning
            if !viewModel.neglectedGoals.isEmpty && !showingArchived {
                Section {
                    ForEach(viewModel.neglectedGoals, id: \.id) { goal in
                        Button {
                            selectedGoalForDetail = goal
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("\(goal.name) needs attention")
                                    .font(.subheadline)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Needs Attention")
                }
            }

            // Active goals
            if !viewModel.activeGoals.isEmpty || showingArchived {
                Section {
                    ForEach(viewModel.goals, id: \.id) { goal in
                        Button {
                            selectedGoalForDetail = goal
                        } label: {
                            GoalRow(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !showingArchived {
                                Button(role: .destructive) {
                                    Task { await viewModel.deleteGoal(goal) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }

                                Button {
                                    selectedGoalForEdit = goal
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if goal.statusEnum == .active {
                                Button {
                                    Task { await viewModel.completeGoal(goal) }
                                } label: {
                                    Label("Complete", systemImage: "checkmark")
                                }
                                .tint(.green)
                            }
                        }
                        .contextMenu {
                            goalContextMenu(for: goal)
                        }
                    }
                    .onMove { source, destination in
                        Task {
                            await viewModel.moveGoals(from: source, to: destination)
                        }
                    }
                } header: {
                    Text(showingArchived ? "Archived Goals" : "Goals")
                }
            }

            // Paused goals
            if !viewModel.pausedGoals.isEmpty && !showingArchived {
                Section {
                    ForEach(viewModel.pausedGoals, id: \.id) { goal in
                        Button {
                            selectedGoalForDetail = goal
                        } label: {
                            GoalRow(goal: goal)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                Task { await viewModel.resumeGoal(goal) }
                            } label: {
                                Label("Resume", systemImage: "play")
                            }
                            .tint(.green)
                        }
                    }
                } header: {
                    Text("Paused")
                }
            }
        }
    }

    // MARK: - Context Menu
    @ViewBuilder
    private func goalContextMenu(for goal: GoalEntity) -> some View {
        Button {
            selectedGoalForEdit = goal
        } label: {
            Label("Edit", systemImage: "pencil")
        }

        Divider()

        if goal.statusEnum == .active {
            Button {
                Task { await viewModel.pauseGoal(goal) }
            } label: {
                Label("Pause", systemImage: "pause")
            }

            Button {
                Task { await viewModel.completeGoal(goal) }
            } label: {
                Label("Mark Complete", systemImage: "checkmark.circle")
            }
        } else if goal.statusEnum == .paused {
            Button {
                Task { await viewModel.resumeGoal(goal) }
            } label: {
                Label("Resume", systemImage: "play")
            }
        }

        Divider()

        Button(role: .destructive) {
            Task { await viewModel.abandonGoal(goal) }
        } label: {
            Label("Abandon", systemImage: "xmark.circle")
        }

        Button(role: .destructive) {
            Task { await viewModel.deleteGoal(goal) }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

// MARK: - Preview
#Preview {
    GoalsListView()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
}
