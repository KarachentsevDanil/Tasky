//
//  WeeklyGoalCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Compact weekly goal progress card
struct WeeklyGoalCard: View {

    // MARK: - Properties
    let completed: Int
    let goal: Int
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Computed
    private var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(completed) / Double(goal), 1.0)
    }

    private var progressPercentage: Int {
        Int(progress * 100)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 12) {
            // Chart Icon
            Text("📊")
                .font(.system(size: 32))

            // Progress Text
            Text("\(completed)/\(goal)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .contentTransition(.numericText())

            // Label
            Text("This Week")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * progress,
                            height: 6
                        )
                }
            }
            .frame(height: 6)

            // Percentage
            Text("\(progressPercentage)%")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.15)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    HStack(spacing: 16) {
        WeeklyGoalCard(completed: 19, goal: 25)
        WeeklyGoalCard(completed: 25, goal: 25)
    }
    .padding()
}
