//
//  ProgressView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Enhanced progress and stats view with comprehensive analytics
struct ProgressTabView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @StateObject private var progressViewModel: ProgressViewModel
    @State private var animateStats = false
    @State private var showConfetti = false
    @State private var selectedAchievement: AchievementData?
    @State private var showAllAchievements = false

    // MARK: - Initialization
    init(viewModel: TaskListViewModel) {
        self.viewModel = viewModel
        self._progressViewModel = StateObject(wrappedValue: ProgressViewModel(dataService: viewModel.dataService))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Period selector
                    periodSelector
                        .padding(.horizontal)

                    // State-based content rendering
                    switch progressViewModel.statisticsState {
                    case .idle:
                        EmptyView()

                    case .loading:
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading your progress...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 300)

                    case .loaded(let stats):
                        VStack(spacing: 20) {
                            // Hero Streak Card
                            EnhancedStreakCard(
                                currentStreak: stats.currentStreak,
                                recordStreak: stats.recordStreak,
                                message: stats.streakMessage
                            )
                            .padding(.horizontal)

                            // Key Stats Grid
                            statsGrid(stats: stats)
                                .padding(.horizontal)

                            // Weekly Activity Chart
                            WeeklyActivityChart(data: stats.weeklyActivity)
                                .padding(.horizontal)

                            // Activity Heatmap
                            ActivityHeatmap(data: stats.heatmapData)
                                .padding(.horizontal)

                            // Productivity Score
                            ProductivityScoreView(score: stats.productivityScore)
                                .padding(.horizontal)

                            // Insights
                            InsightsCard(insights: stats.insights)
                                .padding(.horizontal)

                            // Personal Best
                            PersonalBestCard(personalBest: stats.personalBest)
                                .padding(.horizontal)

                            // Achievements
                            achievementsSection(achievements: stats.achievements)
                                .padding(.horizontal)
                        }

                    case .error(let error):
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundStyle(.orange)

                            Text("Unable to Load Progress")
                                .font(.headline)

                            Text(error.localizedDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)

                            Button {
                                Task {
                                    await progressViewModel.retryLoadStatistics()
                                }
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .font(.body.weight(.semibold))
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .padding()
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await progressViewModel.loadStatistics()
            }
            .refreshable {
                await progressViewModel.loadStatistics()
            }
            .confetti(isPresented: $showConfetti)
            .sheet(item: $selectedAchievement) { achievement in
                AchievementDetailModal(achievement: achievement)
            }
            .sheet(isPresented: $showAllAchievements) {
                if let stats = progressViewModel.statistics {
                    AllAchievementsView(achievements: stats.achievements)
                }
            }
            .onChange(of: progressViewModel.newlyUnlockedAchievements) { oldValue, newValue in
                if !newValue.isEmpty {
                    // Show confetti for achievement unlock
                    showConfetti = true

                    // Clear after animation
                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                        progressViewModel.clearNewlyUnlockedAchievements()
                        showConfetti = false
                    }
                }
            }
        }
    }

    // MARK: - Period Selector
    private var periodSelector: some View {
        HStack {
            Spacer()

            Picker("Period", selection: $progressViewModel.selectedPeriod) {
                ForEach(ProgressTimePeriod.allCases, id: \.self) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            .onChange(of: progressViewModel.selectedPeriod) { oldValue, newValue in
                HapticManager.shared.selectionChanged()
                Task {
                    await progressViewModel.loadStatistics()
                }
            }
        }
    }

    // MARK: - Stats Grid
    private func statsGrid(stats: ProgressStatistics) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            EnhancedStatCard(
                icon: "✅",
                value: "\(stats.tasksCompleted)",
                label: "Completed",
                trend: stats.tasksCompletedChange,
                color: .green
            )

            EnhancedStatCard(
                icon: "⏱️",
                value: String(format: "%.1fh", stats.focusHours),
                label: "Time Focused",
                trend: Int(stats.focusHoursChange),
                color: .blue
            )

            EnhancedStatCard(
                icon: "🎯",
                value: String(format: "%.0f%%", stats.completionRate),
                label: "Completion Rate",
                trend: Int(stats.completionRateChange),
                color: .orange
            )

            EnhancedStatCard(
                icon: "⚡",
                value: String(format: "%.1f", stats.avgPerDay),
                label: "Avg per Day",
                trend: Int(stats.avgPerDayChange),
                color: .purple
            )
        }
    }

    // MARK: - Achievements Section
    private func achievementsSection(achievements: [AchievementData]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Achievements")
                    .font(.title3.weight(.bold))

                Spacer()

                Button("View All") {
                    showAllAchievements = true
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }

            // Achievement Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement)
                        .onTapGesture {
                            selectedAchievement = achievement
                        }
                }
            }
        }
    }
}

// MARK: - Enhanced Stat Card with Trend
struct EnhancedStatCard: View {
    let icon: String
    let value: String
    let label: String
    let trend: Int
    let color: Color

    @State private var animateValue = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        VStack(spacing: 12) {
            // Icon
            Text(icon)
                .font(.title)

            // Value
            Text(value)
                .font(.title.weight(.bold))
                .opacity(animateValue ? 1 : 0)
                .scaleEffect(animateValue ? 1 : 0.5)
                .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: animateValue)

            // Label
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Trend Indicator
            trendIndicator
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .onAppear {
            animateValue = true
        }
    }

    private var trendIndicator: some View {
        Group {
            if trend > 0 {
                Label("+\(trend)", systemImage: "arrow.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            } else if trend < 0 {
                Label("\(trend)", systemImage: "arrow.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.red)
            } else {
                Text("No change")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Achievement Card
struct AchievementCard: View {
    let achievement: AchievementData

    var body: some View {
        VStack(spacing: 12) {
            // Icon with background
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
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.gray))
                        .offset(x: 20, y: -20)
                }
            }

            // Name
            Text(achievement.name)
                .font(.caption.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(achievement.unlocked ? .primary : .secondary)

            // Progress
            if !achievement.unlocked {
                Text("\(achievement.progress)/\(achievement.required)")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(achievement.unlocked ? Color.yellow.opacity(0.15) : Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            achievement.unlocked ? Color.yellow : Color.clear,
                            lineWidth: 2
                        )
                )
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    ProgressTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
