//
//  FocusStatisticsViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import Foundation
import Combine

/// ViewModel for focus statistics screen
@MainActor
class FocusStatisticsViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var statistics = FocusStatistics()
    @Published var heatmapData: [DayFocusData] = []
    @Published var rankings: [TaskFocusRanking] = []
    @Published var selectedPeriod: StatisticsPeriod = .week
    @Published var isLoading = false
    @Published var selectedDate = Date()

    // MARK: - Properties
    private let dataService: DataService

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    // MARK: - Data Loading

    /// Load all statistics data
    func loadStatistics() async {
        isLoading = true

        // Load overall statistics
        if let stats = try? dataService.calculateFocusStatistics() {
            statistics = stats
        }

        // Load heatmap data (last 12 weeks)
        await loadHeatmapData()

        // Load rankings for selected period
        await loadRankings()

        isLoading = false
    }

    /// Load heatmap data for the last 12 weeks
    func loadHeatmapData() async {
        let calendar = Calendar.current

        // Start from 12 weeks ago, aligned to week start (Sunday)
        let today = Date()
        let weeksAgo = calendar.date(byAdding: .weekOfYear, value: -12, to: today)!
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weeksAgo))!
        let endDate = calendar.date(byAdding: .day, value: 1, to: today)!

        if let data = try? dataService.fetchFocusSessionsByDay(from: startOfWeek, to: endDate) {
            heatmapData = data
        }
    }

    /// Load rankings for selected period
    func loadRankings() async {
        let (startDate, endDate) = dateRangeForPeriod(selectedPeriod, referenceDate: selectedDate)

        if let data = try? dataService.fetchFocusRankings(from: startDate, to: endDate) {
            rankings = data
        }
    }

    /// Update selected period and reload rankings
    func selectPeriod(_ period: StatisticsPeriod) {
        selectedPeriod = period
        Task {
            await loadRankings()
        }
    }

    /// Navigate to previous period
    func previousPeriod() {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: -1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
        }
        Task {
            await loadRankings()
        }
    }

    /// Navigate to next period
    func nextPeriod() {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .day:
            selectedDate = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        case .week:
            selectedDate = calendar.date(byAdding: .weekOfYear, value: 1, to: selectedDate) ?? selectedDate
        case .month:
            selectedDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
        }
        Task {
            await loadRankings()
        }
    }

    // MARK: - Computed Properties

    var periodTitle: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current

        switch selectedPeriod {
        case .day:
            if calendar.isDateInToday(selectedDate) {
                return "Today"
            } else if calendar.isDateInYesterday(selectedDate) {
                return "Yesterday"
            }
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: selectedDate)

        case .week:
            let (start, end) = dateRangeForPeriod(.week, referenceDate: selectedDate)
            formatter.dateFormat = "MMM d"
            let startStr = formatter.string(from: start)
            let endStr = formatter.string(from: calendar.date(byAdding: .day, value: -1, to: end) ?? end)
            return "\(startStr) - \(endStr)"

        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    var canGoNext: Bool {
        let calendar = Calendar.current
        switch selectedPeriod {
        case .day:
            return !calendar.isDateInToday(selectedDate)
        case .week:
            let (_, endDate) = dateRangeForPeriod(.week, referenceDate: selectedDate)
            return endDate <= Date()
        case .month:
            let (_, endDate) = dateRangeForPeriod(.month, referenceDate: selectedDate)
            return endDate <= Date()
        }
    }

    // MARK: - Helpers

    private func dateRangeForPeriod(_ period: StatisticsPeriod, referenceDate: Date) -> (Date, Date) {
        let calendar = Calendar.current

        switch period {
        case .day:
            let startOfDay = calendar.startOfDay(for: referenceDate)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)

        case .week:
            let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: referenceDate))!
            let endOfWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: startOfWeek)!
            return (startOfWeek, endOfWeek)

        case .month:
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: referenceDate))!
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
            return (startOfMonth, endOfMonth)
        }
    }
}
