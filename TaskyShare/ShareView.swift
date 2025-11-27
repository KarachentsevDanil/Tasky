//
//  ShareView.swift
//  TaskyShare
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Minimal SwiftUI interface for the Share Extension
struct ShareView: View {

    let content: SharedContent
    let onSave: (String, String?) -> Void
    let onCancel: () -> Void

    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @FocusState private var isTitleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $title)
                        .focused($isTitleFocused)
                        .autocorrectionDisabled(false)
                } header: {
                    Text("Title")
                }

                if !notes.isEmpty || content.url != nil {
                    Section {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                    } header: {
                        Text("Notes")
                    }
                }
            }
            .navigationTitle("Add to Tasky")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                    .fontWeight(.semibold)
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .onAppear {
            // Pre-fill from shared content
            title = content.title
            notes = content.notes ?? ""

            // Focus title field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTitleFocused = true
            }
        }
    }

    private func save() {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSaving = true

        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            onSave(
                title.trimmingCharacters(in: .whitespaces),
                notes.isEmpty ? nil : notes
            )
        }
    }
}

// MARK: - Preview

#Preview {
    ShareView(
        content: SharedContent(
            title: "Check out this article",
            notes: "https://example.com/article",
            url: URL(string: "https://example.com/article")
        ),
        onSave: { title, notes in
            print("Save: \(title), \(notes ?? "no notes")")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}
