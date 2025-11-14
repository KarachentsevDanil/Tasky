//
//  ProgressView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

// MARK: - Progress Tab Selection
enum ProgressTab: String, CaseIterable {
    case overview = "Overview"
    case patterns = "Patterns"
    case achievements = "Achievements"
}

/// Enhanced progress and stats view with tabbed interface
struct ProgressTabView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: TaskListViewModel
    @StateObject private var progressViewModel: ProgressViewModel
    @State private var selectedTab: ProgressTab = .overview
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
            VStack(spacing: 0) {
                // Tab Picker
                tabPicker

                // Content
                ScrollView {
                    switch progressViewModel.statisticsState {
                    case .idle:
                        EmptyView()

                    case .loading:
                        loadingView

                    case .loaded(let stats):
                        loadedContent(stats: stats)

                    case .error(let error):
                        errorView(error: error)
                    }
                }
                .refreshable {
                    await progressViewModel.loadStatistics()
                }
            }
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
            .task {
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
                    showConfetti = true
                    HapticManager.shared.success()

                    Task {
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        progressViewModel.clearNewlyUnlockedAchievements()
                        showConfetti = false
                    }
                }
            }
        }
    }

    // MARK: - Tab Picker
    private var tabPicker: some View {
        Picker("Tab", selection: $selectedTab) {
            ForEach(ProgressTab.allCases, id: \.self) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .onChange(of: selectedTab) { oldValue, newValue in
            HapticManager.shared.selectionChanged()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your progress...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    // MARK: - Error View
    private func errorView(error: Error) -> some View {
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
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    // MARK: - Loaded Content
    @ViewBuilder
    private func loadedContent(stats: ProgressStatistics) -> some View {
        switch selectedTab {
        case .overview:
            OverviewTab(
                stats: stats,
                onInsightTap: handleInsightTap,
                onStartFocusSession: handleStartFocusSession
            )
            .padding(.vertical)

        case .patterns:
            PatternsTab(
                stats: stats,
                selectedPeriod: $progressViewModel.selectedPeriod
            )
            .padding(.vertical)

        case .achievements:
            AchievementsTab(
                achievements: stats.achievements,
                onAchievementTap: { achievement in
                    selectedAchievement = achievement
                },
                onViewAll: {
                    showAllAchievements = true
                }
            )
            .padding(.vertical)
        }
    }

    // MARK: - Actions
    private func handleInsightTap(_ insight: String) {
        // TODO: Navigate to relevant view based on insight
        // For now, just haptic feedback
        HapticManager.shared.lightImpact()
    }

    private func handleStartFocusSession() {
        // TODO: Navigate to Focus Session start screen
        // For now, just haptic feedback
        HapticManager.shared.lightImpact()
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

// MARK: - Overview Tab
struct OverviewTab: View {
    let stats: ProgressStatistics
    let onInsightTap: (String) -> Void
    let onStartFocusSession: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Hero: Productivity Score
            ProductivityScoreView(score: stats.productivityScore)
                .padding(.horizontal)

            // Compact Cards Row: Streak + Weekly Goal
            HStack(spacing: 16) {
                CompactStreakCard(currentStreak: stats.currentStreak)

                WeeklyGoalCard(
                    completed: stats.tasksCompleted,
                    goal: 25 // TODO: Make this configurable
                )
            }
            .padding(.horizontal)

            // Actionable Insights
            if !stats.insights.isEmpty {
                ActionableInsightsSection(
                    insights: stats.insights,
                    onInsightTap: onInsightTap
                )
                .padding(.horizontal)
            }

            // Focus Sessions Onboarding (if no focus time)
            if stats.focusHours == 0 {
                FocusSessionOnboardingCard(onStartSession: onStartFocusSession)
                    .padding(.horizontal)
            }

            // Quick Stats Grid
            VStack(alignment: .leading, spacing: 16) {
                Text("Quick Stats")
                    .font(.title3.weight(.bold))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    EnhancedStatCard(
                        icon: "✅",
                        value: "\(stats.tasksCompleted)",
                        label: "Completed",
                        trend: stats.tasksCompletedChange,
                        color: .green
                    )

                    EnhancedStatCard(
                        icon: "🎯",
                        value: String(format: "%.0f%%", stats.completionRate),
                        label: "Rate",
                        trend: Int(stats.completionRateChange),
                        color: .orange
                    )

                    EnhancedStatCard(
                        icon: "⚡",
                        value: String(format: "%.1f", stats.avgPerDay),
                        label: "Avg/Day",
                        trend: Int(stats.avgPerDayChange),
                        color: .purple
                    )

                    if stats.focusHours > 0 {
                        EnhancedStatCard(
                            icon: "⏱️",
                            value: String(format: "%.1fh", stats.focusHours),
                            label: "Focus",
                            trend: Int(stats.focusHoursChange),
                            color: .blue
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Patterns Tab
struct PatternsTab: View {
    let stats: ProgressStatistics
    @Binding var selectedPeriod: ProgressTimePeriod

    var body: some View {
        VStack(spacing: 24) {
            // Period Selector
            HStack {
                Spacer()

                Picker("Period", selection: $selectedPeriod) {
                    ForEach(ProgressTimePeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }
            .padding(.horizontal)

            // Top Stats Row
            HStack(spacing: 16) {
                // Completion Rate
                VStack(spacing: 8) {
                    Text("🎯")
                        .font(.title)

                    Text("\(Int(stats.completionRate))%")
                        .font(.title.weight(.bold))

                    Text("Completion Rate")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if stats.completionRateChange != 0 {
                        Label(
                            String(format: "%+.0f", stats.completionRateChange),
                            systemImage: stats.completionRateChange > 0 ? "arrow.up" : "arrow.down"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stats.completionRateChange > 0 ? .green : .red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )

                // Avg per Day
                VStack(spacing: 8) {
                    Text("⚡")
                        .font(.title)

                    Text(String(format: "%.1f", stats.avgPerDay))
                        .font(.title.weight(.bold))

                    Text("Avg per Day")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if stats.avgPerDayChange != 0 {
                        Label(
                            String(format: "%+.0f", stats.avgPerDayChange),
                            systemImage: stats.avgPerDayChange > 0 ? "arrow.up" : "arrow.down"
                        )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(stats.avgPerDayChange > 0 ? .green : .red)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
                )
            }
            .padding(.horizontal)

            // Weekly Activity Chart
            WeeklyActivityChart(data: stats.weeklyActivity)
                .padding(.horizontal)

            // Activity Heatmap
            ActivityHeatmap(data: stats.heatmapData)
                .padding(.horizontal)

            // Personal Best
            if let personalBest = stats.personalBest {
                PersonalBestCard(personalBest: personalBest)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Achievements Tab
struct AchievementsTab: View {
    let achievements: [AchievementData]
    let onAchievementTap: (AchievementData) -> Void
    let onViewAll: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            // Stats Summary
            VStack(spacing: 12) {
                let unlockedCount = achievements.filter { $0.unlocked }.count
                let totalCount = achievements.count

                Text("\(unlockedCount)/\(totalCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("Achievements Unlocked")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Progress Bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.systemGray5))
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: geometry.size.width * (Double(unlockedCount) / Double(totalCount)),
                                height: 8
                            )
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)
            }
            .padding(.vertical, 20)
            .padding(.horizontal)

            // Achievement Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                ForEach(achievements) { achievement in
                    AchievementCard(achievement: achievement)
                        .onTapGesture {
                            onAchievementTap(achievement)
                        }
                }
            }
            .padding(.horizontal)

            // View All Button
            Button(action: onViewAll) {
                Text("View All Achievements")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.bottom)
        }
    }
}

// MARK: - Preview
#Preview {
    ProgressTabView(viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview)))
}
