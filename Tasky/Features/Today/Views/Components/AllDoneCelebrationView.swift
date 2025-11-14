//
//  AllDoneCelebrationView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Full-screen celebration when all tasks are completed
struct AllDoneCelebrationView: View {

    // MARK: - Properties
    @Environment(\.dismiss) var dismiss
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @AppStorage("currentStreak") private var currentStreak: Int = 0
    @AppStorage("lastCompletionDate") private var lastCompletionDateString: String = ""

    let tasksCompletedCount: Int
    let onShare: () -> Void

    // MARK: - State
    @State private var showContent = false
    @State private var showRing = false
    @State private var showConfetti = false

    // MARK: - Computed Properties
    private var isNewStreak: Bool {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = ISO8601DateFormatter().date(from: lastCompletionDateString) {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            return daysDiff == 1
        }

        return false
    }

    private var streakText: String {
        if currentStreak > 1 {
            return "\(currentStreak) day streak!"
        } else {
            return "Keep it up!"
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background with gradient
            LinearGradient(
                colors: [
                    Color.blue.opacity(0.3),
                    Color.purple.opacity(0.3),
                    Color.pink.opacity(0.3)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .blur(radius: 40)

            // Content
            VStack(spacing: 24) {
                Spacer()

                // Celebration Title
                if showContent {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 56, weight: .medium))
                            .foregroundStyle(.purple)
                            .symbolEffect(.bounce, value: showContent)
                            .accessibilityHidden(true)

                        Text("All Done!")
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("All done! You completed \(tasksCompletedCount) tasks today")
                }

                // Completion Ring - Clean, no overlapping text
                if showRing {
                    CompletionRingView(
                        completed: tasksCompletedCount,
                        total: tasksCompletedCount,
                        lineWidth: 12
                    )
                    .frame(width: 200, height: 200)
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                        .frame(width: 200, height: 200)
                }

                // Celebration Message
                if showContent {
                    VStack(spacing: 16) {
                        Text("Time to relax and recharge")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)

                        // Streak indicator
                        if currentStreak > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.orange)

                                Text(streakText)
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.15))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .multilineTextAlignment(.center)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                // Action Buttons
                if showContent {
                    VStack(spacing: 16) {
                        Button {
                            HapticManager.shared.lightImpact()
                            onShare()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.body.weight(.semibold))
                                Text("Share Achievement")
                                    .font(.headline)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: Color.purple.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Share achievement")
                        .accessibilityHint("Share your accomplishment of completing \(tasksCompletedCount) tasks")

                        Button {
                            HapticManager.shared.lightImpact()
                            dismiss()
                        } label: {
                            Text("Close")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                        .accessibilityHint("Dismiss celebration screen")
                    }
                    .padding(.horizontal, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 50)
            .padding(.bottom, 20)
        }
        .confetti(isPresented: $showConfetti)
        .onAppear {
            startCelebration()
            updateStreak()
        }
    }

    // MARK: - Animation
    private func startCelebration() {
        guard !reduceMotion else {
            showContent = true
            showRing = true
            return
        }

        // Haptic feedback
        HapticManager.shared.success()

        // Show confetti immediately
        showConfetti = true

        // Staggered animation sequence
        // 1. Show ring first
        withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1)) {
            showRing = true
        }

        // 2. Show content (title, message, buttons)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4)) {
            showContent = true
        }

        // Note: Removed auto-dismiss - let user choose when to close
    }

    // MARK: - Streak Management
    private func updateStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let todayString = ISO8601DateFormatter().string(from: today)

        if lastCompletionDateString.isEmpty {
            // First completion ever
            currentStreak = 1
            lastCompletionDateString = todayString
        } else if let lastDate = ISO8601DateFormatter().date(from: lastCompletionDateString) {
            let lastDay = calendar.startOfDay(for: lastDate)
            let daysDiff = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0

            if daysDiff == 0 {
                // Already completed today, no change
                return
            } else if daysDiff == 1 {
                // Consecutive day
                currentStreak += 1
                lastCompletionDateString = todayString
            } else {
                // Streak broken
                currentStreak = 1
                lastCompletionDateString = todayString
            }
        }
    }
}

// MARK: - Preview
#Preview {
    AllDoneCelebrationView(
        tasksCompletedCount: 8,
        onShare: { print("Share tapped") }
    )
}

#Preview("With Streak") {
    @Previewable @AppStorage("currentStreak") var streak = 5

    return AllDoneCelebrationView(
        tasksCompletedCount: 12,
        onShare: { print("Share tapped") }
    )
}
