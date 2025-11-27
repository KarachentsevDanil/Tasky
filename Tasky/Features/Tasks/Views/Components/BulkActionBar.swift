//
//  BulkActionBar.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI

/// Floating action bar for bulk operations during multi-select mode
struct BulkActionBar: View {

    @ObservedObject var viewModel: TaskListViewModel
    @State private var showingDatePicker = false
    @State private var showingListPicker = false
    @State private var showingPriorityPicker = false
    @State private var showingTagPicker = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Selection info
            HStack {
                Text("\(viewModel.selectedTasksCount) selected")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button("Select All") {
                    viewModel.selectAllTasks()
                    HapticManager.shared.lightImpact()
                }
                .font(.subheadline)

                Button("Done") {
                    viewModel.exitMultiSelectMode()
                }
                .font(.subheadline)
                .fontWeight(.semibold)
            }
            .padding(.horizontal)
            .padding(.vertical, Constants.Spacing.sm)

            Divider()

            // Action buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.lg) {
                    // Complete
                    BulkActionButton(
                        icon: "checkmark.circle.fill",
                        label: "Complete",
                        color: .green
                    ) {
                        Task {
                            await viewModel.bulkCompleteSelectedTasks()
                        }
                    }

                    // Reschedule
                    BulkActionButton(
                        icon: "calendar",
                        label: "Reschedule",
                        color: .blue
                    ) {
                        showingDatePicker = true
                    }

                    // Move to List
                    BulkActionButton(
                        icon: "folder",
                        label: "Move",
                        color: .orange
                    ) {
                        showingListPicker = true
                    }

                    // Priority
                    BulkActionButton(
                        icon: "flag.fill",
                        label: "Priority",
                        color: .red
                    ) {
                        showingPriorityPicker = true
                    }

                    // Add Tag
                    BulkActionButton(
                        icon: "tag",
                        label: "Tag",
                        color: .purple
                    ) {
                        showingTagPicker = true
                    }

                    // Delete
                    BulkActionButton(
                        icon: "trash",
                        label: "Delete",
                        color: .red
                    ) {
                        showingDeleteConfirmation = true
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, Constants.Spacing.md)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        .shadow(color: .black.opacity(0.1), radius: 8, y: -2)
        .sheet(isPresented: $showingDatePicker) {
            BulkDatePickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingListPicker) {
            BulkListPickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingPriorityPicker) {
            BulkPriorityPickerSheet(viewModel: viewModel)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingTagPicker) {
            BulkTagPickerSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
        .alert("Delete Tasks", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete \(viewModel.selectedTasksCount) Tasks", role: .destructive) {
                Task {
                    await viewModel.bulkDeleteSelectedTasks()
                }
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedTasksCount) tasks? This cannot be undone.")
        }
    }
}

// MARK: - Bulk Action Button

struct BulkActionButton: View {

    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            VStack(spacing: Constants.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)

                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 60)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk Date Picker Sheet

struct BulkDatePickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.lg) {
                // Quick options
                VStack(spacing: Constants.Spacing.sm) {
                    QuickDateButton(title: "Today", date: Date()) { date in
                        reschedule(to: date)
                    }
                    QuickDateButton(title: "Tomorrow", date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()) { date in
                        reschedule(to: date)
                    }
                    QuickDateButton(title: "Next Week", date: Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()) { date in
                        reschedule(to: date)
                    }
                }
                .padding(.horizontal)

                Divider()

                // Calendar picker
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle("Reschedule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        reschedule(to: selectedDate)
                    }
                }
            }
        }
    }

    private func reschedule(to date: Date) {
        Task {
            await viewModel.bulkRescheduleSelectedTasks(to: date)
            dismiss()
        }
    }
}

struct QuickDateButton: View {

    let title: String
    let date: Date
    let action: (Date) -> Void

    var body: some View {
        Button {
            action(date)
        } label: {
            HStack {
                Text(title)
                Spacer()
                Text(date, style: .date)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bulk List Picker Sheet

struct BulkListPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel

    var body: some View {
        NavigationStack {
            List {
                // Inbox option
                Button {
                    moveToList(nil)
                } label: {
                    HStack {
                        Image(systemName: "tray.fill")
                            .foregroundStyle(.gray)
                        Text("Inbox")
                        Spacer()
                    }
                }

                // Custom lists
                ForEach(viewModel.taskLists) { list in
                    Button {
                        moveToList(list)
                    } label: {
                        HStack {
                            Image(systemName: list.iconName ?? "list.bullet")
                                .foregroundStyle(list.color)
                            Text(list.name)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Move to List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func moveToList(_ list: TaskListEntity?) {
        Task {
            await viewModel.bulkMoveSelectedTasks(to: list)
            dismiss()
        }
    }
}

// MARK: - Bulk Priority Picker Sheet

struct BulkPriorityPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.md) {
                ForEach(Constants.TaskPriority.allCases, id: \.rawValue) { priority in
                    Button {
                        setPriority(priority)
                    } label: {
                        HStack {
                            if priority != .none {
                                Image(systemName: "flag.fill")
                                    .foregroundStyle(priority.color)
                            }
                            Text(priority.displayName)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("Set Priority")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func setPriority(_ priority: Constants.TaskPriority) {
        Task {
            await viewModel.bulkSetPriorityForSelectedTasks(priority.rawValue)
            dismiss()
        }
    }
}

// MARK: - Bulk Tag Picker Sheet

struct BulkTagPickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel

    var body: some View {
        NavigationStack {
            List {
                if viewModel.tags.isEmpty {
                    ContentUnavailableView(
                        "No Tags",
                        systemImage: "tag",
                        description: Text("Create tags in Settings to use them here")
                    )
                } else {
                    ForEach(viewModel.tags) { tag in
                        Button {
                            addTag(tag)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(tag.color)
                                    .frame(width: 12, height: 12)
                                Text(tag.name)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addTag(_ tag: TagEntity) {
        Task {
            await viewModel.bulkAddTagToSelectedTasks(tag)
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("Bulk Action Bar") {
    VStack {
        Spacer()
        BulkActionBar(
            viewModel: {
                let vm = TaskListViewModel(dataService: DataService(persistenceController: .preview))
                vm.isMultiSelectMode = true
                vm.selectedTaskIds = [UUID(), UUID(), UUID()]
                return vm
            }()
        )
    }
    .padding()
}

#Preview("Date Picker Sheet") {
    BulkDatePickerSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview))
    )
}

#Preview("Priority Picker Sheet") {
    BulkPriorityPickerSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview))
    )
}
