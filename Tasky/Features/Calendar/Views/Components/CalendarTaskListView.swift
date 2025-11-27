//
//  CalendarTaskListView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 25.11.2025.
//

import SwiftUI

/// Undo action type for task operations
enum CalendarUndoAction {
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

/// Polished task list view for the calendar with contextual headers
struct CalendarTaskListView: View {
    let selectedDate: Date
    let tasks: [TaskEntity]
    @ObservedObject var viewModel: TaskListViewModel
    @ObservedObject var timerViewModel: FocusTimerViewModel
    @Binding var undoAction: CalendarUndoAction?

    @State private var showCompletedTasks = false
    @State private var selectedTaskForDetail: TaskEntity?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    private var incompleteTasks: [TaskEntity] {
        tasks.filter { !$0.isCompleted }
            .sorted { $0.aiPriorityScore > $1.aiPriorityScore }
    }

    private var completedTasks: [TaskEntity] {
        tasks.filter { $0.isCompleted }
    }

    private var dateHeaderText: String {
        let calendar = Calendar.current

        if calendar.isDateInToday(selectedDate) {
            return "Today"
        } else if calendar.isDateInTomorrow(selectedDate) {
            return "Tomorrow"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: selectedDate)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: selectedDate)
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var isPastDate: Bool {
        Calendar.current.startOfDay(for: selectedDate) < Calendar.current.startOfDay(for: Date())
    }

    private var daysFromToday: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfSelected = calendar.startOfDay(for: selectedDate)
        return calendar.dateComponents([.day], from: startOfToday, to: startOfSelected).day ?? 0
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Date header card
            dateHeaderCard

            // Tasks section
            if incompleteTasks.isEmpty && completedTasks.isEmpty {
                emptyStateView
            } else {
                tasksSection
            }

