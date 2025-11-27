//
//  CalendarMainView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Unified calendar view with Day/Week modes for comprehensive task management
struct CalendarMainView: View {
    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @StateObject private var dayCalendarViewModel: DayCalendarViewModel
    @State private var selectedDate = Date()
    @State private var showQuickAdd = false
    @State private var showFullAddTask = false
    @State private var selectedView: ViewMode = .day
    @State private var undoAction: CalendarUndoAction?
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization
    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _dayCalendarViewModel = StateObject(wrappedValue: DayCalendarViewModel(dataService: viewModel.dataService))
    }

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case day = "Timeline"
        case upcoming = "Week"

        var icon: String {
            switch self {
            case .day: return "clock"
            case .upcoming: return "calendar"
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker - cleaner styling
                viewModePicker

                // Content based on selected view
                Group {
                    switch selectedView {
                    case .day:
                        dayView
                    case .upcoming:
                        upcomingView
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .floatingActionButton(isVisible: selectedView == .upcoming) {
                showQuickAdd = true
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showQuickAdd) {
                QuickAddSheet(
                    viewModel: viewModel,
                    isPresented: $showQuickAdd,
                    onShowFullForm: {
                        showFullAddTask = true
                    },
                    preselectedDate: currentPreselectedDate
                )
            }
            .navigationDestination(isPresented: $showFullAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK") {
                    viewModel.showError = false
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
            .task {
                viewModel.currentFilter = .all
                await viewModel.loadTasks()
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
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack(spacing: Constants.Spacing.sm) {
            ForEach(ViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        selectedView = mode
                    }
                    HapticManager.shared.selectionChanged()
                } label: {
                    HStack(spacing: Constants.Spacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.subheadline.weight(.medium))

                        Text(mode.rawValue)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(selectedView == mode ? .white : .primary)
                    .padding(.horizontal, Constants.Spacing.md)
                    .padding(.vertical, Constants.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedView == mode ? Color.accentColor : Color(.tertiarySystemFill))
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.vertical, Constants.Spacing.sm)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("View mode")
        .accessibilityHint("Switch between timeline and week views")
    }

    // MARK: - Day View
    private var dayView: some View {
        DayCalendarView(
            viewModel: dayCalendarViewModel,
            taskListViewModel: viewModel,
            timerViewModel: timerViewModel
        )
    }

    // MARK: - Upcoming View
    private var upcomingView: some View {
        VStack(spacing: 0) {
            // Week Strip Calendar
            WeekStripView(
                selectedDate: $selectedDate,
                tasksForDate: tasksForDate
            )

            // Task List for Selected Day
            ScrollView {
                CalendarTaskListView(
                    selectedDate: selectedDate,
                    tasks: tasksForDate(selectedDate),
                    viewModel: viewModel,
                    timerViewModel: timerViewModel,
                    undoAction: $undoAction
                )
                .padding(.bottom, Constants.Spacing.xxxl)
            }
            .refreshable {
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Computed Properties

    /// Returns the appropriate preselected date based on current view mode
    private var currentPreselectedDate: Date {
        switch selectedView {
        case .day:
            return dayCalendarViewModel.selectedDate
        case .upcoming:
            return selectedDate
        }
    }

    // MARK: - Tasks For Date Helper
    private func tasksForDate(_ date: Date) -> [TaskEntity] {
        viewModel.tasks.filter { task in
            if let dueDate = task.dueDate {
                if Calendar.current.isDate(dueDate, inSameDayAs: date) {
                    return true
                }
            }
            if let scheduledTime = task.scheduledTime {
                if Calendar.current.isDate(scheduledTime, inSameDayAs: date) {
                    return true
                }
            }
            return false
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarMainView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
