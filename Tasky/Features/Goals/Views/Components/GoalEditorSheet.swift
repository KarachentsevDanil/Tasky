//
//  GoalEditorSheet.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Sheet for creating or editing a goal
struct GoalEditorSheet: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss

    // MARK: - Properties
    let existingGoal: GoalEntity?
    let onSave: (String, String?, Date?, String, String) async -> Void

    // MARK: - State
    @State private var name: String = ""
    @State private var notes: String = ""
    @State private var hasTargetDate = false
    @State private var targetDate = Date()
    @State private var selectedColorHex: String = "007AFF"
    @State private var selectedIconName: String = "target"
    @State private var isSaving = false
    @FocusState private var isNameFocused: Bool

    // MARK: - Constants
    private let availableColors = Constants.Colors.listColors
    private let availableIcons = [
        "target", "star.fill", "flag.fill", "rocket.fill", "lightbulb.fill",
        "book.fill", "briefcase.fill", "heart.fill", "bolt.fill", "trophy.fill",
        "graduationcap.fill", "house.fill", "airplane", "car.fill", "figure.run"
    ]

    // MARK: - Computed Properties
    private var isEditing: Bool {
        existingGoal != nil
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !isSaving
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Form {
                // Name Section
                Section {
                    TextField("Goal name", text: $name)
                        .focused($isNameFocused)
                        .submitLabel(.next)
                } header: {
                    Text("Name")
                }

                // Notes Section
                Section {
                    TextField("Optional description", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Description")
                }

                // Target Date Section
                Section {
                    Toggle("Set target date", isOn: $hasTargetDate)

                    if hasTargetDate {
                        DatePicker(
                            "Target date",
                            selection: $targetDate,
                            in: Date()...,
                            displayedComponents: .date
                        )
                    }
                } header: {
                    Text("Target Date")
                } footer: {
                    Text("A target date helps track your velocity toward the goal")
                }

                // Color Section
                Section {
                    colorPicker
                } header: {
                    Text("Color")
                }

                // Icon Section
                Section {
                    iconPicker
                } header: {
                    Text("Icon")
                }
            }
            .navigationTitle(isEditing ? "Edit Goal" : "New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Create") {
                        saveGoal()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadExistingGoal()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isNameFocused = true
                }
            }
        }
    }

    // MARK: - Color Picker
    private var colorPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: Constants.Spacing.md) {
            ForEach(availableColors, id: \.hex) { colorItem in
                Button {
                    selectedColorHex = colorItem.hex
                    HapticManager.shared.selectionChanged()
                } label: {
                    ZStack {
                        Circle()
                            .fill(colorItem.color)
                            .frame(width: 36, height: 36)

                        if selectedColorHex == colorItem.hex {
                            Circle()
                                .stroke(Color.primary, lineWidth: 2)
                                .frame(width: 44, height: 44)

                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(colorItem.name)
                .accessibilityAddTraits(selectedColorHex == colorItem.hex ? .isSelected : [])
            }
        }
        .padding(.vertical, Constants.Spacing.xs)
    }

    // MARK: - Icon Picker
    private var iconPicker: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: Constants.Spacing.md) {
            ForEach(availableIcons, id: \.self) { icon in
                Button {
                    selectedIconName = icon
                    HapticManager.shared.selectionChanged()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedIconName == icon ? Color.accentColor.opacity(0.15) : Color(.tertiarySystemFill))
                            .frame(width: 44, height: 44)

                        Image(systemName: icon)
                            .font(.title3)
                            .foregroundStyle(selectedIconName == icon ? Color.accentColor : Color.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(icon.replacingOccurrences(of: ".fill", with: ""))
                .accessibilityAddTraits(selectedIconName == icon ? .isSelected : [])
            }
        }
        .padding(.vertical, Constants.Spacing.xs)
    }

    // MARK: - Methods
    private func loadExistingGoal() {
        guard let goal = existingGoal else { return }

        name = goal.name
        notes = goal.notes ?? ""
        hasTargetDate = goal.targetDate != nil
        targetDate = goal.targetDate ?? Date()
        selectedColorHex = goal.colorHex ?? "007AFF"
        selectedIconName = goal.iconName ?? "target"
    }

    private func saveGoal() {
        guard canSave else { return }

        isSaving = true
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespaces)
        let finalTargetDate = hasTargetDate ? targetDate : nil

        Task {
            await onSave(
                trimmedName,
                trimmedNotes.isEmpty ? nil : trimmedNotes,
                finalTargetDate,
                selectedColorHex,
                selectedIconName
            )
            dismiss()
        }
    }
}

// MARK: - Preview
#Preview("New Goal") {
    GoalEditorSheet(existingGoal: nil) { _, _, _, _, _ in }
}

#Preview("Edit Goal") {
    GoalEditorSheet(existingGoal: PreviewGoalProvider.sampleGoal) { _, _, _, _, _ in }
}
