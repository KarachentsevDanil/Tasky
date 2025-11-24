//
//  CalendarMainView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Unified view with Day/Upcoming modes for calendar and task management
struct CalendarMainView: View {
    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var upcomingViewModel: UpcomingViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    @StateObject private var dayCalendarViewModel: DayCalendarViewModel
    @State private var selectedDate = Date()
    @State private var showingAddTask = false
    @State private var selectedView: ViewMode = .day

    // MARK: - Initialization
    init(viewModel: TaskListViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _upcomingViewModel = StateObject(wrappedValue: UpcomingViewModel(taskListViewModel: viewModel))
        _dayCalendarViewModel = StateObject(wrappedValue: DayCalendarViewModel(dataService: viewModel.dataService))
    }

    // MARK: - View Mode
    enum ViewMode: String, CaseIterable {
        case day = "Day"
        case upcoming = "Upcoming"
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // View Mode Picker
                Picker("View", selection: $selectedView) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedView) { _ in
                    HapticManager.shared.selectionChanged()
                }
                .padding()
                .accessibilityLabel("View mode")
                .accessibilityHint("Switch between day view and upcoming list view")

                Divider()

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
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        HapticManager.shared.lightImpact()
                        showingAddTask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel("Add task")
                    .accessibilityHint("Create a new task")
                }
            }
            .navigationDestination(isPresented: $showingAddTask) {
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
        }
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
        ScrollView {
            VStack(spacing: 0) {
                // Mini Calendar
                MiniCalendarSection(
                    selectedDate: $selectedDate,
                    selectedDateForFiltering: $upcomingViewModel.selectedDateForFiltering,
                    tasks: viewModel.tasks,
                    tasksForDate: upcomingViewModel.tasksForDate
                )

                Divider()

                // Upcoming Tasks List
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    ForEach(upcomingViewModel.groupedTasks, id: \.date) { group in
                        Section {
                            VStack(spacing: 0) {
                                ForEach(group.tasks) { task in
                                    NavigationLink {
                                        TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                                    } label: {
                                        UpcomingTaskRow(task: task, timerViewModel: timerViewModel) {
                                            Task {
                                                await viewModel.toggleTaskCompletion(task)
                                                HapticManager.shared.success()
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task {
                                                await viewModel.deleteTask(task)
                                            }
                                        } label: {
                                            Label("Delete", systemImage: Constants.Icons.delete)
                                        }
                                    }
                                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                        Button {
                                            Task {
                                                await viewModel.toggleTaskCompletion(task)
                                                HapticManager.shared.success()
                                            }
                                        } label: {
                                            Label(
                                                task.isCompleted ? "Incomplete" : "Complete",
                                                systemImage: task.isCompleted ? "circle" : "checkmark.circle.fill"
                                            )
                                        }
                                        .tint(.green)
                                    }
                                    .contextMenu {
                                        Button {
                                            Task {
                                                await viewModel.toggleTaskCompletion(task)
                                                HapticManager.shared.success()
                                            }
                                        } label: {
                                            Label(
                                                task.isCompleted ? "Mark as Incomplete" : "Mark as Complete",
                                                systemImage: task.isCompleted ? "circle" : "checkmark.circle"
                                            )
                                        }

                                        Divider()

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
                            .padding(.horizontal)
                        } header: {
                            upcomingDateHeader(for: group.date)
                        }
                    }

                    if upcomingViewModel.groupedTasks.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    }
                }
                .padding(.vertical)
            }
        }
        .refreshable {
            await viewModel.loadTasks()
        }
    }

    // MARK: - Date Header
    private func upcomingDateHeader(for date: Date) -> some View {
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isTomorrow = calendar.isDateInTomorrow(date)

        let dateText: String = {
            if isToday {
                return "Today"
            } else if isTomorrow {
                return "Tomorrow"
            } else {
                return AppDateFormatters.shortDayMonthFormatter.string(from: date)
            }
        }()

        let fullDateText = AppDateFormatters.shortDayMonthFormatter.string(from: date)

        return HStack(spacing: 8) {
            Text(dateText)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            if isToday || isTomorrow {
                Text("· \(fullDateText)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 60))
                .foregroundStyle(.green.gradient)

            Text("All Caught Up!")
                .font(.title2.weight(.bold))

            Text("You don't have any upcoming tasks.\nTap + to add a new task.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Preview
#Preview {
    CalendarMainView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
