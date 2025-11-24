//
//  QuickAddSheet.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// Quick add bottom sheet with pills for date and priority selection
struct QuickAddSheet: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @Binding var isPresented: Bool

    // MARK: - State
    @State private var taskTitle = ""
    @State private var selectedDate: QuickDate = .today
    @State private var selectedPriority: Constants.TaskPriority = .none
    @FocusState private var isFocused: Bool

    enum QuickDate: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case flexible = "Flexible"

        var icon: String {
            switch self {
            case .today: return "sun.max.fill"
            case .tomorrow: return "sunrise.fill"
            case .flexible: return "calendar"
            }
        }

        var date: Date? {
            let calendar = Calendar.current
            switch self {
            case .today:
                return calendar.startOfDay(for: Date())
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
            case .flexible:
                return nil
            }
        }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: Constants.Spacing.lg) {
                // Task input
                VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
                    Text("What do you need to do?")
                        .font(.headline)

                    TextField("Task title", text: $taskTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit {
                            addTask()
                        }
                }

                // Quick date selection
                VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
                    Text("When?")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: Constants.Spacing.sm) {
                        ForEach(QuickDate.allCases, id: \.self) { date in
                            quickDatePill(date)
                        }
                    }
                }

                // Priority selection
                VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
                    Text("Priority")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: Constants.Spacing.sm) {
                        quickPriorityPill(.none)
                        quickPriorityPill(.medium)
                        quickPriorityPill(.high)
                    }
                }

                Spacer()

                // Add button
                Button {
                    addTask()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Task")
                    }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
                }
                .disabled(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
            .padding()
            .navigationTitle("Quick Add")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isFocused = true
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Quick Date Pill
    @ViewBuilder
    private func quickDatePill(_ date: QuickDate) -> some View {
        Button {
            selectedDate = date
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: Constants.Spacing.xs) {
                Image(systemName: date.icon)
                    .font(.caption.weight(.semibold))

                Text(date.rawValue)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(selectedDate == date ? .white : .primary)
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.vertical, Constants.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall)
                    .fill(selectedDate == date ? Color.blue : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Priority Pill
    @ViewBuilder
    private func quickPriorityPill(_ priority: Constants.TaskPriority) -> some View {
        Button {
            selectedPriority = priority
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: Constants.Spacing.xs) {
                if priority != .none {
                    Image(systemName: "flag.fill")
                        .font(.caption.weight(.semibold))
                }

                Text(priority.displayName)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(selectedPriority == priority ? .white : .primary)
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.vertical, Constants.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall)
                    .fill(selectedPriority == priority ? priority.color : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Methods
    private func addTask() {
        let trimmedTitle = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        Task {
            await viewModel.createTask(
                title: trimmedTitle,
                dueDate: selectedDate.date,
                priority: selectedPriority.rawValue
            )

            await MainActor.run {
                HapticManager.shared.success()
                isPresented = false
                taskTitle = ""
                selectedDate = .today
                selectedPriority = .none
            }
        }
    }
}

// MARK: - Preview
#Preview {
    QuickAddSheet(
        viewModel: TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        ),
        isPresented: .constant(true)
    )
}
