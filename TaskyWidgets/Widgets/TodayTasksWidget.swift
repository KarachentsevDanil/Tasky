//
//  TodayTasksWidget.swift
//  TaskyWidgets
//
//  Created by Claude Code on 27.11.2025.
//

import WidgetKit
import SwiftUI

/// Widget showing today's tasks with completion progress
struct TodayTasksWidget: Widget {
    let kind: String = "TodayTasksWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TodayTasksProvider()) { entry in
            TodayTasksWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Today's Tasks")
        .description("See your tasks for today at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget View

struct TodayTasksWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TodayTasksEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        default:
            smallWidgetView
        }
    }

    // MARK: - Small Widget

    private var smallWidgetView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with progress ring
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(formattedDate)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: entry.completionPercentage)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    Text("\(entry.completedCount)/\(entry.totalCount)")
                        .font(.system(size: 10, weight: .medium))
                }
                .frame(width: 36, height: 36)
            }

            Divider()

            // Task list
            if entry.tasks.isEmpty {
                Spacer()
                Text("All done!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(entry.tasks.prefix(3)) { task in
                    SmallTaskRow(task: task)
                }
                Spacer(minLength: 0)
            }
        }
        .padding()
    }

    // MARK: - Medium Widget

    private var mediumWidgetView: some View {
        HStack(spacing: 16) {
            // Left side - Progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Today")
                    .font(.headline)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                // Large progress ring
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 8)

                    Circle()
                        .trim(from: 0, to: entry.completionPercentage)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 2) {
                        Text("\(Int(entry.completionPercentage * 100))%")
                            .font(.title2.bold())

                        Text("done")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                Spacer()
            }

            Divider()

            // Right side - Tasks
            VStack(alignment: .leading, spacing: 6) {
                if entry.tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.green)
                        Text("All tasks complete!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ForEach(entry.tasks.prefix(5)) { task in
                        MediumTaskRow(task: task)
                    }

                    if entry.tasks.count > 5 {
                        Text("+\(entry.tasks.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .padding()
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E, MMM d"
        return formatter.string(from: entry.date)
    }
}

// MARK: - Task Row Components

struct SmallTaskRow: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 6) {
            // Priority indicator
            if task.priority >= 2 {
                Image(systemName: "flag.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.red)
            }

            Text(task.title)
                .font(.caption)
                .lineLimit(1)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
    }
}

struct MediumTaskRow: View {
    let task: WidgetTask

    var body: some View {
        HStack(spacing: 8) {
            // Checkbox style indicator
            Circle()
                .stroke(task.priority >= 2 ? Color.red : Color.secondary, lineWidth: 1.5)
                .frame(width: 14, height: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .font(.subheadline)
                    .lineLimit(1)

                if let time = task.formattedScheduledTime {
                    Text(time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // List color indicator
            if let colorHex = task.listColorHex {
                Circle()
                    .fill(Color(hex: colorHex) ?? .gray)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    TodayTasksWidget()
} timeline: {
    TodayTasksEntry(
        date: Date(),
        tasks: [
            WidgetTask(id: UUID(), title: "Review PR", isCompleted: false, dueDate: Date(), scheduledTime: nil, priority: 2, aiPriorityScore: 90, listName: "Work", listColorHex: "007AFF"),
            WidgetTask(id: UUID(), title: "Buy groceries", isCompleted: false, dueDate: Date(), scheduledTime: nil, priority: 0, aiPriorityScore: 50, listName: "Personal", listColorHex: "FF9500"),
            WidgetTask(id: UUID(), title: "Call dentist", isCompleted: false, dueDate: Date(), scheduledTime: nil, priority: 1, aiPriorityScore: 60, listName: nil, listColorHex: nil)
        ],
        completedCount: 3,
        totalCount: 6
    )
}

#Preview("Medium", as: .systemMedium) {
    TodayTasksWidget()
} timeline: {
    TodayTasksEntry(
        date: Date(),
        tasks: [
            WidgetTask(id: UUID(), title: "Review PR for feature branch", isCompleted: false, dueDate: Date(), scheduledTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()), priority: 2, aiPriorityScore: 90, listName: "Work", listColorHex: "007AFF"),
            WidgetTask(id: UUID(), title: "Buy groceries", isCompleted: false, dueDate: Date(), scheduledTime: Calendar.current.date(bySettingHour: 12, minute: 30, second: 0, of: Date()), priority: 0, aiPriorityScore: 50, listName: "Personal", listColorHex: "FF9500"),
            WidgetTask(id: UUID(), title: "Call dentist", isCompleted: false, dueDate: Date(), scheduledTime: nil, priority: 1, aiPriorityScore: 60, listName: nil, listColorHex: nil),
            WidgetTask(id: UUID(), title: "Prepare presentation", isCompleted: false, dueDate: Date(), scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: Date()), priority: 2, aiPriorityScore: 85, listName: "Work", listColorHex: "007AFF")
        ],
        completedCount: 2,
        totalCount: 6
    )
}
