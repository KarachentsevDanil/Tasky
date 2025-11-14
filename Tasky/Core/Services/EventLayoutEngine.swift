//
//  EventLayoutEngine.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import Foundation
import CoreGraphics

/// Layout information for rendering a task in the calendar
struct TaskLayout {
    let task: TaskEntity
    var frame: CGRect
    var column: Int
    var totalColumns: Int

    var relativeX: CGFloat {
        CGFloat(column) / CGFloat(totalColumns)
    }

    var relativeWidth: CGFloat {
        1.0 / CGFloat(totalColumns)
    }
}

/// Engine for calculating optimal layout of overlapping tasks
@MainActor
final class EventLayoutEngine {

    struct LayoutConfig {
        let containerWidth: CGFloat
        let hourHeight: CGFloat
        let startHour: Int
        let eventPadding: CGFloat = 2
    }

    /// Calculate layouts for all tasks, handling overlaps intelligently
    func layoutTasks(_ tasks: [TaskEntity], config: LayoutConfig) -> [TaskLayout] {
        guard !tasks.isEmpty else { return [] }

        // Filter tasks with scheduledTime and sort by start time, then by duration (longer first)
        let scheduledTasks = tasks.compactMap { task -> (task: TaskEntity, start: Date, end: Date)? in
            guard let startTime = task.scheduledTime else { return nil }
            let endTime = task.scheduledEndTime ?? Calendar.current.date(byAdding: .hour, value: 1, to: startTime)!
            return (task, startTime, endTime)
        }
        .sorted { first, second in
            if first.start == second.start {
                return first.end.timeIntervalSince(first.start) > second.end.timeIntervalSince(second.start)
            }
            return first.start < second.start
        }

        // Find overlapping groups
        let groups = findOverlappingGroups(scheduledTasks)

        // Layout each group
        var layouts: [TaskLayout] = []
        for group in groups {
            layouts.append(contentsOf: layoutGroup(group, config: config))
        }

        return layouts
    }

    private func findOverlappingGroups(_ tasks: [(task: TaskEntity, start: Date, end: Date)]) -> [[(task: TaskEntity, start: Date, end: Date)]] {
        var groups: [[(task: TaskEntity, start: Date, end: Date)]] = []
        var currentGroup: [(task: TaskEntity, start: Date, end: Date)] = []

        for taskInfo in tasks {
            if currentGroup.isEmpty {
                currentGroup.append(taskInfo)
            } else {
                // Check if task overlaps with any task in current group
                let overlapsWithGroup = currentGroup.contains { existing in
                    taskInfo.start < existing.end && taskInfo.end > existing.start
                }

                if overlapsWithGroup {
                    currentGroup.append(taskInfo)
                } else {
                    // Start new group
                    groups.append(currentGroup)
                    currentGroup = [taskInfo]
                }
            }
        }

        if !currentGroup.isEmpty {
            groups.append(currentGroup)
        }

        return groups
    }

    private func layoutGroup(_ group: [(task: TaskEntity, start: Date, end: Date)], config: LayoutConfig) -> [TaskLayout] {
        var layouts: [TaskLayout] = []
        var columns: [[(task: TaskEntity, start: Date, end: Date)]] = []

        for taskInfo in group {
            var placed = false

            // Try to place in existing column
            for (index, var column) in columns.enumerated() {
                let canPlace = !column.contains { existing in
                    taskInfo.start < existing.end && taskInfo.end > existing.start
                }
                if canPlace {
                    column.append(taskInfo)
                    columns[index] = column
                    placed = true
                    break
                }
            }

            // Create new column if needed
            if !placed {
                columns.append([taskInfo])
            }
        }

        let totalColumns = columns.count

        // Create layouts
        for (columnIndex, column) in columns.enumerated() {
            for taskInfo in column {
                let frame = calculateFrame(
                    startTime: taskInfo.start,
                    endTime: taskInfo.end,
                    column: columnIndex,
                    totalColumns: totalColumns,
                    config: config
                )

                layouts.append(TaskLayout(
                    task: taskInfo.task,
                    frame: frame,
                    column: columnIndex,
                    totalColumns: totalColumns
                ))
            }
        }

        return layouts
    }

    private func calculateFrame(
        startTime: Date,
        endTime: Date,
        column: Int,
        totalColumns: Int,
        config: LayoutConfig
    ) -> CGRect {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute], from: startTime)
        let startMinutes = (startComponents.hour ?? 0) * 60 + (startComponents.minute ?? 0)
        let baseMinutes = config.startHour * 60

        let endComponents = calendar.dateComponents([.hour, .minute], from: endTime)
        let endMinutes = (endComponents.hour ?? 0) * 60 + (endComponents.minute ?? 0)
        let durationMinutes = endMinutes - startMinutes

        let y = CGFloat(startMinutes - baseMinutes) * (config.hourHeight / 60)
        let height = max(40, CGFloat(durationMinutes) * (config.hourHeight / 60))

        let columnWidth = config.containerWidth / CGFloat(totalColumns)
        let x = CGFloat(column) * columnWidth + config.eventPadding
        let width = columnWidth - (config.eventPadding * 2)

        return CGRect(x: x, y: y, width: max(40, width), height: height)
    }
}
