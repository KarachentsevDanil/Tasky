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
        AppDateFormatters.dayMonthFormatter.string(from: Date())
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    // Header
                    headerView

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
            .refreshable {
                await viewModel.loadTasks()
            }
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
        TodayHeaderView(formattedDate: formattedDate)
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

    // MARK: - Quick Add Card
    private var quickAddCard: some View {
        QuickAddCardView(
            taskTitle: $quickTaskTitle,
            isFocused: $isQuickAddFocused,
            onAdd: addQuickTask,
            onShowAdvanced: { sheetPresentation = .addTask }
        )
    }

    // MARK: - Tasks Section
    private var tasksSection: some View {
        VStack(alignment: .leading, spacing: 8) {

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
        .padding(.top, 4)
    }

    // MARK: - Completed Section
    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        EmptyStateView.noTasks()
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

// MARK: - Preview
#Preview {
    TodayView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
