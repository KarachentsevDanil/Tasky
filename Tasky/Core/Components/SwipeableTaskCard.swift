//
//  SwipeableTaskCard.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// A wrapper that adds swipe-to-complete and swipe-to-delete functionality to task cards
/// Works in ScrollView (unlike .swipeActions which only works in List)
struct SwipeableTaskCard<Content: View>: View {

    // MARK: - Properties
    let content: Content
    let onComplete: () -> Void
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var isSwiping = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants
    private let actionThreshold: CGFloat = 80
    private let maxOffset: CGFloat = 100
    private let actionButtonWidth: CGFloat = 80

    // MARK: - Initialization
    init(
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.onComplete = onComplete
        self.onDelete = onDelete
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                // Left side - Complete action (revealed when swiping right)
                completeAction

                Spacer()

                // Right side - Delete action (revealed when swiping left)
                deleteAction
            }

            // Main content
            content
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusSmall))
        // Accessibility actions for VoiceOver users who can't swipe
        .accessibilityAction(named: "Complete") {
            triggerComplete()
        }
        .accessibilityAction(named: "Delete") {
            triggerDelete()
        }
    }

    // MARK: - Complete Action (Left side - revealed when swiping right)
    private var completeAction: some View {
        ZStack {
            Color.green

            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(.leading, Constants.Spacing.lg)

                Spacer()
            }
        }
        .frame(width: max(0, offset))
        .opacity(offset > 0 ? 1 : 0)
    }

    // MARK: - Delete Action (Right side - revealed when swiping left)
    private var deleteAction: some View {
        ZStack {
            Color.red

            HStack {
                Spacer()

                Image(systemName: "trash.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .padding(.trailing, Constants.Spacing.lg)
            }
        }
        .frame(width: max(0, -offset))
        .opacity(offset < 0 ? 1 : 0)
    }

    // MARK: - Swipe Gesture
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let translation = value.translation.width

                // Only allow horizontal swipes (not diagonal)
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    return
                }

                isSwiping = true

                // Apply resistance at the edges
                if translation > 0 {
                    // Swiping right (complete)
                    offset = min(translation * 0.8, maxOffset)
                } else {
                    // Swiping left (delete)
                    offset = max(translation * 0.8, -maxOffset)
                }
            }
            .onEnded { value in
                isSwiping = false

                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width - translation

                // Check if threshold was met
                if offset > actionThreshold || (offset > 40 && velocity > 100) {
                    // Complete action triggered (swipe right)
                    triggerComplete()
                } else if offset < -actionThreshold || (offset < -40 && velocity < -100) {
                    // Delete action triggered (swipe left)
                    triggerDelete()
                } else {
                    // Reset position
                    resetPosition()
                }
            }
    }

    // MARK: - Actions
    private func triggerComplete() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
        HapticManager.shared.success()
        onComplete()
    }

    private func triggerDelete() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
        HapticManager.shared.mediumImpact()
        onDelete()
    }

    private func resetPosition() {
        withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
            offset = 0
        }
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        VStack(spacing: Constants.Spacing.sm) {
            SwipeableTaskCard(
                onComplete: { print("Complete") },
                onDelete: { print("Delete") }
            ) {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray)
                    Text("Swipe right to complete, left to delete")
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            SwipeableTaskCard(
                onComplete: { print("Complete 2") },
                onDelete: { print("Delete 2") }
            ) {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.gray)
                    Text("Another task to swipe")
                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
