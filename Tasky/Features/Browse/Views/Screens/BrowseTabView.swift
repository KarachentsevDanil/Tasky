//
//  BrowseTabView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Browse tab combining Progress, Lists, and quick access to features
/// Following Todoist's Browse tab pattern for unified navigation
struct BrowseTabView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel

    // MARK: - State
    @State private var showingAddList = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // All Tasks Section
                Section {
                    NavigationLink {
                        AllTasksView(viewModel: viewModel)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "list.bullet")
                                .font(.title3)
                                .foregroundStyle(.purple)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("All Tasks")
                                    .font(.body.weight(.semibold))

                                Text("Complete prioritized task list")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if viewModel.tasks.filter({ !$0.isCompleted }).count > 0 {
                                Text("\(viewModel.tasks.filter { !$0.isCompleted }.count)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.purple)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    NavigationLink {
                        ProgressTabView(viewModel: viewModel)
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Progress & Stats")
                                    .font(.body.weight(.semibold))

                                Text("View your achievements and analytics")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Overview")
                }

                // Smart Lists Section
                Section {
                    NavigationLink {
                        TaskListView(
                            viewModel: viewModel,
                            filterType: .today,
                            title: "Today"
                        )
                    } label: {
                        smartListRow(
                            icon: Constants.Icons.today,
                            title: "Today",
                            color: .blue,
                            count: viewModel.todayTasksCount
                        )
                    }

                    NavigationLink {
                        TaskListView(
                            viewModel: viewModel,
                            filterType: .upcoming,
                            title: "Upcoming"
                        )
                    } label: {
                        smartListRow(
                            icon: Constants.Icons.upcoming,
                            title: "Upcoming",
                            color: .orange,
                            count: viewModel.upcomingTasksCount
                        )
                    }

                    NavigationLink {
                        TaskListView(
                            viewModel: viewModel,
                            filterType: .inbox,
                            title: "Inbox"
                        )
                    } label: {
                        smartListRow(
                            icon: Constants.Icons.inbox,
                            title: "Inbox",
                            color: .gray,
                            count: viewModel.inboxTasksCount
                        )
                    }

                    NavigationLink {
                        TaskListView(
                            viewModel: viewModel,
                            filterType: .completed,
                            title: "Completed"
                        )
                    } label: {
                        smartListRow(
                            icon: "checkmark.circle.fill",
                            title: "Completed",
                            color: .green,
                            count: 0
                        )
                    }
                } header: {
                    Text("Smart Lists")
                }

                // Custom Lists Section
                Section {
                    ForEach(viewModel.taskLists, id: \.id) { list in
                        NavigationLink {
                            CustomTaskListView(viewModel: viewModel, list: list)
                        } label: {
                            HStack {
                                Image(systemName: list.iconName ?? Constants.Icons.list)
                                    .foregroundStyle(list.color)
                                    .frame(width: 32)

                                Text(list.name)

                                Spacer()

                                if list.incompleteTasksCount > 0 {
                                    Text("\(list.incompleteTasksCount)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { indexSet in
                        deleteLists(at: indexSet)
                    }

                    Button {
                        showingAddList = true
                    } label: {
                        Label("New List", systemImage: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                    .disabled(viewModel.taskLists.count >= Constants.Limits.maxCustomLists)
                } header: {
                    HStack {
                        Text("My Lists")
                        Spacer()
                        Text("\(viewModel.taskLists.count)/\(Constants.Limits.maxCustomLists)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // Settings Row
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.gray)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Settings")
                                    .font(.body.weight(.semibold))

                                Text("Preferences and app settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Browse")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await viewModel.loadTaskLists()
            }
            .sheet(isPresented: $showingAddList) {
                AddListView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadTaskLists()
            }
        }
    }

    // MARK: - Smart List Row
    private func smartListRow(icon: String, title: String, color: Color, count: Int) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 32)

            Text(title)

            Spacer()

            if count > 0 {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Methods
    private func deleteLists(at offsets: IndexSet) {
        for index in offsets {
            let list = viewModel.taskLists[index]
            Task {
                await viewModel.deleteTaskList(list)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    BrowseTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
