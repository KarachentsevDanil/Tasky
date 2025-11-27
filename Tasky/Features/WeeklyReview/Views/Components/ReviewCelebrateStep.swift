//
//  ReviewCelebrateStep.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Step 1: Celebrate the week's wins
struct ReviewCelebrateStep: View {

    // MARK: - Properties
    let data: WeekReviewData
    let showConfetti: Bool
    let onContinue: () -> Void

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State
    @State private var showStats = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.Spacing.xl) {
            Spacer()

            // Celebration Header
            VStack(spacing: Constants.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "party.popper.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                        .symbolEffect(.bounce, value: showConfetti)
                }

                Text("Great Week!")
                    .font(.largeTitle.weight(.bold))

                Text(data.weekRangeFormatted)
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            // Stats Grid
            if showStats {
                statsGrid
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
            }

            Spacer()

            // Continue Button
            Button {
                onContinue()
            } label: {
                Text("Continue")
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
            withAnimation(reduceMotion ? .none : .spring(response: 0.5, dampingFraction: 0.7).delay(0.3)) {
                showStats = true
            }
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        VStack(spacing: Constants.Spacing.lg) {
            HStack(spacing: Constants.Spacing.lg) {
                StatCard(
                    value: "\(data.completedCount)",
                    label: "Completed",
                    iconName: "checkmark.circle.fill",
                    color: .green
                )

                StatCard(
                    value: "\(data.createdCount)",
                    label: "Created",
                    iconName: "plus.circle.fill",
                    color: .blue
                )
            }

            HStack(spacing: Constants.Spacing.lg) {
                StatCard(
                    value: data.formattedFocusTime,
                    label: "Focus Time",
                    iconName: "timer",
                    color: .orange
                )

                StatCard(
                    value: "\(data.completionRate)%",
                    label: "Completion Rate",
                    iconName: "chart.line.uptrend.xyaxis",
                    color: .purple
                )
            }

            // Streak indicator
            if data.currentStreak > 0 {
                HStack(spacing: Constants.Spacing.sm) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(data.currentStreak) week streak!")
                        .font(.headline)
                        .foregroundStyle(.orange)
                }
                .padding(.top, Constants.Spacing.sm)
            }
        }
        .padding(.horizontal, Constants.Spacing.lg)
    }
}

// MARK: - Stat Card
private struct StatCard: View {
    let value: String
    let label: String
    let iconName: String
    let color: Color

    var body: some View {
        VStack(spacing: Constants.Spacing.sm) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.lg)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }
}

// MARK: - Preview
#Preview {
    ReviewCelebrateStep(
        data: WeekReviewData(
            weekStart: Date(),
            weekEnd: Date(),
            completedTasks: [],
            incompleteTasks: [],
            overdueTasks: [],
            upcomingTasks: [],
            createdCount: 12,
            totalFocusSeconds: 7200,
            currentStreak: 3
        ),
        showConfetti: true,
        onContinue: {}
    )
}
