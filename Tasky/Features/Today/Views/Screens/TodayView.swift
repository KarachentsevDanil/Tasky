//
//  TodayView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Modern, clean Today view with card-based design
struct TodayView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State
    @State private var showConfetti = false
    @State private var showAllDoneCelebration = false
    @State private var completedTasksCount = 0
    @State private var showQuickAdd = false
    @State private var showAddTask = false
    @State private var selectedTaskForDetail: TaskEntity?
    @State private var showCompletedTasks = false
    @State private var undoAction: UndoAction?
    @State private var showAllTasks = false

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

    // MARK: - Task Grouping
    enum TaskGroup: Int, CaseIterable {
        case overdue
        case now
        case laterToday
        case noTime

        var title: String {
            switch self {
            case .overdue: return "Overdue"
            case .now: return "Now"
            case .laterToday: return "Later Today"
            case .noTime: return "Anytime"
            }
        }

        var icon: String {
            switch self {
            case .overdue: return "exclamationmark.circle.fill"
            case .now: return "circle.fill"
            case .laterToday: return "clock.fill"
            case .noTime: return "tray.fill"
            }
        }

        var color: Color {
            switch self {
            case .overdue: return .red
            case .now: return .blue
            case .laterToday: return .orange
            case .noTime: return .secondary
            }
        }
    }

    // MARK: - Computed Properties
    private var todayTasks: [TaskEntity] {
        // Flat list sorted by AI priority score (highest first)
        viewModel.tasks.filter { !$0.isCompleted }
            .sorted { $0.aiPriorityScore > $1.aiPriorityScore }
    }

    private var topPriorityTask: TaskEntity? {
        todayTasks.first
    }

    private var visibleTasksLimit: Int {
        5
    }

    private var visibleTasks: [TaskEntity] {
        if showAllTasks {
            return todayTasks
        } else {
            return Array(todayTasks.prefix(visibleTasksLimit))
        }
    }

    private var hiddenTasksCount: Int {
        max(0, todayTasks.count - visibleTasksLimit)
    }

    private var groupedTasks: [(group: TaskGroup, tasks: [TaskEntity])] {
        let now = Date()
        let calendar = Calendar.current
        let twoHoursFromNow = calendar.date(byAdding: .hour, value: 2, to: now) ?? now
        let endOfToday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now

        var grouped: [TaskGroup: [TaskEntity]] = [:]

        for task in todayTasks {
            // Only use scheduledTime for time-based grouping
            // Tasks with dueDate but no scheduledTime go to "Anytime"
            if let scheduledTime = task.scheduledTime {
                if scheduledTime < now {
                    grouped[.overdue, default: []].append(task)
                } else if scheduledTime <= twoHoursFromNow {
                    grouped[.now, default: []].append(task)
                } else if scheduledTime <= endOfToday {
                    grouped[.laterToday, default: []].append(task)
                } else {
                    grouped[.noTime, default: []].append(task)
                }
            } else {
                // No scheduled time = goes to Anytime section
                grouped[.noTime, default: []].append(task)
            }
        }

        // Return groups in priority order with tasks sorted by priority
        return TaskGroup.allCases.compactMap { group in
            guard let tasks = grouped[group], !tasks.isEmpty else { return nil }
            let sortedTasks = tasks.sorted { $0.priority > $1.priority }
            return (group, sortedTasks)
        }
    }

    private var completedTasks: [TaskEntity] {
        viewModel.tasks.filter { $0.isCompleted }
    }

    private var completionPercentage: Double {
        guard viewModel.tasks.count > 0 else { return 0 }
        return Double(completedTasks.count) / Double(viewModel.tasks.count)
    }

    private var tasksLeftCount: Int {
        todayTasks.count
    }

    private var formattedDate: String {
        AppDateFormatters.dayMonthFormatter.string(from: Date())
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Constants.Spacing.sm) {
                    // Header
                    headerView

                    // Tasks Section
                    tasksSection

                    // Completed Section
                    if !completedTasks.isEmpty {
                        VStack(alignment: .leading, spacing: Constants.Spacing.xs) {
                            // Always show the toggle button
                            showCompletedButton

                            // Show/hide completed tasks with animation
                            if showCompletedTasks {
                                completedSection
                            }
                        }
                    }
                }
                .padding(.horizontal, Constants.Spacing.lg)
                .padding(.vertical, Constants.Spacing.sm)
            }
            .background(Color(.systemGroupedBackground))
            .floatingActionButton {
                showQuickAdd = true
            }
            .refreshable {
                await viewModel.loadTasks()
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(
                    viewModel: viewModel,
                    isPresented: $showQuickAdd,
                    onShowFullForm: {
                        showAddTask = true
                    }
                )
            }
            .navigationDestination(isPresented: $showAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .sheet(item: $selectedTaskForDetail) { task in
                NavigationStack {
                    TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                }
            }
            .confetti(isPresented: $showConfetti)
            .undoToast(
                isPresented: Binding(
                    get: { undoAction != nil },
                    set: { if !$0 { undoAction = nil } }
                ),
                icon: undoAction?.icon ?? "trash",
                message: undoAction?.message ?? "",
                onUndo: {
                    // Capture the action BEFORE creating the async Task
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
            .fullScreenCover(isPresented: $showAllDoneCelebration) {
                AllDoneCelebrationView(
                    tasksCompletedCount: completedTasksCount,
                    onShare: shareAchievement
                )
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .task {
                viewModel.currentFilter = .today
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        TodayHeaderView(
            formattedDate: formattedDate,
            completedCount: completedTasks.count,
            totalCount: viewModel.tasks.count
        )
    }

    // MARK: - Daily Progress Card
    private var dailyProgressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Daily Progress: \(Int(completionPercentage * 100))% Complete")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.white.opacity(0.5))
                        .frame(width: geometry.size.width * completionPercentage, height: 6)
                        .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                }
            }
            .frame(height: 6)
            .accessibilityLabel("Daily progress")
            .accessibilityValue("\(Int(completionPercentage * 100)) percent complete, \(tasksLeftCount) tasks remaining")
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.5, green: 0.5, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
    }

    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            if todayTasks.isEmpty {
                emptyStateView
            } else {
                // Flat AI-prioritized list - limited view
                ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                    taskRow(for: task, isTopPriority: index == 0)
                }

                // Show more button
                if hiddenTasksCount > 0 && !showAllTasks {
                    Button {
                        withAnimation(.spring(response: Constants.Animation.Spring.response, dampingFraction: Constants.Animation.Spring.dampingFraction)) {
                            showAllTasks = true
                        }
                        HapticManager.shared.lightImpact()
                    } label: {
                        Text("+\(hiddenTasksCount) more task\(hiddenTasksCount == 1 ? "" : "s")")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, Constants.Spacing.sm)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Task Row
    @ViewBuilder
    private func taskRow(for task: TaskEntity, isTopPriority: Bool) -> some View {
        SwipeableTaskCard(
            onComplete: {
                Task {
                    await toggleTaskCompletion(task)
                }
            },
            onDelete: {
                Task {
                    await viewModel.deleteTaskWithUndo(task)
                    undoAction = .deletion
                }
            }
        ) {
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
        }
        .contextMenu {
            Button {
                selectedTaskForDetail = task
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Divider()

            Button {
                Task {
                    await toggleTaskCompletion(task)
                }
            } label: {
                Label(task.isCompleted ? "Mark Incomplete" : "Complete", systemImage: "checkmark.circle")
            }

            Menu {
                Button {
                    Task {
                        await scheduleTaskForLater(task, hours: 1)
                    }
                } label: {
                    Label("In 1 Hour", systemImage: "clock")
                }

                Button {
                    Task {
                        await scheduleTaskForLater(task, hours: 3)
                    }
                } label: {
                    Label("In 3 Hours", systemImage: "clock")
                }

                Button {
                    Task {
                        await scheduleTaskForTomorrow(task)
                    }
                } label: {
                    Label("Tomorrow", systemImage: "calendar")
                }

                Button {
                    Task {
                        await scheduleTaskForNextWeek(task)
                    }
                } label: {
                    Label("Next Week", systemImage: "calendar")
                }
            } label: {
                Label("Reschedule", systemImage: "clock.arrow.circlepath")
            }

            Menu {
                ForEach(Constants.TaskPriority.allCases, id: \.rawValue) { priority in
                    Button {
                        Task {
                            await updateTaskPriority(task, priority: priority.rawValue)
                        }
                    } label: {
                        Label(priority.displayName, systemImage: task.priority == priority.rawValue ? "checkmark" : "")
                    }
                }
            } label: {
                Label("Change Priority", systemImage: "flag")
            }

            if !viewModel.taskLists.isEmpty {
                Menu {
                    ForEach(viewModel.taskLists) { list in
                        Button {
                            Task {
                                await moveTaskToList(task, list: list)
                            }
                        } label: {
                            Label(list.name, systemImage: list.iconName ?? "list.bullet")
                        }
                    }
                } label: {
                    Label("Move to List", systemImage: "folder")
                }
            }

            Divider()

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
        VStack(alignment: .leading, spacing: Constants.Spacing.xs) {
            ForEach(completedTasks) { task in
                ModernTaskCardView(task: task) {
                    Task {
                        await toggleTaskCompletion(task)
                    }
                }
                .opacity(0.6)
                .scaleEffect(0.98)
                .onTapGesture {
                    selectedTaskForDetail = task
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        TodayEmptyStateView()
    }

    // MARK: - Completed Toggle Button
    private var showCompletedButton: some View {
        Button {
            withAnimation(.spring(response: Constants.Animation.Spring.response, dampingFraction: Constants.Animation.Spring.dampingFraction)) {
                showCompletedTasks.toggle()
            }
            HapticManager.shared.lightImpact()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(completedTasks.count) completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(showCompletedTasks ? 180 : 0))
            }
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.vertical, Constants.Spacing.sm)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
            .shadow(color: .black.opacity(0.02), radius: 2, y: 0.5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(completedTasks.count) completed tasks")
        .accessibilityHint(showCompletedTasks ? "Tap to collapse completed tasks" : "Tap to expand and view completed tasks")
    }

    // MARK: - Methods
    private func toggleTaskCompletion(_ task: TaskEntity) async {
        let wasCompleted = task.isCompleted
        let remainingTasksBeforeToggle = todayTasks.count

        await viewModel.toggleTaskCompletionWithUndo(task)

        await MainActor.run {
            if !wasCompleted {
                // Task was just completed
                HapticManager.shared.success()
                showConfetti = true
                undoAction = .completion

                // Check if this was the last task
                if remainingTasksBeforeToggle == 1 {
                    // All tasks completed!
                    completedTasksCount = completedTasks.count
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showAllDoneCelebration = true
                    }
                }
            } else {
                // Task was uncompleted (user tapped again on completed task)
                HapticManager.shared.mediumImpact()
                // Don't show undo toast when uncompleting - it's already a reversal
            }
        }
    }

    private func shareAchievement() {
        let text = "🎉 I completed \(completedTasksCount) tasks today with Tasky!"
        let activityVC = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }

        HapticManager.shared.lightImpact()
    }

    // MARK: - Quick Action Helpers

    private func scheduleTaskForLater(_ task: TaskEntity, hours: Int) async {
        let newTime = Calendar.current.date(byAdding: .hour, value: hours, to: Date())
        await viewModel.scheduleTask(task, startTime: newTime, endTime: nil)
        HapticManager.shared.lightImpact()
    }

    private func scheduleTaskForTomorrow(_ task: TaskEntity) async {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let tomorrowStart = Calendar.current.startOfDay(for: tomorrow ?? Date())
        await viewModel.scheduleTask(task, startTime: tomorrowStart, endTime: nil)
        HapticManager.shared.lightImpact()
    }

    private func scheduleTaskForNextWeek(_ task: TaskEntity) async {
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())
        let nextWeekStart = Calendar.current.startOfDay(for: nextWeek ?? Date())
        await viewModel.scheduleTask(task, startTime: nextWeekStart, endTime: nil)
        HapticManager.shared.lightImpact()
    }

    private func updateTaskPriority(_ task: TaskEntity, priority: Int16) async {
        await viewModel.updateTask(task, priority: priority)
        HapticManager.shared.lightImpact()
    }

    private func moveTaskToList(_ task: TaskEntity, list: TaskListEntity) async {
        await viewModel.updateTask(task, list: list)
        HapticManager.shared.lightImpact()
    }
}

// MARK: - Preview
#Preview {
    TodayView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
