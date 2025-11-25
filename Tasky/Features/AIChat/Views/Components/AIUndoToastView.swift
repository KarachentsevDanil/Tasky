//
//  AIUndoToastView.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// Toast view showing undo option for AI operations (5-second window)
/// Works with AIUndoManager for managing undo state
struct AIUndoToastView: View {
    @ObservedObject var undoManager: AIUndoManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if undoManager.showUndoToast, let action = undoManager.currentUndo {
            HStack(spacing: Constants.Spacing.sm) {
                // Action description
                Text(action.description)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                // Undo button
                Button {
                    undoManager.performUndo()
                } label: {
                    Text("Undo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .accessibilityLabel("Undo \(action.description)")
                .accessibilityHint("Double tap to undo this action")
            }
            .padding(.horizontal, Constants.Spacing.md)
            .padding(.vertical, Constants.Spacing.sm)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            .padding(.horizontal, Constants.Spacing.md)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: undoManager.showUndoToast)
        }
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @StateObject private var undoManager = AIUndoManager()

        var body: some View {
            VStack {
                Spacer()

                AIUndoToastView(undoManager: undoManager)

                Button("Show Toast") {
                    undoManager.registerUndo(
                        AIUndoManager.UndoableAction(
                            type: .complete,
                            description: "Completed 'Buy groceries'",
                            undoHandler: { print("Undo!") },
                            expiresAt: Date().addingTimeInterval(5.0)
                        )
                    )
                }
                .padding()
            }
        }
    }

    return PreviewWrapper()
}
