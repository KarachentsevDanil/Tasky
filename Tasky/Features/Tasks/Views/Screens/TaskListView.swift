//
//  TaskListView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// View for displaying a list of tasks with different filters
struct TaskListView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel
    @StateObject private var timerViewModel = FocusTimerViewModel()
    let filterType: TaskListViewModel.FilterType
    let title: String

    // MARK: - State
    @State private var showingAddTask = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.tasks.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddTask = true
                    } label: {
                        Image(systemName: Constants.Icons.add)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                viewModel.currentFilter = filterType
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Task List View
    private var taskListView: some View {
        List {
            ForEach(viewModel.tasks, id: \.id) { task in
                NavigationLink {
                    TaskDetailView(viewModel: viewModel, timerViewModel: timerViewModel, task: task)
                } label: {
                    TaskRowView(task: task) {
                        Task {
                            await viewModel.toggleTaskCompletion(task)
                        }
                    }
                }
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
                        Label("Delete", systemImage: Constants.Icons.delete)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(emptyStateTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(emptyStateMessage)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                showingAddTask = true
            } label: {
                Label("Add Task", systemImage: Constants.Icons.add)
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            }
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Empty State Content
    private var emptyStateIcon: String {
        switch filterType {
        case .today:
            return Constants.Icons.today
        case .upcoming:
            return Constants.Icons.upcoming
        case .inbox:
            return Constants.Icons.inbox
        case .completed:
            return Constants.Icons.completed
        default:
            return Constants.Icons.list
        }
    }

    private var emptyStateTitle: String {
        switch filterType {
        case .today:
            return "No tasks for today"
        case .upcoming:
            return "No upcoming tasks"
        case .inbox:
            return "Inbox is empty"
        case .completed:
            return "No completed tasks"
        default:
            return "No tasks"
        }
    }

    private var emptyStateMessage: String {
        switch filterType {
        case .today:
            return "You don't have any tasks due today. Enjoy your free time!"
        case .upcoming:
            return "No tasks scheduled for the next 7 days."
        case .inbox:
            return "Your inbox is clear. Add new tasks to get started."
        case .completed:
            return "Complete tasks to see them here."
        default:
            return "Add your first task to get organized."
        }
    }
}

// MARK: - Preview
#Preview("Today - Empty") {
    TaskListView(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        filterType: .today,
        title: "Today"
    )
}

#Preview("Inbox - With Tasks") {
    TaskListView(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)),
        filterType: .inbox,
        title: "Inbox"
    )
}
