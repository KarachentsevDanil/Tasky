//
//  ReviewSummaryStep.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Step 5: Review completion summary
struct ReviewSummaryStep: View {

    // MARK: - Properties
    let newStreak: Int
    let deletedCount: Int
    let rescheduledCount: Int
    let keptCount: Int
    let onComplete: () -> Void

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State
    @State private var showContent = false
    @State private var showConfetti = false

    // MARK: - Computed Properties
    private var totalActions: Int {
        deletedCount + rescheduledCount + keptCount
    }

    private var streakMessage: String {
        if newStreak == 1 {
            return "You've started your review streak!"
        } else if newStreak < 5 {
            return "Keep it up! \(newStreak) weeks strong."
        } else if newStreak < 10 {
            return "Amazing consistency! \(newStreak) weeks."
        } else {
            return "Incredible! \(newStreak) week streak!"
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.Spacing.xl) {
            Spacer()

            // Completion header
            if showContent {
                completionHeader
                    .transition(.scale.combined(with: .opacity))
            }

            // Streak card
            if showContent && newStreak > 0 {
                streakCard
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            // Actions summary
            if showContent && totalActions > 0 {
                actionsSummary
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Spacer()

            // Done button
            Button {
                onComplete()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Constants.Spacing.md)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.bottom, Constants.Spacing.xl)
        }
        .overlay {
            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            animateIn()
        }
    }

    // MARK: - Completion Header
    private var completionHeader: some View {
        VStack(spacing: Constants.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.15))
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: showConfetti)
            }

            Text("Review Complete!")
                .font(.largeTitle.weight(.bold))

            Text("You're all set for the week ahead")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(spacing: Constants.Spacing.md) {
            HStack(spacing: Constants.Spacing.sm) {
                Image(systemName: "flame.fill")
                    .font(.title)
                    .foregroundStyle(.orange)

                Text("\(newStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text(streakMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Constants.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [.orange.opacity(0.1), .yellow.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        .padding(.horizontal, Constants.Spacing.lg)
    }

    // MARK: - Actions Summary
    private var actionsSummary: some View {
        VStack(spacing: Constants.Spacing.md) {
            Text("This Review")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)

            HStack(spacing: Constants.Spacing.xl) {
                if deletedCount > 0 {
                    SummaryBadge(
                        count: deletedCount,
                        label: "Deleted",
                        color: .red
                    )
                }

                if rescheduledCount > 0 {
                    SummaryBadge(
                        count: rescheduledCount,
                        label: "Rescheduled",
                        color: .blue
                    )
                }

                if keptCount > 0 {
                    SummaryBadge(
                        count: keptCount,
                        label: "Kept",
                        color: .green
                    )
                }
            }
        }
        .padding(.horizontal, Constants.Spacing.lg)
    }

    // MARK: - Animation
    private func animateIn() {
        let animation: Animation = reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.7)

        withAnimation(animation.delay(0.2)) {
            showContent = true
        }

        if !reduceMotion && newStreak > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showConfetti = true
                HapticManager.shared.success()
            }
        }
    }
}

// MARK: - Summary Badge
private struct SummaryBadge: View {
    let count: Int
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Constants.Spacing.xs) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Preview
#Preview {
    ReviewSummaryStep(
        newStreak: 5,
        deletedCount: 3,
        rescheduledCount: 7,
        keptCount: 2,
        onComplete: {}
    )
}
