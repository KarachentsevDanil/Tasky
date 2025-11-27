//
//  MorningBriefViewModel.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 27.11.2025.
//

import Combine
import Foundation
import SwiftUI

/// ViewModel for the Morning Brief view
@MainActor
class MorningBriefViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var briefData: MorningBriefData?
    @Published var isLoading = false
    @Published var isDismissing = false

    // MARK: - Properties
    private let briefService: MorningBriefService
    private let onDismiss: () -> Void

    // MARK: - Computed Properties
    var greeting: String {
        briefData?.greeting ?? "Good morning!"
    }

    var subtitle: String {
        "Here's your day at a glance"
    }

    var totalTasksText: String {
        guard let data = briefData else { return "Loading..." }

        if data.isEmpty {
            return "No tasks scheduled for today"
        }

        let taskWord = data.totalTasksToday == 1 ? "task" : "tasks"
        return "\(data.totalTasksToday) \(taskWord) today"
    }

    var hasOverdue: Bool {
        briefData?.hasOverdueTasks ?? false
    }

    var overdueText: String {
        guard let count = briefData?.overdueCount, count > 0 else { return "" }
        let taskWord = count == 1 ? "task" : "tasks"
        return "\(count) overdue \(taskWord)"
    }

    var focusTasks: [BriefTask] {
        briefData?.focusTasks ?? []
    }

    var scheduleBlocks: [ScheduleBlock] {
        briefData?.scheduleOverview ?? []
    }

    var hasSchedule: Bool {
        !scheduleBlocks.isEmpty
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Initialization
    init(briefService: MorningBriefService = .shared, onDismiss: @escaping () -> Void) {
        self.briefService = briefService
        self.onDismiss = onDismiss
    }

    // MARK: - Actions

    /// Load the brief data
    func loadBrief() async {
        isLoading = true
        await briefService.generateBriefData()
        briefData = briefService.briefData
        isLoading = false
    }

    /// Start the day - mark brief as reviewed and dismiss
    func startMyDay() {
        HapticManager.shared.success()
        briefService.markBriefAsReviewed()
        dismissWithAnimation()
    }

    /// Skip the brief for today
    func skipBrief() {
        HapticManager.shared.lightImpact()
        briefService.skipBriefForToday()
        dismissWithAnimation()
    }

    /// Dismiss with animation
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isDismissing = true
        }

        // Delay actual dismiss to allow animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.onDismiss()
        }
    }

    // MARK: - Priority Helpers

    func priorityColor(for task: BriefTask) -> Color {
        switch task.priority {
        case 3: return .red
        case 2: return .orange
        case 1: return .blue
        default: return .gray
        }
    }

    func priorityLabel(for task: BriefTask) -> String {
        switch task.priority {
        case 3: return "High"
        case 2: return "Medium"
        case 1: return "Low"
        default: return ""
        }
    }

    func formattedTime(for task: BriefTask) -> String? {
        guard let time = task.scheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
}
