//
//  FocusStatisticsView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI

/// Full statistics screen for focus sessions (TickTick-inspired)
struct FocusStatisticsView: View {

    // MARK: - Properties
    @StateObject private var viewModel = FocusStatisticsViewModel()
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Stats Cards Grid
                    statsCardsSection

                    // Focus Record Heatmap
                    heatmapSection

                    // Period Selector & Rankings
                    rankingsSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Focus Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .task {
                await viewModel.loadStatistics()
            }
        }
    }

    // MARK: - Stats Cards Section
    private var statsCardsSection: some View {
        VStack(spacing: 12) {
            // Today's stats row
            HStack(spacing: 12) {
                StatCard(
                    title: "Today's Pomo",
                    value: "\(viewModel.statistics.todaysPomoCount)",
                    change: viewModel.statistics.todaysPomoChange,
                    icon: "timer",
                    color: .orange
                )

                StatCard(
                    title: "Today's Focus",
                    value: viewModel.statistics.todaysFocusFormatted,
                    changeText: viewModel.statistics.todaysFocusChangeFormatted,
                    isPositiveChange: viewModel.statistics.todaysFocusChange >= 0,
                    icon: "clock.fill",
                    color: .blue
                )
            }

            // Total stats row
            HStack(spacing: 12) {
                StatCard(
                    title: "Total Pomo",
                    value: "\(viewModel.statistics.totalPomoCount)",
                    icon: "flame.fill",
                    color: .red
                )

                StatCard(
                    title: "Total Duration",
                    value: viewModel.statistics.totalFocusFormatted,
                    icon: "hourglass",
                    color: .purple
                )
            }
        }
    }

    // MARK: - Heatmap Section
    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Focus Record")
                    .font(.headline)

                Spacer()

                Text("Last 12 weeks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            FocusHeatmapView(data: viewModel.heatmapData)
        }
    }

    // MARK: - Rankings Section
    private var rankingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section header with period selector
            HStack {
                Text("Focus Ranking")
                    .font(.headline)

                Spacer()

                // Period navigation
                HStack(spacing: 8) {
                    Button {
                        viewModel.previousPeriod()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Text(viewModel.periodTitle)
                        .font(.subheadline.weight(.medium))
                        .frame(minWidth: 100)

                    Button {
                        viewModel.nextPeriod()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .opacity(viewModel.canGoNext ? 1 : 0.3)
                    }
                    .disabled(!viewModel.canGoNext)
                }
            }

            // Period tabs
            Picker("Period", selection: $viewModel.selectedPeriod) {
                ForEach(StatisticsPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.selectedPeriod) { _, newPeriod in
                viewModel.selectPeriod(newPeriod)
            }

            // Rankings list
            FocusRankingList(rankings: viewModel.rankings)
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    var change: Int?
    var changeText: String?
    var isPositiveChange: Bool = true
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            // Change indicator
            if let change = change {
                changeIndicator(value: change, isPositive: change >= 0)
            } else if let text = changeText {
                changeIndicator(text: text, isPositive: isPositiveChange)
            } else {
                Text(" ")
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    @ViewBuilder
    private func changeIndicator(value: Int? = nil, text: String? = nil, isPositive: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.bold))

            if let value = value {
                Text("\(isPositive && value > 0 ? "+" : "")\(value) from yesterday")
            } else if let text = text {
                Text("\(text) from yesterday")
            }
        }
        .font(.caption)
        .foregroundStyle(isPositive ? .green : .red)
    }
}

// MARK: - Preview

#Preview {
    FocusStatisticsView()
}
