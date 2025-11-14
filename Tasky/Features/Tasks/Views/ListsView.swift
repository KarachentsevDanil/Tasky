//
//  ListsView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// View for managing task lists
struct ListsView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel

    // MARK: - State
    @State private var showingAddList = false

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // Smart Lists Section
                Section("Smart Lists") {
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
                                    .frame(width: Constants.UI.iconSize)

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
                } header: {
                    HStack {
                        Text("My Lists")
                        Spacer()
                        Text("\(viewModel.taskLists.count)/\(Constants.Limits.maxCustomLists)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddList = true
                    } label: {
                        Image(systemName: Constants.Icons.add)
                    }
                    .disabled(viewModel.taskLists.count >= Constants.Limits.maxCustomLists)
                }
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
                .frame(width: Constants.UI.iconSize)

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

// MARK: - Custom Task List View
struct CustomTaskListView: View {
    @ObservedObject var viewModel: TaskListViewModel
    let list: TaskListEntity

    var body: some View {
        TaskListView(
            viewModel: viewModel,
            filterType: .list(list),
            title: list.name
        )
    }
}

// MARK: - Add List View
struct AddListView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel

    // MARK: - State
    @State private var name = ""
    @State private var selectedColor = Constants.Colors.listColors[0]
    @State private var selectedIcon = "list.bullet"

    // Available icons for lists
    private let availableIcons = [
        "list.bullet", "folder.fill", "briefcase.fill", "house.fill",
        "cart.fill", "heart.fill", "star.fill", "flag.fill",
        "book.fill", "graduationcap.fill", "gift.fill", "cup.and.saucer.fill"
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("List name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Name")
                }

                // Color Section
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Constants.UI.padding) {
                            ForEach(Constants.Colors.listColors, id: \.hex) { colorOption in
                                Circle()
                                    .fill(colorOption.color)
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if selectedColor.hex == colorOption.hex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .onTapGesture {
                                        selectedColor = colorOption
                                    }
                            }
                        }
                        .padding(.vertical, Constants.UI.smallPadding)
                    }
                } header: {
                    Text("Color")
                }

                // Icon Section
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: Constants.UI.padding) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundStyle(selectedColor.color)
                                .frame(width: 60, height: 60)
                                .background(
                                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                                        .fill(selectedIcon == icon ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                                        .stroke(selectedIcon == icon ? Color.accentColor : Color.clear, lineWidth: 2)
                                }
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                } header: {
                    Text("Icon")
                }
            }
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addList()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    // MARK: - Methods
    private func addList() {
        Task {
            await viewModel.createTaskList(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                colorHex: selectedColor.hex,
                iconName: selectedIcon
            )
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("Lists View") {
    ListsView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}

#Preview("Add List View") {
    AddListView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
