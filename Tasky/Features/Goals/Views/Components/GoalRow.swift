//
//  GoalRow.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

internal import CoreData
import SwiftUI

/// Row component for displaying a goal in a list
struct GoalRow: View {

    // MARK: - Properties
    let goal: GoalEntity

    // MARK: - Computed Properties
    private var goalColor: Color {
        Color(hex: goal.colorHex ?? "007AFF") ?? .blue
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(goalColor.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: goal.iconName ?? "target")
                    .font(.title3)
                    .foregroundStyle(goalColor)
            }

            // Content
            VStack(alignment: .leading, spacing: Constants.Spacing.xs) {
                HStack {
                    Text(goal.name)
                        .font(.headline)
                        .lineLimit(1)

                    if goal.isNeglected {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack(spacing: Constants.Spacing.sm) {
                    // Task count
                    Text(goal.progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Target date if exists
                    if let targetDate = goal.formattedTargetDate {
                        Text("•")
                            .foregroundStyle(.tertiary)
                        Text(targetDate)
                            .font(.caption)
                            .foregroundStyle(goal.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Progress indicator
            VStack(alignment: .trailing, spacing: Constants.Spacing.xs) {
                Text("\(goal.progressPercentage)%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(goalColor)

                GoalProgressBar(progress: goal.progress, color: goalColor, height: 4)
                    .frame(width: 50)
            }
        }
        .padding(.vertical, Constants.Spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(goal.name), \(goal.progressPercentage) percent complete, \(goal.progressText)")
        .accessibilityHint(goal.isOverdue ? "Overdue" : "")
    }
}

/// Compact goal row for smaller displays
struct CompactGoalRow: View {

    // MARK: - Properties
    let goal: GoalEntity

    // MARK: - Computed Properties
    private var goalColor: Color {
        Color(hex: goal.colorHex ?? "007AFF") ?? .blue
    }

    // MARK: - Body
    var body: some View {
        HStack(spacing: Constants.Spacing.sm) {
            // Icon
            Image(systemName: goal.iconName ?? "target")
                .font(.subheadline)
                .foregroundStyle(goalColor)

            // Name
            Text(goal.name)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // Progress
            Text("\(goal.progressPercentage)%")
                .font(.caption.weight(.medium))
                .foregroundStyle(goalColor)
        }
        .padding(.vertical, Constants.Spacing.xs)
    }
}

// MARK: - Preview
#Preview {
    List {
        GoalRow(goal: PreviewGoalProvider.sampleGoal)
        GoalRow(goal: PreviewGoalProvider.overdueGoal)
        CompactGoalRow(goal: PreviewGoalProvider.sampleGoal)
    }
}

// MARK: - Preview Provider
enum PreviewGoalProvider {
    static var sampleGoal: GoalEntity {
        let context = PersistenceController.preview.viewContext
        let goal = GoalEntity(context: context)
        goal.id = UUID()
        goal.name = "Launch Product"
        goal.status = GoalStatus.active.rawValue
        goal.colorHex = "007AFF"
        goal.iconName = "rocket.fill"
        goal.targetDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        goal.createdAt = Date()
        return goal
    }

    static var overdueGoal: GoalEntity {
        let context = PersistenceController.preview.viewContext
        let goal = GoalEntity(context: context)
        goal.id = UUID()
        goal.name = "Complete Training"
        goal.status = GoalStatus.active.rawValue
        goal.colorHex = "FF3B30"
        goal.iconName = "book.fill"
        goal.targetDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        goal.createdAt = Date()
        return goal
    }
}
