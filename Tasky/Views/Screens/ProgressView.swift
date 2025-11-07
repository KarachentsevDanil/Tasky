//
//  ProgressView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Progress and stats view with streaks and achievements
struct ProgressTabView: View {

    // MARK: - Properties
    @StateObject var viewModel: TaskListViewModel

    // MARK: - Computed Properties
    private var completedThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return viewModel.tasks.filter {
            $0.isCompleted && ($0.completedAt ?? Date()) >= weekAgo
        }.count
    }

    private var totalCompleted: Int {
        viewModel.tasks.filter { $0.isCompleted }.count
    }

    private var averagePerDay: Double {
        guard totalCompleted > 0 else { return 0 }
        // Simplified calculation
        return Double(totalCompleted) / 7.0
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak Card
                    streakCard

                    // Weekly Stats
                    weeklyStatsCard

                    // Achievements Section
                    achievementsSection
                }
                .padding()
            }
            .navigationTitle("Progress")
            .task {
                await viewModel.loadTasks()
            }
        }
    }

    // MARK: - Streak Card
    private var streakCard: some View {
        VStack(spacing: 16) {
            // Flame Icon
            Image(systemName: "flame.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange.gradient)

            // Streak Count
            VStack(spacing: 4) {
                Text("\(currentStreak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)

                Text("Day Streak")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            // Motivational Message
            Text(streakMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 10, y: 2)
        )
    }

    // MARK: - Weekly Stats Card
    private var weeklyStatsCard: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("This Week")
                .font(.title2.weight(.bold))

            // Stats Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(
                    icon: "checkmark.circle.fill",
                    value: "\(completedThisWeek)",
                    label: "Completed",
                    color: .green
                )

                StatCard(
                    icon: "chart.line.uptrend.xyaxis",
                    value: String(format: "%.1f", averagePerDay),
                    label: "Avg/Day",
                    color: .blue
                )

                StatCard(
                    icon: "star.fill",
                    value: "\(totalCompleted)",
                    label: "Total",
                    color: .yellow
                )

                StatCard(
                    icon: "calendar",
                    value: "\(viewModel.taskLists.count)",
                    label: "Lists",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Achievements Section
    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Achievements")
                .font(.title2.weight(.bold))

            ForEach(achievements, id: \.title) { achievement in
                AchievementRow(achievement: achievement, isUnlocked: achievement.isUnlocked(totalCompleted))
            }
        }
    }

    // MARK: - Computed Values
    private var currentStreak: Int {
        // Simplified: return total completed tasks / 10 as streak days
        max(1, totalCompleted / 5)
    }

    private var streakMessage: String {
        switch currentStreak {
        case 1:
            return "Start your journey today!"
        case 2...7:
            return "Building momentum!"
        case 8...14:
            return "You're on a roll!"
        case 15...30:
            return "Incredible consistency!"
        default:
            return "You're unstoppable!"
        }
    }

    private let achievements: [Achievement] = [
        Achievement(
            title: "Getting Started",
            description: "Complete your first task",
            icon: "star.fill",
            color: .yellow,
            threshold: 1
        ),
        Achievement(
            title: "Productive Week",
            description: "Complete 10 tasks",
            icon: "flame.fill",
            color: .orange,
            threshold: 10
        ),
        Achievement(
            title: "Task Master",
            description: "Complete 50 tasks",
            icon: "crown.fill",
            color: .purple,
            threshold: 50
        ),
        Achievement(
            title: "Legend",
            description: "Complete 100 tasks",
            icon: "trophy.fill",
            color: .yellow,
            threshold: 100
        )
    ]
}

// MARK: - Stat Card
struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color.gradient)

            Text(value)
                .font(.title.weight(.bold))

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Achievement Model
struct Achievement {
    let title: String
    let description: String
    let icon: String
    let color: Color
    let threshold: Int

    func isUnlocked(_ count: Int) -> Bool {
        count >= threshold
    }
}

// MARK: - Achievement Row
struct AchievementRow: View {
    let achievement: Achievement
    let isUnlocked: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: achievement.icon)
                .font(.title2)
                .foregroundStyle(isUnlocked ? achievement.color.gradient : Color.gray.gradient)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isUnlocked ? achievement.color.opacity(0.1) : Color.gray.opacity(0.1))
                )

            // Details
            VStack(alignment: .leading, spacing: 4) {
                Text(achievement.title)
                    .font(.headline)
                    .foregroundStyle(isUnlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Lock/Unlock Indicator
            if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

// MARK: - Preview
#Preview {
    ProgressTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
