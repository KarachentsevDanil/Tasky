//
//  AchievementDetailModal.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Detailed modal view for achievement information
struct AchievementDetailModal: View {

    // MARK: - Properties
    let achievement: AchievementData
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Large icon
                    iconSection

                    // Achievement info
                    infoSection

                    // Progress section
                    if !achievement.unlocked {
                        progressSection
                    }

                    // Date unlocked (if completed)
                    if achievement.unlocked {
                        completedSection
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("Achievement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Icon Section
    private var iconSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Glow effect for unlocked
                if achievement.unlocked {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.yellow.opacity(0.3), Color.clear],
                                center: .center,
                                startRadius: 40,
                                endRadius: 100
                            )
                        )
                        .frame(width: 200, height: 200)
                }

                // Background circle
                Circle()
                    .fill(achievement.unlocked ? Color.yellow.opacity(0.2) : Color(.systemGray5))
                    .frame(width: 120, height: 120)

                // Icon
                Text(achievement.icon)
                    .font(.system(size: 60))
                    .grayscale(achievement.unlocked ? 0 : 1)
                    .opacity(achievement.unlocked ? 1 : 0.5)

                // Lock overlay
                if !achievement.unlocked {
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .frame(width: 120, height: 120)

                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    // MARK: - Info Section
    private var infoSection: some View {
        VStack(spacing: 12) {
            Text(achievement.name)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            Text(achievement.description)
                .font(.system(size: 17))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Progress Section
    private var progressSection: some View {
        VStack(spacing: 16) {
            Text("Progress")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 16)

                    // Progress
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.gradient)
                        .frame(
                            width: geometry.size.width * CGFloat(achievement.progress) / CGFloat(achievement.required),
                            height: 16
                        )
                }
            }
            .frame(height: 16)

            // Numbers
            HStack {
                Text("\(achievement.progress)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.blue)

                Text("/ \(achievement.required)")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            // Remaining
            Text("\(achievement.required - achievement.progress) more to unlock")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
    }

    // MARK: - Completed Section
    private var completedSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(.green.gradient)

            Text("Achievement Unlocked!")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.green)

            Text("Congratulations on your accomplishment!")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.green.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview {
    AchievementDetailModal(
        achievement: AchievementData(
            id: 1,
            name: "Week Warrior",
            icon: "🔥",
            description: "Complete tasks for 7 days in a row",
            unlocked: false,
            progress: 4,
            required: 7
        )
    )
}

#Preview("Unlocked") {
    AchievementDetailModal(
        achievement: AchievementData(
            id: 2,
            name: "Speed Demon",
            icon: "⚡",
            description: "Complete 10 tasks in a single day",
            unlocked: true,
            progress: 10,
            required: 10
        )
    )
}
