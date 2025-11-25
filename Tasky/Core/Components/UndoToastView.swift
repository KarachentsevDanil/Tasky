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

    // MARK: - Constants
    private let autoDismissSeconds: Double = 5.0
    private let timerInterval: Double = 0.05

    // MARK: - State
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var offset: CGFloat = 100
    @State private var progress: CGFloat = 1.0
    @State private var timer: Timer?

    var body: some View {
        HStack(spacing: 12) {
            // Circular countdown timer with icon
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 2.5)
                    .frame(width: 28, height: 28)

                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.accentColor,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-90))

                // Icon in center
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
                    .font(.caption.weight(.medium))
            }

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                HapticManager.shared.lightImpact()
                stopTimer()
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
            startCountdown()
        }
        .onDisappear {
            stopTimer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message). Double tap undo button to restore.")
    }

    // MARK: - Timer Methods

    private func startCountdown() {
        progress = 1.0
        let decrementAmount = timerInterval / autoDismissSeconds

        timer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { _ in
            if progress > 0 {
                withAnimation(reduceMotion ? .none : .linear(duration: timerInterval)) {
                    progress -= decrementAmount
                }
            } else {
                stopTimer()
                dismissToast()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
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
