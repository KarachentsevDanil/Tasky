//
//  CompactStreakCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Compact streak card for side-by-side layout in Overview tab
struct CompactStreakCard: View {

    // MARK: - Properties
    let currentStreak: Int
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            // Flame Icon
            Text("🔥")
                .font(.system(size: 32))

            // Streak Count
            Text("\(currentStreak)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            // Label
            Text("Day\nStreak")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.15), Color.red.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 16) {
        CompactStreakCard(currentStreak: 5)
        CompactStreakCard(currentStreak: 12)
    }
    .padding()
}
