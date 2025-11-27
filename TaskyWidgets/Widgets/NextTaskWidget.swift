//
//  NextTaskWidget.swift
//  TaskyWidgets
//
//  Created by Claude Code on 27.11.2025.
//

import WidgetKit
import SwiftUI

/// Widget showing the next most important task
struct NextTaskWidget: Widget {
    let kind: String = "NextTaskWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextTaskProvider()) { entry in
            NextTaskWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Task")
        .description("See your most important task right now.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget View

struct NextTaskWidgetView: View {
    let entry: NextTaskEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)

                Text("Next Up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()
            }

            if let task = entry.task {
                // Task content
                VStack(alignment: .leading, spacing: 6) {
                    // Priority badge
                    if task.priority >= 2 {
                        HStack(spacing: 4) {
                            Image(systemName: "flag.fill")
                                .font(.system(size: 10))
                            Text("High Priority")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundStyle(.red)
                    }

                    // Task title
                    Text(task.title)
                        .font(.subheadline.bold())
                        .lineLimit(3)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    // Footer info
                    HStack {
                        // Time/Date info
                        if let time = task.formattedScheduledTime {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(time)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        } else if let due = task.formattedDueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(due)
                            }
                            .font(.caption2)
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                        }

                        Spacer()

                        // List indicator
                        if let listName = task.listName, let colorHex = task.listColorHex {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 6, height: 6)
                                Text(listName)
                                    .lineLimit(1)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // Empty state
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.green)

                    Text("You're all caught up!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Previews

#Preview("With Task", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    NextTaskEntry(
        date: Date(),
        task: WidgetTask(
            id: UUID(),
            title: "Review and merge feature branch PR",
            isCompleted: false,
            dueDate: Date(),
            scheduledTime: Calendar.current.date(bySettingHour: 14, minute: 30, second: 0, of: Date()),
            priority: 2,
            aiPriorityScore: 95,
            listName: "Work",
            listColorHex: "007AFF"
        )
    )
}

#Preview("Empty", as: .systemSmall) {
    NextTaskWidget()
} timeline: {
    NextTaskEntry(date: Date(), task: nil)
}
