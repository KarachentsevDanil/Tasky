//
//  UndoToastView.swift
//  Tasky
//
//  Created by Danylo Karachentsev
//

import SwiftUI

/// Toast notification with undo action for destructive operations
struct UndoToastView: View {

    let icon: String
    let message: String
    let onUndo: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var offset: CGFloat = 100

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.body.weight(.medium))

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                HapticManager.shared.lightImpact()
                onUndo()
            } label: {
                Text("Undo")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.horizontal, 16)
        .offset(y: offset)
        .onAppear {
            withAnimation(reduceMotion ? .none : .spring(response: 0.35, dampingFraction: 0.7)) {
                offset = 0
            }

            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                dismissToast()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Double tap undo button to restore.")
    }

    private func dismissToast() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8)) {
            offset = 100
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - View Extension
extension View {
    /// Shows an undo toast at the bottom of the screen
    func undoToast(
        isPresented: Binding<Bool>,
        icon: String,
        message: String,
        onUndo: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .bottom) {
            self

            if isPresented.wrappedValue {
                UndoToastView(
                    icon: icon,
                    message: message,
                    onUndo: {
                        // Call onUndo FIRST so parent can capture state before it's cleared
                        onUndo()
                        // Then dismiss the toast
                        isPresented.wrappedValue = false
                    },
                    onDismiss: {
                        isPresented.wrappedValue = false
                    }
                )
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(999)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Spacer()
        Text("Swipe a task to test")
            .foregroundStyle(.secondary)
        Spacer()
    }
    .undoToast(
        isPresented: .constant(true),
        icon: "trash",
        message: "Task deleted",
        onUndo: {
            print("Undo tapped")
        }
    )
}
