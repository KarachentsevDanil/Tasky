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
            VStack(spacing: 32) {
                Spacer()

                // Completion Ring
                ZStack {
                    if showRing {
                        CompletionRingView(
                            completed: tasksCompletedCount,
                            total: tasksCompletedCount,
                            lineWidth: 12
                        )
                        .frame(width: 160, height: 160)
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                            .frame(width: 160, height: 160)
                    }

                    if showContent {
                        VStack(spacing: 4) {
                            Text("completed")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }

                // Celebration Message
                if showContent {
                    VStack(spacing: 12) {
                        Text("Time to relax and recharge")
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        // Streak indicator
                        if currentStreak > 0 {
                            HStack(spacing: 8) {
                                Image(systemName: "flame.fill")
                                    .foregroundStyle(.orange)

                                Text(streakText)
                                    .font(.headline)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.orange.opacity(0.15))
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
                    VStack(spacing: 12) {
                        Button {
                            HapticManager.shared.lightImpact()
                            onShare()
                        } label: {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Achievement")
                            }
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
                        }

                        Button {
                            HapticManager.shared.lightImpact()
                            dismiss()
                        } label: {
                            Text("Close")
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
                        }
                    }
                    .padding(.horizontal, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.vertical, 40)
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

        // Show ring with animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
            showRing = true
        }

        // Show content with delay
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5)) {
            showContent = true
        }

        // Auto-dismiss after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if showContent {
                dismiss()
            }
        }
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
