//
//  GoalDetailView.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

internal import CoreData
import SwiftUI

/// Detail view for displaying goal information, progress, and linked tasks
struct GoalDetailView: View {

    // MARK: - Properties
    let goal: GoalEntity
    @ObservedObject var viewModel: GoalsViewModel

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State
    @State private var showingLinkTasks = false
    @State private var showingEditGoal = false
    @State private var showingDeleteConfirmation = false
    @State private var showingStatusMenu = false

    // MARK: - Body
    var body: some View {
        List {
            // Progress header section
            progressHeaderSection

            // Statistics section
            statisticsSection

            // Linked tasks section
            linkedTasksSection

            // Actions section
            actionsSection
        }
        .navigationTitle(goal.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditGoal = true
                    } label: {
                        Label("Edit Goal", systemImage: "pencil")
                    }

                    Divider()

                    statusMenuItems

                    Divider()

                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete Goal", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditGoal) {
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
        .sheet(isPresented: $showingLinkTasks) {
            LinkTasksSheet(goal: goal, viewModel: viewModel)
        }
        .alert("Delete Goal?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteGoal(goal)
                    dismiss()
                }
            }
        } message: {
            Text("This will permanently delete the goal. Linked tasks will not be deleted.")
        }
    }

    // MARK: - Progress Header Section
    private var progressHeaderSection: some View {
        Section {
            VStack(spacing: Constants.Spacing.lg) {
                // Goal icon and progress ring
                ZStack {
                    GoalProgressRing(
                        progress: goal.progress,
                        color: Color(hex: goal.colorHex ?? "007AFF") ?? .accentColor,
                        lineWidth: 12,
                        size: 120
                    )

                    VStack(spacing: Constants.Spacing.xs) {
                        if let iconName = goal.iconName {
                            Image(systemName: iconName)
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: goal.colorHex ?? "007AFF") ?? .accentColor)
                        }

                        Text("\(goal.progressPercentage)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Progress text
                Text(goal.progressText)
                    .font(.headline)

                // Status badge
                statusBadge

                // Notes
                if let notes = goal.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.Spacing.md)
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Status Badge
    private var statusBadge: some View {
        HStack(spacing: Constants.Spacing.xs) {
            Image(systemName: goal.statusEnum.iconName)
            Text(goal.statusEnum.displayName)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, Constants.Spacing.md)
        .padding(.vertical, Constants.Spacing.xs)
        .background(Color(hex: goal.statusEnum.color)?.opacity(0.15) ?? Color.gray.opacity(0.15))
        .foregroundStyle(Color(hex: goal.statusEnum.color) ?? .gray)
        .clipShape(Capsule())
    }

    // MARK: - Statistics Section
    private var statisticsSection: some View {
        Section("Statistics") {
            // Target date
            if let targetDate = goal.targetDate {
                HStack {
                    Label("Target Date", systemImage: "calendar")
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(goal.formattedTargetDate ?? "")
                            .foregroundStyle(goal.isOverdue ? Color.red : Color.primary)
                        if let days = goal.daysUntilTarget {
                            Text(days >= 0 ? "\(days) days left" : "\(abs(days)) days overdue")
                                .font(.caption)
                                .foregroundStyle(days >= 0 ? Color.secondary : Color.red)
                        }
                    }
                }
            }

            // Weekly velocity
            HStack {
                Label("Weekly Velocity", systemImage: "speedometer")
                Spacer()
                Text(String(format: "%.1f tasks/day", goal.weeklyVelocity))
                    .foregroundStyle(.secondary)
            }

            // Estimated completion
            if let estimatedText = goal.estimatedCompletionText {
                HStack {
                    Label("Estimated Completion", systemImage: "calendar.badge.clock")
                    Spacer()
                    Text(estimatedText.replacingOccurrences(of: "Est. completion: ", with: ""))
                        .foregroundStyle(.secondary)
                }
            }

            // Days since progress
            if let daysSince = goal.daysSinceProgress {
                HStack {
                    Label("Last Progress", systemImage: "clock.arrow.circlepath")
                    Spacer()
                    Text(daysSince == 0 ? "Today" : "\(daysSince) days ago")
                        .foregroundStyle(daysSince > 7 ? .orange : .secondary)
                }
            }

            // Created date
            HStack {
                Label("Created", systemImage: "plus.circle")
                Spacer()
                Text(goal.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Linked Tasks Section
    private var linkedTasksSection: some View {
        Section {
            // Link tasks button
            Button {
                showingLinkTasks = true
            } label: {
                Label("Link Tasks", systemImage: "link.badge.plus")
            }

            // Linked tasks list
            if goal.linkedTasks.isEmpty {
                ContentUnavailableView {
                    Label("No Linked Tasks", systemImage: "checkmark.circle.badge.questionmark")
                } description: {
                    Text("Link tasks to track progress towards this goal.")
                }
                .listRowBackground(Color.clear)
            } else {
                ForEach(goal.linkedTasks, id: \.id) { task in
                    linkedTaskRow(task)
                }
            }
        } header: {
            HStack {
                Text("Tasks")
                Spacer()
                Text("\(goal.completedTaskCount)/\(goal.totalTaskCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Linked Task Row
    private func linkedTaskRow(_ task: TaskEntity) -> some View {
        HStack(spacing: Constants.Spacing.md) {
            // Completion indicator
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(task.isCompleted ? Color.green : Color.gray.opacity(0.4))
                .font(.title3)

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if let dueDate = task.dueDate {
                    Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Unlink button
            Button {
                Task {
                    await viewModel.unlinkTask(task, from: goal)
                }
            } label: {
                Image(systemName: "link.badge.minus")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, Constants.Spacing.xs)
    }

    // MARK: - Actions Section
    private var actionsSection: some View {
        Section {
            if goal.statusEnum == .active {
                Button {
                    Task { await viewModel.pauseGoal(goal) }
                } label: {
                    Label("Pause Goal", systemImage: "pause.circle")
                }

                Button {
                    Task { await viewModel.completeGoal(goal) }
                } label: {
                    Label("Mark as Complete", systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            } else if goal.statusEnum == .paused {
                Button {
                    Task { await viewModel.resumeGoal(goal) }
                } label: {
                    Label("Resume Goal", systemImage: "play.circle")
                        .foregroundStyle(.green)
                }
            }

            if goal.statusEnum != .abandoned && goal.statusEnum != .completed {
                Button(role: .destructive) {
                    Task { await viewModel.abandonGoal(goal) }
                } label: {
                    Label("Abandon Goal", systemImage: "xmark.circle")
                }
            }
        }
    }

    // MARK: - Status Menu Items
    @ViewBuilder
    private var statusMenuItems: some View {
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
    }
}

// MARK: - Link Tasks Sheet
private struct LinkTasksSheet: View {
    let goal: GoalEntity
    @ObservedObject var viewModel: GoalsViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var availableTasks: [TaskEntity] = []
    @State private var selectedTasks: Set<UUID> = []
    @State private var searchText = ""

    private var filteredTasks: [TaskEntity] {
        if searchText.isEmpty {
            return availableTasks
        }
        return availableTasks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if filteredTasks.isEmpty {
                    ContentUnavailableView {
                        Label("No Tasks Found", systemImage: "magnifyingglass")
                    } description: {
                        Text("All tasks are already linked or no tasks match your search.")
                    }
                } else {
                    ForEach(filteredTasks, id: \.id) { task in
                        Button {
                            toggleTask(task)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.title)
                                    if let dueDate = task.dueDate {
                                        Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                if selectedTasks.contains(task.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search tasks")
            .navigationTitle("Link Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") {
                        linkSelectedTasks()
                    }
                    .disabled(selectedTasks.isEmpty)
                }
            }
            .task {
                await loadAvailableTasks()
            }
        }
    }

    private func toggleTask(_ task: TaskEntity) {
        if selectedTasks.contains(task.id) {
            selectedTasks.remove(task.id)
        } else {
            selectedTasks.insert(task.id)
        }
    }

    private func loadAvailableTasks() async {
        // Get tasks not already linked to this goal
        let linkedTaskIds = Set(goal.linkedTasks.map { $0.id })
        let allTasks = await viewModel.fetchUnlinkedTasks(excludingGoal: goal)
        availableTasks = allTasks.filter { !linkedTaskIds.contains($0.id) }
    }

    private func linkSelectedTasks() {
        Task {
            for taskId in selectedTasks {
                if let task = availableTasks.first(where: { $0.id == taskId }) {
                    await viewModel.linkTask(task, to: goal)
                }
            }
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview {
    let context = PersistenceController.preview.container.viewContext
    let goal = GoalEntity(context: context)
    goal.id = UUID()
    goal.name = "Learn SwiftUI"
    goal.notes = "Master SwiftUI framework for iOS development"
    goal.status = GoalStatus.active.rawValue
    goal.colorHex = "007AFF"
    goal.iconName = "book.fill"
    goal.createdAt = Date()
    goal.targetDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())

    return NavigationStack {
        GoalDetailView(
            goal: goal,
            viewModel: GoalsViewModel(dataService: DataService(persistenceController: .preview))
        )
    }
}
