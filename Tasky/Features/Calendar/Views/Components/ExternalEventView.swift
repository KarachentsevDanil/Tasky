//
//  ExternalEventView.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Read-only view for displaying external calendar events in the day calendar
struct ExternalEventView: View {

    // MARK: - Properties

    let event: ExternalEvent
    let layout: ExternalEventLayout

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background with calendar color (muted)
            RoundedRectangle(cornerRadius: 6)
                .fill(event.calendarColor.opacity(0.15))

            // Left accent bar
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(event.calendarColor.opacity(0.6))
                    .frame(width: 3)

                Spacer()
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                // Title
                Text(event.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(layout.frame.height > 40 ? 2 : 1)

                // Time (if not all-day and enough space)
                if !event.isAllDay && layout.frame.height > 30 {
                    Text(event.formattedTimeRange)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Location (if available and enough space)
                if let location = event.location, !location.isEmpty, layout.frame.height > 50 {
                    HStack(spacing: 2) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8))
                        Text(location)
                            .lineLimit(1)
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, 8)
            .padding(.trailing, 4)
            .padding(.vertical, 4)

            // Calendar indicator (bottom right)
            if layout.frame.height > 40 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(event.calendarTitle)
                            .font(.system(size: 8))
                            .foregroundStyle(.quaternary)
                            .padding(.trailing, 4)
                            .padding(.bottom, 2)
                    }
                }
            }
        }
        .frame(width: layout.frame.width, height: layout.frame.height)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Calendar event from \(event.calendarTitle)")
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        var label = event.title

        if event.isAllDay {
            label += ", all day event"
        } else {
            label += ", \(event.formattedTimeRange)"
        }

        if let location = event.location, !location.isEmpty {
            label += ", at \(location)"
        }

        return label
    }
}

/// Layout information for external events
struct ExternalEventLayout: Identifiable {
    let id: String
    let event: ExternalEvent
    var frame: CGRect
    var column: Int
    var totalColumns: Int

    init(event: ExternalEvent, frame: CGRect, column: Int = 0, totalColumns: Int = 1) {
        self.id = event.id
        self.event = event
        self.frame = frame
        self.column = column
        self.totalColumns = totalColumns
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Tall event
        ExternalEventView(
            event: ExternalEvent(
                id: "1",
                title: "Team Meeting",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                isAllDay: false,
                calendarTitle: "Work",
                calendarColorHex: "007AFF",
                location: "Conference Room A",
                notes: nil
            ),
            layout: ExternalEventLayout(
                event: ExternalEvent(
                    id: "1",
                    title: "Team Meeting",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600),
                    isAllDay: false,
                    calendarTitle: "Work",
                    calendarColorHex: "007AFF",
                    location: "Conference Room A",
                    notes: nil
                ),
                frame: CGRect(x: 0, y: 0, width: 200, height: 60)
            )
        )

        // Short event
        ExternalEventView(
            event: ExternalEvent(
                id: "2",
                title: "Quick Call",
                startDate: Date(),
                endDate: Date().addingTimeInterval(900),
                isAllDay: false,
                calendarTitle: "Personal",
                calendarColorHex: "FF9500",
                location: nil,
                notes: nil
            ),
            layout: ExternalEventLayout(
                event: ExternalEvent(
                    id: "2",
                    title: "Quick Call",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(900),
                    isAllDay: false,
                    calendarTitle: "Personal",
                    calendarColorHex: "FF9500",
                    location: nil,
                    notes: nil
                ),
                frame: CGRect(x: 0, y: 0, width: 200, height: 25)
            )
        )
    }
    .padding()
}
