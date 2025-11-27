//
//  WeeklyReviewViewModel.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Combine
import Foundation
import SwiftUI

/// Represents the current step in the weekly review flow
enum ReviewStep: Int, CaseIterable {
    case celebrate = 0
    case incomplete = 1
    case overdue = 2
    case upcoming = 3
    case summary = 4

    var title: String {
        switch self {
        case .celebrate: return "Celebrate"
        case .incomplete: return "Incomplete"
        case .overdue: return "Overdue"
        case .upcoming: return "Upcoming"
        case .summary: return "Summary"
        }
    }

    var iconName: String {
        switch self {
        case .celebrate: return "party.popper"
        case .incomplete: return "clock.badge.questionmark"
        case .overdue: return "exclamationmark.triangle"
        case .upcoming: return "calendar.badge.clock"
        case .summary: return "checkmark.seal"
        }
    }

    var next: ReviewStep? {
        ReviewStep(rawValue: rawValue + 1)
    }

    var previous: ReviewStep? {
        ReviewStep(rawValue: rawValue - 1)
    }
}

/// Action to take on a task during review
enum TaskReviewAction {
    case delete
    case moveToNextWeek
    case rescheduleToTomorrow
    case keep
}

/// Loading state for the review
enum ReviewLoadingState {
    case loading
    case loaded(WeekReviewData)
    case error(Error)

    var data: WeekReviewData? {
        if case .loaded(let data) = self { return data }
        return nil
    }
}

/// ViewModel for the weekly review flow
@MainActor
final class WeeklyReviewViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var currentStep: ReviewStep = .celebrate
    @Published var loadingState: ReviewLoadingState = .loading
    @Published var showConfetti = false

    // Task lists (mutable copies for triage)
    @Published var incompleteTasks: [TaskEntity] = []
    @Published var overdueTasks: [TaskEntity] = []
    @Published var upcomingTasks: [TaskEntity] = []

    // Tracking actions taken
    @Published private(set) var deletedCount = 0
    @Published private(set) var rescheduledCount = 0
    @Published private(set) var keptCount = 0

    // MARK: - Services
    private let reviewService: WeeklyReviewService
    private let dataService: DataService

    // MARK: - Computed Properties
    var weekData: WeekReviewData? { loadingState.data }

    var canGoBack: Bool {
        currentStep.previous != nil
    }

    var canGoForward: Bool {
        currentStep.next != nil
    }

    var progress: Double {
        Double(currentStep.rawValue + 1) / Double(ReviewStep.allCases.count)
    }

    var isLastStep: Bool {
        currentStep == .summary
    }

    var newStreak: Int {
        (weekData?.currentStreak ?? 0) + 1
    }

    // MARK: - Initialization
    init(
        reviewService: WeeklyReviewService = .shared,
        dataService: DataService = DataService()
    ) {
        self.reviewService = reviewService
        self.dataService = dataService
    }

    // MARK: - Data Loading

    func loadReviewData() async {
        loadingState = .loading

        do {
            let data = try await reviewService.getWeekSummary(dataService: dataService)

            // Copy task arrays for mutation during triage
            incompleteTasks = data.incompleteTasks
            overdueTasks = data.overdueTasks
            upcomingTasks = data.upcomingTasks

            loadingState = .loaded(data)

            // Trigger celebration animation
            if data.completedCount > 0 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    showConfetti = true
                }
            }
        } catch {
            print("Failed to load review data: \(error)")
            loadingState = .error(error)
        }
    }

    // MARK: - Navigation

    func goToNextStep() {
        guard let next = currentStep.next else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentStep = next
        }
        HapticManager.shared.lightImpact()
    }

    func goToPreviousStep() {
        guard let previous = currentStep.previous else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentStep = previous
        }
        HapticManager.shared.lightImpact()
    }

    func goToStep(_ step: ReviewStep) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentStep = step
        }
    }

    // MARK: - Task Actions

    /// Handle action on an incomplete task
    func handleIncompleteTask(_ task: TaskEntity, action: TaskReviewAction) {
        switch action {
        case .delete:
            deleteTask(task)
            incompleteTasks.removeAll { $0.id == task.id }
            deletedCount += 1

        case .moveToNextWeek:
            rescheduleToNextWeek(task)
            incompleteTasks.removeAll { $0.id == task.id }
            rescheduledCount += 1

        case .keep:
            incompleteTasks.removeAll { $0.id == task.id }
            keptCount += 1

        case .rescheduleToTomorrow:
            rescheduleToTomorrow(task)
            incompleteTasks.removeAll { $0.id == task.id }
            rescheduledCount += 1
        }

        HapticManager.shared.lightImpact()
    }

    /// Handle action on an overdue task
    func handleOverdueTask(_ task: TaskEntity, action: TaskReviewAction) {
        switch action {
        case .delete:
            deleteTask(task)
            overdueTasks.removeAll { $0.id == task.id }
            deletedCount += 1

        case .rescheduleToTomorrow:
            rescheduleToTomorrow(task)
            overdueTasks.removeAll { $0.id == task.id }
            rescheduledCount += 1

        case .moveToNextWeek:
            rescheduleToNextWeek(task)
            overdueTasks.removeAll { $0.id == task.id }
            rescheduledCount += 1

        case .keep:
            // Move to today
            rescheduleToToday(task)
            overdueTasks.removeAll { $0.id == task.id }
            keptCount += 1
        }

        HapticManager.shared.lightImpact()
    }

    // MARK: - Review Completion

    func completeReview() {
        reviewService.completeReview()
        HapticManager.shared.success()
    }

    // MARK: - Private Helpers

    private func deleteTask(_ task: TaskEntity) {
        do {
            try dataService.deleteTask(task)
        } catch {
            print("Failed to delete task: \(error)")
        }
    }

    private func rescheduleToTomorrow(_ task: TaskEntity) {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        do {
            try dataService.updateTask(task, dueDate: tomorrow)
        } catch {
            print("Failed to reschedule task: \(error)")
        }
    }

    private func rescheduleToNextWeek(_ task: TaskEntity) {
        let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date())!
        do {
            try dataService.updateTask(task, dueDate: nextWeek)
        } catch {
            print("Failed to reschedule task: \(error)")
        }
    }

    private func rescheduleToToday(_ task: TaskEntity) {
        let today = Calendar.current.startOfDay(for: Date())
        do {
            try dataService.updateTask(task, dueDate: today)
        } catch {
            print("Failed to reschedule task: \(error)")
        }
    }

    // MARK: - Skip Functionality

    /// Skip remaining incomplete tasks (mark all as "keep")
    func skipIncomplete() {
        keptCount += incompleteTasks.count
        incompleteTasks.removeAll()
        goToNextStep()
    }

    /// Skip remaining overdue tasks (mark all as "keep")
    func skipOverdue() {
        // Move all overdue to today
        for task in overdueTasks {
            rescheduleToToday(task)
        }
        keptCount += overdueTasks.count
        overdueTasks.removeAll()
        goToNextStep()
    }
}
