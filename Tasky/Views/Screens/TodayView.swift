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

    // MARK: - State
    @State private var showConfetti = false
    @State private var quickTaskTitle = ""
    @State private var sheetPresentation: SheetType?
    @FocusState private var isQuickAddFocused: Bool

    enum SheetType: Identifiable {
        case addTask
        case taskDetail(TaskEntity)

        var id: String {
            switch self {
            case .addTask: return "addTask"
            case .taskDetail(let task): return "taskDetail-\(task.id)"
            }
        }
    }

    // MARK: - Computed Properties
    private var todayTasks: [TaskEntity] {
        viewModel.tasks.filter { !$0.isCompleted }
            .sorted { task1, task2 in
                let date1 = task1.scheduledTime ?? task1.dueDate ?? Date.distantFuture
                let date2 = task2.scheduledTime ?? task2.dueDate ?? Date.distantFuture

                if date1 != date2 {
                    return date1 < date2
                }

                return task1.priority > task2.priority
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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // Header
                    headerView

                    // Daily Progress Card
                    dailyProgressCard

                    // Quick Add Card
                    quickAddCard

                    // Tasks Section
                    tasksSection

                    // Completed Section
                    if !completedTasks.isEmpty {
                        completedSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(item: $sheetPresentation) { sheet in
                switch sheet {
                case .addTask:
                    AddTaskView(viewModel: viewModel)
                case .taskDetail(let task):
                    NavigationStack {
                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                    }
                }
            }
            .confetti(isPresented: $showConfetti)
            .task {
                viewModel.currentFilter = .today
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.system(size: 34, weight: .bold))

                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(tasksLeftCount) task\(tasksLeftCount == 1 ? "" : "s") left")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
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
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: completionPercentage)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(red: 0.5, green: 0.5, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Quick Add Card
    private var quickAddCard: some View {
        HStack(spacing: 10) {
            // Blue + button (clickable to create task)
            Button {
                if !quickTaskTitle.isEmpty {
                    addQuickTask()
                } else {
                    // If empty, focus the text field
                    isQuickAddFocused = true
                }
                HapticManager.shared.lightImpact()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)

                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            TextField("What do you want to accomplish?", text: $quickTaskTitle)
                .focused($isQuickAddFocused)
                .submitLabel(.done)
                .onSubmit {
                    addQuickTask()
                }

            // Always show ellipsis for advanced options
            Button {
                HapticManager.shared.lightImpact()
                sheetPresentation = .addTask
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }

    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tasks")
                .font(.title3.weight(.bold))
                .padding(.horizontal, 4)

            if todayTasks.isEmpty {
                emptyStateView
            } else {
                ForEach(todayTasks) { task in
                    ModernTaskCardView(task: task) {
                        Task {
                            await toggleTaskCompletion(task)
                        }
                    }
                    .onTapGesture {
                        sheetPresentation = .taskDetail(task)
                    }
                    .contextMenu {
                        Button {
                            sheetPresentation = .taskDetail(task)
                        } label: {
                            Label("View Details", systemImage: "info.circle")
                        }

                        Button {
                            Task {
                                await toggleTaskCompletion(task)
                            }
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle")
                        }

                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteTask(task)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Completed Section
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Completed")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(completedTasks.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            ForEach(completedTasks) { task in
                ModernTaskCardView(task: task) {
                    Task {
                        await toggleTaskCompletion(task)
                    }
                }
                .opacity(0.7)
                .onTapGesture {
                    sheetPresentation = .taskDetail(task)
                }
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green.gradient)

            Text("No tasks yet")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Add a task to get started")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Methods
    private func addQuickTask() {
        let trimmedTitle = quickTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        Task {
            // Quick add sets due date to today (so it appears in Today view)
            await viewModel.createTask(
                title: trimmedTitle,
                dueDate: Calendar.current.startOfDay(for: Date()),
                priority: 0
            )

            await MainActor.run {
                quickTaskTitle = ""
                HapticManager.shared.success()
            }
        }
    }

    private func toggleTaskCompletion(_ task: TaskEntity) async {
        let wasCompleted = task.isCompleted

        await viewModel.toggleTaskCompletion(task)

        await MainActor.run {
            if !wasCompleted {
                HapticManager.shared.success()
                showConfetti = true
            } else {
                HapticManager.shared.mediumImpact()
            }
        }
    }
}

// MARK: - Modern Task Card View
struct ModernTaskCardView: View {
    let task: TaskEntity
    let onToggleCompletion: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Priority accent bar
            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(priority.color)
                    .frame(width: 4)
                    .padding(.vertical, 4)
            }

            HStack(spacing: 8) {
                // Checkbox
                Button(action: onToggleCompletion) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(task.isCompleted ? .green : Color(.systemGray3))
                }
                .buttonStyle(.plain)

                // Task content
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)

                    // Metadata pills
                    if hasMetadata {
                        HStack(spacing: 5) {
                            // Priority pill
                            if task.priority > 0, let priority = Constants.TaskPriority(rawValue: task.priority) {
                                HStack(spacing: 2) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 8))
                                    Text(priority.displayName)
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(priority.color)
                                )
                            }

                            // Recurring pill
                            if task.isRecurring {
                                HStack(spacing: 2) {
                                    Image(systemName: "repeat")
                                        .font(.system(size: 8))
                                    Text("Daily")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.purple)
                                )
                            }

                            // Scheduled time
                            if let formattedTime = task.formattedScheduledTime {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 8))
                                    Text(formattedTime)
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(.blue)
                            }

                            // Due date (if different from scheduled)
                            if task.scheduledTime == nil, let dueDate = task.dueDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 8))
                                    Text(formatDueDate(dueDate))
                                        .font(.system(size: 10))
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Spacer()

                // Notes indicator (green dot)
                if task.notes != nil && !task.notes!.isEmpty {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.leading, task.priority > 0 ? 8 : 10)
            .padding(.trailing, 10)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.04), radius: 4, y: 1)
    }

    private var hasMetadata: Bool {
        task.priority > 0 || task.isRecurring || task.scheduledTime != nil || task.dueDate != nil
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current

        // Check if time is midnight (00:00) - indicates it's just a date, not a specific time
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let isMidnight = components.hour == 0 && components.minute == 0

        if isMidnight {
            // Just show "Today", "Tomorrow", or the date
            if calendar.isDateInToday(date) {
                return "Today"
            } else if calendar.isDateInTomorrow(date) {
                return "Tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                return formatter.string(from: date)
            }
        } else {
            // Show "Due HH:mm" for tasks with specific times
            return "Due \(formatTime(date))"
        }
    }
}

// MARK: - Preview
#Preview {
    TodayView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
