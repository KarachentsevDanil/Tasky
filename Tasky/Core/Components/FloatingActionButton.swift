//
//  FloatingActionButton.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// Floating Action Button (FAB) component for primary actions
struct FloatingActionButton: View {

    // MARK: - Properties
    let icon: String
    let action: () -> Void
    var color: Color = .blue
    var size: CGFloat = 60

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body
    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(color)
                        .shadow(color: color.opacity(0.4), radius: 8, y: 4)
                )
        }
        .accessibilityLabel("Add new task")
        .accessibilityHint("Double tap to create a new task")
    }
}

// MARK: - View Extension for Easy Placement
extension View {
    /// Add a floating action button to the view
    func floatingActionButton(
        icon: String = "plus",
        color: Color = .blue,
        action: @escaping () -> Void
    ) -> some View {
        ZStack(alignment: .bottomTrailing) {
            self

            FloatingActionButton(icon: icon, action: action, color: color)
                .padding(.trailing, Constants.Spacing.lg)
                .padding(.bottom, Constants.Spacing.lg)
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("Main Content")
            .font(.largeTitle)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(.systemGroupedBackground))
    .floatingActionButton {
        print("FAB tapped")
    }
}
