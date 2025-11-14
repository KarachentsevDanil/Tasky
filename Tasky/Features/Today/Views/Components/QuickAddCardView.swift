//
//  QuickAddCardView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Quick task input card with add button and advanced options
struct QuickAddCardView: View {
    @Binding var taskTitle: String
    @FocusState.Binding var isFocused: Bool
    let onAdd: () -> Void
    let onShowAdvanced: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Blue + button (clickable to create task)
            Button {
                if !taskTitle.isEmpty {
                    onAdd()
                } else {
                    // If empty, focus the text field
                    isFocused = true
                }
                HapticManager.shared.lightImpact()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)

                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add quick task")
            .accessibilityHint(taskTitle.isEmpty ? "Focus text field to enter task" : "Create task with entered title")

            TextField("What do you want to accomplish?", text: $taskTitle)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit {
                    onAdd()
                }

            // Always show ellipsis for advanced options
            Button {
                HapticManager.shared.lightImpact()
                onShowAdvanced()
            } label: {
                Image(systemName: "ellipsis")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Advanced task options")
            .accessibilityHint("Open full task creation form with all options")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var taskTitle = ""
    @Previewable @FocusState var isFocused: Bool

    return QuickAddCardView(
        taskTitle: $taskTitle,
        isFocused: $isFocused,
        onAdd: { print("Add task") },
        onShowAdvanced: { print("Show advanced") }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("With Text") {
    @Previewable @State var taskTitle = "Buy groceries"
    @Previewable @FocusState var isFocused: Bool

    return QuickAddCardView(
        taskTitle: $taskTitle,
        isFocused: $isFocused,
        onAdd: { print("Add task") },
        onShowAdvanced: { print("Show advanced") }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
