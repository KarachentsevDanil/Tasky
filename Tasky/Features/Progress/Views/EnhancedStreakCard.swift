//
//  EnhancedStreakCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Enhanced streak card with progress bar and motivational message
struct EnhancedStreakCard: View {

    // MARK: - Properties
    let currentStreak: Int
    let recordStreak: Int
    let message: String
    @State private var animateStreak = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 16) {
            // Flame Icon with glow effect
            ZStack {
                // Glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.orange.opacity(0.3), Color.clear],
                            center: .center,
                            startRadius: 20,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .scaleEffect(animateStreak ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateStreak)

                // Icon
                Text("🔥")
                    .font(.system(size: 60))
            }

            // Streak Count
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(currentStreak)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                }

                Text("Day Streak")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))
            }

            // Progress to next milestone
            if currentStreak < recordStreak {
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(.systemGray5))
                                .frame(height: 8)

                            // Progress
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geometry.size.width * (CGFloat(currentStreak) / CGFloat(recordStreak)),
                                    height: 8
                                )
                        }
                    }
                    .frame(height: 8)

                    Text("\(currentStreak) / \(recordStreak)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 20)
            }

            // Motivational Message
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        )
        .onAppear {
            animateStreak = true
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        EnhancedStreakCard(
            currentStreak: 12,
            recordStreak: 15,
            message: "3 more days to beat your record! 🎯"
        )

        EnhancedStreakCard(
            currentStreak: 20,
            recordStreak: 20,
            message: "New record! You're unstoppable! 🎉"
        )
    }
    .padding()
}
