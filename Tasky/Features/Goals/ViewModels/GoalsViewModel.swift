//
//  GoalsViewModel.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Combine
internal import CoreData
import Foundation
import SwiftUI

/// Loading state for goals
enum GoalsLoadingState {
    case loading
    case loaded([GoalEntity])
    case error(Error)

    var goals: [GoalEntity] {
        if case .loaded(let goals) = self { return goals }
        return []
    }
}

/// ViewModel for managing goals
@MainActor
final class GoalsViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var loadingState: GoalsLoadingState = .loading
    @Published var selectedGoal: GoalEntity?
    @Published var showingAddGoal = false
    @Published var showingEditGoal = false
    @Published var showingArchived = false

    // MARK: - Services
    private let dataService: DataService

    // MARK: - Computed Properties
    var goals: [GoalEntity] { loadingState.goals }

    var activeGoals: [GoalEntity] {
        goals.filter { $0.statusEnum == .active }
    }

    var pausedGoals: [GoalEntity] {
        goals.filter { $0.statusEnum == .paused }
    }

    var neglectedGoals: [GoalEntity] {
        goals.filter { $0.isNeglected }
    }

    var overdueGoals: [GoalEntity] {
        goals.filter { $0.isOverdue }
    }

    var hasGoals: Bool {
        !goals.isEmpty
    }

    // MARK: - Initialization
    init(dataService: DataService = DataService()) {
        self.dataService = dataService
    }

    // MARK: - Data Loading

    func loadGoals() async {
        loadingState = .loading

        do {
            let goals = try dataService.fetchAllGoals(includeArchived: showingArchived)
            loadingState = .loaded(goals)
        } catch {
            print("Failed to load goals: \(error)")
            loadingState = .error(error)
        }
    }

    func loadArchivedGoals() async {
        do {
            let completed = try dataService.fetchGoals(status: .completed)
            let abandoned = try dataService.fetchGoals(status: .abandoned)
            loadingState = .loaded(completed + abandoned)
        } catch {
            print("Failed to load archived goals: \(error)")
            loadingState = .error(error)
        }
    }

    // MARK: - CRUD Operations

    func createGoal(
        name: String,
        notes: String? = nil,
        targetDate: Date? = nil,
        colorHex: String? = nil,
        iconName: String? = nil
    ) async {
        do {
            _ = try dataService.createGoal(
                name: name,
                notes: notes,
                targetDate: targetDate,
                colorHex: colorHex,
                iconName: iconName
            )
            await loadGoals()
            HapticManager.shared.success()
        } catch {
            print("Failed to create goal: \(error)")
            HapticManager.shared.error()
        }
    }

    func updateGoal(
        _ goal: GoalEntity,
        name: String? = nil,
        notes: String? = nil,
        targetDate: Date? = nil,
        colorHex: String? = nil,
        iconName: String? = nil,
        status: GoalStatus? = nil
    ) async {
        do {
            try dataService.updateGoal(
                goal,
                name: name,
                notes: notes,
                targetDate: targetDate,
                colorHex: colorHex,
                iconName: iconName,
                status: status
            )
            await loadGoals()
            HapticManager.shared.lightImpact()
        } catch {
            print("Failed to update goal: \(error)")
            HapticManager.shared.error()
        }
    }

    func deleteGoal(_ goal: GoalEntity) async {
        do {
            try dataService.deleteGoal(goal)
            await loadGoals()
            HapticManager.shared.success()
        } catch {
            print("Failed to delete goal: \(error)")
            HapticManager.shared.error()
        }
    }

    // MARK: - Status Changes

    func completeGoal(_ goal: GoalEntity) async {
        do {
            try dataService.completeGoal(goal)
            await loadGoals()
            HapticManager.shared.success()
        } catch {
            print("Failed to complete goal: \(error)")
            HapticManager.shared.error()
        }
    }

    func abandonGoal(_ goal: GoalEntity) async {
        do {
            try dataService.abandonGoal(goal)
            await loadGoals()
            HapticManager.shared.lightImpact()
        } catch {
            print("Failed to abandon goal: \(error)")
            HapticManager.shared.error()
        }
    }

    func pauseGoal(_ goal: GoalEntity) async {
        await updateGoal(goal, status: .paused)
    }

    func resumeGoal(_ goal: GoalEntity) async {
        await updateGoal(goal, status: .active)
    }

    // MARK: - Task Linking

    func linkTask(_ task: TaskEntity, to goal: GoalEntity) async {
        do {
            try dataService.linkTaskToGoal(task: task, goal: goal)
            await loadGoals()
            HapticManager.shared.lightImpact()
        } catch {
            print("Failed to link task to goal: \(error)")
        }
    }

    func unlinkTask(_ task: TaskEntity, from goal: GoalEntity) async {
        do {
            try dataService.unlinkTaskFromGoal(task: task, goal: goal)
            await loadGoals()
            HapticManager.shared.lightImpact()
        } catch {
            print("Failed to unlink task from goal: \(error)")
        }
    }

    // MARK: - Reordering

    func moveGoals(from source: IndexSet, to destination: Int) async {
        var reorderedGoals = goals
        reorderedGoals.move(fromOffsets: source, toOffset: destination)

        do {
            try dataService.reorderGoals(reorderedGoals)
            loadingState = .loaded(reorderedGoals)
        } catch {
            print("Failed to reorder goals: \(error)")
        }
    }

    // MARK: - Selection

    func selectGoal(_ goal: GoalEntity) {
        selectedGoal = goal
    }

    func clearSelection() {
        selectedGoal = nil
    }

    // MARK: - Task Fetching

    /// Fetch tasks not linked to the specified goal
    func fetchUnlinkedTasks(excludingGoal goal: GoalEntity) async -> [TaskEntity] {
        do {
            let allTasks = try dataService.fetchAllTasks()
            let linkedTaskIds = Set(goal.linkedTasks.map { $0.id })
            return allTasks.filter { !linkedTaskIds.contains($0.id) && !$0.isCompleted }
        } catch {
            print("Failed to fetch tasks: \(error)")
            return []
        }
    }
}
