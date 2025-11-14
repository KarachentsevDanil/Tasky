//
//  AllAchievementsView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Full achievements view showing all achievements with categories
struct AllAchievementsView: View {

    // MARK: - Properties
    let achievements: [AchievementData]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAchievement: AchievementData?

    // MARK: - Computed Properties
    private var unlockedCount: Int {
        achievements.filter { $0.unlocked }.count
    }

    private var totalCount: Int {
        achievements.count
    }

    private var completionPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(unlockedCount) / Double(totalCount) * 100
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall progress card
                    overallProgressCard

                    // Achievements list
                    achievementsList
                }
                .padding()
            }
            .navigationTitle("Achievements")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailModal(achievement: achievement)
            }
        }
    }

    // MARK: - Overall Progress Card
    private var overallProgressCard: some View {
        VStack(spacing: 16) {
            // Trophy icon
            Text("🏆")
                .font(.system(size: 60))

            // Stats
            VStack(spacing: 8) {
                Text("\(unlockedCount) / \(totalCount)")
                    .font(.system(size: 34, weight: .bold))

                Text("Achievements Unlocked")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            width: geometry.size.width * completionPercentage / 100,
                            height: 12
                        )
                }
            }
            .frame(height: 12)

            Text(String(format: "%.0f%% Complete", completionPercentage))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.yellow.opacity(0.3), lineWidth: 2)
                )
        )
    }

    // MARK: - Achievements List
    private var achievementsList: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section: Unlocked
            if !unlockedAchievements.isEmpty {
                sectionHeader(title: "Unlocked", count: unlockedAchievements.count)

                ForEach(unlockedAchievements) { achievement in
                    AchievementRow(achievement: achievement)
                        .onTapGesture {
                            selectedAchievement = achievement
                        }
                }
            }

            // Section: In Progress
            if !inProgressAchievements.isEmpty {
                sectionHeader(title: "In Progress", count: inProgressAchievements.count)

                ForEach(inProgressAchievements) { achievement in
                    AchievementRow(achievement: achievement)
                        .onTapGesture {
                            selectedAchievement = achievement
                        }
                }
            }

            // Section: Locked
            if !lockedAchievements.isEmpty {
                sectionHeader(title: "Locked", count: lockedAchievements.count)

                ForEach(lockedAchievements) { achievement in
                    AchievementRow(achievement: achievement)
                        .onTapGesture {
                            selectedAchievement = achievement
                        }
                }
            }
        }
    }

    // MARK: - Section Header
    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 20, weight: .bold))

            Text("\(count)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                )

            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Filtered Achievements
    private var unlockedAchievements: [AchievementData] {
        achievements.filter { $0.unlocked }
    }

    private var inProgressAchievements: [AchievementData] {
        achievements.filter { !$0.unlocked && $0.progress > 0 }
    }

    private var lockedAchievements: [AchievementData] {
        achievements.filter { !$0.unlocked && $0.progress == 0 }
    }
}

// MARK: - Achievement Row Component
struct AchievementRow: View {
    let achievement: AchievementData

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(achievement.unlocked ? Color.yellow.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 60, height: 60)

                Text(achievement.icon)
                    .font(.system(size: 30))
                    .grayscale(achievement.unlocked ? 0 : 1)
                    .opacity(achievement.unlocked ? 1 : 0.5)

                if !achievement.unlocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.gray))
                        .offset(x: 20, y: -20)
                }
            }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text(achievement.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(achievement.unlocked ? .primary : .secondary)

                Text(achievement.description)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                // Progress bar for locked achievements
                if !achievement.unlocked && achievement.progress > 0 {
                    progressBar
                }
            }

            Spacer()

            // Status indicator
            if achievement.unlocked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(achievement.unlocked ? Color.yellow.opacity(0.1) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            achievement.unlocked ? Color.yellow.opacity(0.5) : Color(.systemGray5),
                            lineWidth: achievement.unlocked ? 2 : 1
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.gradient)
                    .frame(
                        width: geometry.size.width * CGFloat(achievement.progress) / CGFloat(achievement.required),
                        height: 6
                    )
            }
        }
        .frame(height: 6)
        .overlay(
            HStack {
                Spacer()
                Text("\(achievement.progress)/\(achievement.required)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            },
            alignment: .trailing
        )
        .padding(.top, 2)
    }
}

// MARK: - Preview
#Preview {
    AllAchievementsView(
        achievements: [
            AchievementData(id: 1, name: "Week Warrior", icon: "🔥", description: "7 day streak", unlocked: true, progress: 7, required: 7),
            AchievementData(id: 2, name: "Speed Demon", icon: "⚡", description: "10 tasks in 1 day", unlocked: true, progress: 10, required: 10),
            AchievementData(id: 3, name: "Perfectionist", icon: "🎯", description: "100% completion", unlocked: false, progress: 85, required: 100),
            AchievementData(id: 4, name: "Diamond", icon: "💎", description: "30 day streak", unlocked: false, progress: 18, required: 30),
            AchievementData(id: 5, name: "Champion", icon: "🏆", description: "100 tasks", unlocked: false, progress: 45, required: 100),
            AchievementData(id: 6, name: "All-Star", icon: "🌟", description: "30 focus hours", unlocked: false, progress: 0, required: 30)
        ]
    )
}
