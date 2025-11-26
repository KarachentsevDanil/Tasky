//
//  FocusHeatmapView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI

/// GitHub-style contribution heatmap for focus sessions
struct FocusHeatmapView: View {

    // MARK: - Properties
    let data: [DayFocusData]
    @State private var selectedDay: DayFocusData?

    private let cellSize: CGFloat = 12
    private let cellSpacing: CGFloat = 3
    private let weeksToShow = 12

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month labels
            monthLabels

            // Heatmap grid
            HStack(alignment: .top, spacing: cellSpacing) {
                // Day labels
                dayLabels

                // Grid
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: cellSpacing) {
                        ForEach(groupedByWeek(), id: \.first?.date) { week in
                            VStack(spacing: cellSpacing) {
                                ForEach(week) { day in
                                    HeatmapCell(
                                        data: day,
                                        size: cellSize,
                                        isSelected: selectedDay?.date == day.date
                                    )
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.2)) {
                                            if selectedDay?.date == day.date {
                                                selectedDay = nil
                                            } else {
                                                selectedDay = day
                                                HapticManager.shared.selectionChanged()
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.trailing, 8)
                }
            }

            // Legend
            legendView

            // Selected day detail
            if let day = selectedDay {
                selectedDayDetail(day)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Month Labels
    private var monthLabels: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 24) // Spacer for day labels

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(getMonthLabels(), id: \.offset) { label in
                        Text(label.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: CGFloat(label.weeks) * (cellSize + cellSpacing), alignment: .leading)
                    }
                }
            }
        }
    }

    // MARK: - Day Labels
    private var dayLabels: some View {
        VStack(spacing: cellSpacing) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20, height: cellSize)
            }
        }
    }

    // MARK: - Legend
    private var legendView: some View {
        HStack(spacing: 8) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { intensity in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForIntensity(intensity))
                        .frame(width: cellSize, height: cellSize)
                }
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Selected Day Detail
    private func selectedDayDetail(_ day: DayFocusData) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(formatDate(day.date))
                    .font(.subheadline.weight(.semibold))

                Text("\(day.sessionCount) sessions - \(day.formattedDuration)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                selectedDay = nil
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.tertiarySystemGroupedBackground))
        )
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Helpers

    private func groupedByWeek() -> [[DayFocusData]] {
        guard !data.isEmpty else { return [] }

        let calendar = Calendar.current
        var weeks: [[DayFocusData]] = []
        var currentWeek: [DayFocusData] = []
        var lastWeekOfYear: Int?

        for day in data.sorted(by: { $0.date < $1.date }) {
            let weekOfYear = calendar.component(.weekOfYear, from: day.date)

            if let last = lastWeekOfYear, weekOfYear != last {
                if !currentWeek.isEmpty {
                    // Pad incomplete weeks
                    while currentWeek.count < 7 {
                        currentWeek.insert(DayFocusData(date: Date.distantPast, totalSeconds: 0, sessionCount: 0), at: 0)
                    }
                    weeks.append(currentWeek)
                }
                currentWeek = []
            }

            currentWeek.append(day)
            lastWeekOfYear = weekOfYear
        }

        // Add last week
        if !currentWeek.isEmpty {
            weeks.append(currentWeek)
        }

        return weeks
    }

    private func getMonthLabels() -> [(name: String, weeks: Int, offset: Int)] {
        guard !data.isEmpty else { return [] }

        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"

        var labels: [(name: String, weeks: Int, offset: Int)] = []
        var currentMonth: Int?
        var weeksInMonth = 0
        var offset = 0

        for day in data.sorted(by: { $0.date < $1.date }) {
            let month = calendar.component(.month, from: day.date)
            let weekday = calendar.component(.weekday, from: day.date)

            if weekday == 1 { // Sunday = new week
                if let current = currentMonth, current != month {
                    labels.append((name: formatter.string(from: day.date), weeks: weeksInMonth, offset: offset))
                    offset += weeksInMonth
                    weeksInMonth = 0
                }
                weeksInMonth += 1
                currentMonth = month
            }
        }

        return labels
    }

    private func colorForIntensity(_ intensity: Double) -> Color {
        if intensity == 0 {
            return Color(.systemGray5)
        }
        return Color.orange.opacity(0.3 + (intensity * 0.7))
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Heatmap Cell

private struct HeatmapCell: View {
    let data: DayFocusData
    let size: CGFloat
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(cellColor)
            .frame(width: size, height: size)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
            )
            .opacity(data.date == Date.distantPast ? 0 : 1)
    }

    private var cellColor: Color {
        if data.totalSeconds == 0 {
            return Color(.systemGray5)
        }
        return Color.orange.opacity(0.3 + (data.intensity * 0.7))
    }
}

// MARK: - Preview

#Preview {
    let calendar = Calendar.current
    let today = Date()

    // Generate sample data
    var sampleData: [DayFocusData] = []
    for i in 0..<84 {
        let date = calendar.date(byAdding: .day, value: -i, to: today)!
        let hasActivity = Int.random(in: 0...10) > 3
        sampleData.append(DayFocusData(
            date: date,
            totalSeconds: hasActivity ? Int.random(in: 0...14400) : 0,
            sessionCount: hasActivity ? Int.random(in: 0...8) : 0
        ))
    }

    return FocusHeatmapView(data: sampleData)
        .padding()
}
