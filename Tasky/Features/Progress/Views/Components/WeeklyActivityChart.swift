//
//  WeeklyActivityChart.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Weekly activity bar chart showing completed vs total tasks
struct WeeklyActivityChart: View {

    // MARK: - Properties
    let data: [DayActivity]
    @State private var animateChart = false
    @State private var selectedDay: DayActivity?
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Constants
    private let chartHeight: CGFloat = 150
    private let barSpacing: CGFloat = 12

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Weekly Activity")
                    .font(.body.weight(.bold))

                Spacer()

                // Legend
                HStack(spacing: 16) {
                    legendItem(color: .green, label: "Completed")
                    legendItem(color: Color(.systemGray4), label: "Total")
                }
                .font(.caption)
            }

            // Chart
            ZStack(alignment: .top) {
                HStack(alignment: .bottom, spacing: barSpacing) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, day in
                        dayBars(for: day, index: index)
                    }
                }
                .frame(height: chartHeight)
                .onAppear {
                    withAnimation(reduceMotion ? .none : .spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                        animateChart = true
                    }
                }

                // Tooltip
                if let selectedDay = selectedDay {
                    tooltip(for: selectedDay)
                        .offset(y: -20)
                        .transition(.opacity.combined(with: .scale))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Day Bars
    @ViewBuilder
    private func dayBars(for day: DayActivity, index: Int) -> some View {
        VStack(spacing: 8) {
            // Bars
            ZStack(alignment: .bottom) {
                // Total bar (gray)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray4))
                    .frame(width: 16, height: barHeight(for: day.total))
                    .scaleEffect(y: animateChart ? 1 : 0, anchor: .bottom)
                    .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05), value: animateChart)

                // Completed bar (green)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.green.gradient)
                    .frame(width: 16, height: barHeight(for: day.completed))
                    .scaleEffect(y: animateChart ? 1 : 0, anchor: .bottom)
                    .animation(reduceMotion ? .none : .spring(response: 0.6, dampingFraction: 0.7).delay(Double(index) * 0.05 + 0.1), value: animateChart)
            }
            .onTapGesture {
                withAnimation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.7)) {
                    if selectedDay?.id == day.id {
                        selectedDay = nil
                    } else {
                        selectedDay = day
                        HapticManager.shared.lightImpact()
                    }
                }
            }

            // Day label
            Text(day.label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(selectedDay?.id == day.id ? .primary : .secondary)
                .fontWeight(selectedDay?.id == day.id ? .bold : .medium)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Legend Item
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Text(label)
        }
    }

    // MARK: - Tooltip
    private func tooltip(for day: DayActivity) -> some View {
        VStack(spacing: 4) {
            Text(day.label)
                .font(.caption.weight(.bold))

            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("\(day.completed)")
                        .font(.caption2)
                }

                Text("/")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 6, height: 6)
                    Text("\(day.total)")
                        .font(.caption2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
        )
    }

    // MARK: - Helpers
    private func barHeight(for value: Int) -> CGFloat {
        let maxValue = data.map { max($0.total, $0.completed) }.max() ?? 1
        let normalizedHeight = CGFloat(value) / CGFloat(maxValue)
        return max(8, normalizedHeight * chartHeight)
    }
}

// MARK: - Preview
#Preview {
    WeeklyActivityChart(
        data: [
            DayActivity(label: "Mon", total: 6, completed: 5),
            DayActivity(label: "Tue", total: 8, completed: 7),
            DayActivity(label: "Wed", total: 7, completed: 6),
            DayActivity(label: "Thu", total: 9, completed: 8),
            DayActivity(label: "Fri", total: 6, completed: 5),
            DayActivity(label: "Sat", total: 4, completed: 4),
            DayActivity(label: "Sun", total: 5, completed: 3)
        ]
    )
    .padding()
}