            // Completed toggle (if there are completed tasks)
            if !completedTasks.isEmpty {
                completedToggleSection
            }
        }
        .padding(.horizontal, Constants.Spacing.md)
        .sheet(item: $selectedTaskForDetail) { task in
            NavigationStack {
                TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
            }
        }
    }

    // MARK: - Date Header Card

    private var dateHeaderCard: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Date badge
            VStack(spacing: 2) {
                Text(formattedDate.components(separatedBy: " ").first ?? "")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isToday ? .white : .accentColor)
                    .textCase(.uppercase)

                Text(formattedDate.components(separatedBy: " ").last ?? "")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isToday ? .white : .primary)
            }
            .frame(width: 52, height: 52)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium)
                    .fill(isToday ? Color.accentColor : Color(.tertiarySystemFill))
            )

            // Day info
            VStack(alignment: .leading, spacing: 2) {
                Text(dateHeaderText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(taskSummaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.top, Constants.Spacing.sm)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dateHeaderText), \(formattedDate), \(taskSummaryText)")
    }

    private var taskSummaryText: String {
        let totalTasks = tasks.count
        let completedCount = completedTasks.count
        let incompleteCount = incompleteTasks.count

        if totalTasks == 0 {
            return "No tasks scheduled"
        } else if incompleteCount == 0 {
            return "All \(completedCount) tasks done"
        } else if completedCount == 0 {
            return "\(incompleteCount) task\(incompleteCount == 1 ? "" : "s") to do"
        } else {
            return "\(incompleteCount) remaining · \(completedCount) done"
        }
    }

    // MARK: - Tasks Section

    private var tasksSection: some View {
        LazyVStack(spacing: Constants.Spacing.sm) {
            ForEach(incompleteTasks) { task in
                taskRow(for: task)
            }
        }
    }

    // MARK: - Task Row

    @ViewBuilder
    private func taskRow(for task: TaskEntity) -> some View {
        SwipeableTaskCard(
            onComplete: {
                Task {
                    await viewModel.toggleTaskCompletion(task)
                    HapticManager.shared.success()
                    undoAction = .completion
                }
            },
            onDelete: {
                Task {
                    await viewModel.deleteTask(task)
                    HapticManager.shared.mediumImpact()
                    undoAction = .deletion
                }
            }
        ) {
            ModernTaskCardView(
                task: task,
                onToggleCompletion: {
                    Task {
                        await viewModel.toggleTaskCompletion(task)
                        HapticManager.shared.success()
                        undoAction = .completion
                    }
                },
                showDoThisFirstBadge: false,
                useHumanReadableLabels: true
            )
            .onTapGesture {
                selectedTaskForDetail = task
            }
        }
        .contextMenu {
            taskContextMenu(for: task)
        }
    }

    // MARK: - Task Context Menu

    @ViewBuilder
    private func taskContextMenu(for task: TaskEntity) -> some View {
        Button {
            selectedTaskForDetail = task
        } label: {
            Label("View Details", systemImage: "info.circle")
        }

        Divider()

        Button {
            Task {
                await viewModel.toggleTaskCompletion(task)
                HapticManager.shared.success()
                if !task.isCompleted {
                    undoAction = .completion
                }
            }
        } label: {
            Label(
                task.isCompleted ? "Mark Incomplete" : "Complete",
                systemImage: task.isCompleted ? "circle" : "checkmark.circle"
            )
        }

        Divider()

        Button(role: .destructive) {
            Task {
                await viewModel.deleteTask(task)
                HapticManager.shared.mediumImpact()
                undoAction = .deletion
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Completed Toggle Section

    private var completedToggleSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            // Toggle button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showCompletedTasks.toggle()
                }
                HapticManager.shared.lightImpact()
            } label: {
                HStack(spacing: Constants.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.green)

                    Text("\(completedTasks.count) completed")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showCompletedTasks ? 90 : 0))
                }
                .padding(.horizontal, Constants.Spacing.md)
                .padding(.vertical, Constants.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium)
                        .fill(Color(.systemBackground))
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(completedTasks.count) completed tasks")
            .accessibilityHint(showCompletedTasks ? "Tap to collapse" : "Tap to expand")

            // Completed tasks list
            if showCompletedTasks {
                LazyVStack(spacing: Constants.Spacing.sm) {
                    ForEach(completedTasks) { task in
                        ModernTaskCardView(task: task) {
                            Task {
                                await viewModel.toggleTaskCompletion(task)
                                HapticManager.shared.lightImpact()
                            }
                        }
                        .opacity(0.6)
                        .onTapGesture {
                            selectedTaskForDetail = task
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            // Contextual icon based on date
            emptyStateIcon
                .font(.system(size: 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(emptyStateColor)

            VStack(spacing: Constants.Spacing.xs) {
                Text(emptyStateTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(emptyStateSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 260)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.xxxl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyStateTitle). \(emptyStateSubtitle)")
    }

    private var emptyStateIcon: Image {
        if isToday {
            return Image(systemName: "sun.max.fill")
        } else if isPastDate {
            return Image(systemName: "checkmark.seal.fill")
        } else if daysFromToday == 1 {
            return Image(systemName: "sunrise.fill")
        } else {
            return Image(systemName: "calendar.badge.plus")
        }
    }

    private var emptyStateColor: Color {
        if isToday {
            return .orange
        } else if isPastDate {
            return .green
        } else if daysFromToday == 1 {
            return .purple
        } else {
            return .blue
        }
    }

    private var emptyStateTitle: String {
        if isToday {
            return "Today is clear"
        } else if isPastDate {
            return "Nothing was scheduled"
        } else if daysFromToday == 1 {
            return "Tomorrow is free"
        } else {
            return "Nothing scheduled yet"
        }
    }

    private var emptyStateSubtitle: String {
        if isToday {
            return "Enjoy your free time or tap + to add something"
        } else if isPastDate {
            return "This day had no tasks"
        } else if daysFromToday == 1 {
            return "Plan ahead by adding tasks for tomorrow"
        } else {
            return "Tap + to schedule tasks for \(dateHeaderText)"
        }
    }
}

// MARK: - Preview

#Preview("Empty Today") {
    ScrollView {
        CalendarTaskListView(
            selectedDate: Date(),
            tasks: [],
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            timerViewModel: FocusTimerViewModel(),
            undoAction: .constant(nil)
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty Tomorrow") {
    ScrollView {
        CalendarTaskListView(
            selectedDate: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
            tasks: [],
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            timerViewModel: FocusTimerViewModel(),
            undoAction: .constant(nil)
        )
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty Past") {
    ScrollView {
        CalendarTaskListView(
            selectedDate: Calendar.current.date(byAdding: .day, value: -3, to: Date())!,
            tasks: [],
            viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
            timerViewModel: FocusTimerViewModel(),
            undoAction: .constant(nil)
        )
    }
    .background(Color(.systemGroupedBackground))
}
