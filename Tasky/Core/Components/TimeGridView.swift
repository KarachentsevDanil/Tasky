//
//  TimeGridView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Time grid view showing hourly time slots for the calendar
/// Uses a global drag gesture overlay for cross-hour event creation
struct TimeGridView: View {

    // MARK: - Properties
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat
    let onSlotTap: ((CGFloat) -> Void)?           // Global Y position
    let onDragChanged: ((CGFloat) -> Void)?        // Global Y during drag
    let onDragStarted: ((CGFloat) -> Void)?        // Global Y at drag start
    let onDragEnded: (() -> Void)?

    // MARK: - State
    @State private var isDragging = false

    // MARK: - Constants
    private enum Layout {
        static let timeLabelWidth: CGFloat = 60
        static let spacing: CGFloat = 12
        static let dividerWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 16
        static let dragThreshold: CGFloat = 5  // Minimum distance to start drag
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Time labels and grid lines (visual only)
            VStack(spacing: 0) {
                ForEach(startHour..<endHour, id: \.self) { hour in
                    timeSlotRow(for: hour)
                }
            }

            // Global drag gesture overlay (spans entire grid)
            globalDragOverlay
        }
    }

    // MARK: - Time Slot Row (Visual Only)
    private func timeSlotRow(for hour: Int) -> some View {
        HStack(alignment: .top, spacing: Layout.spacing) {
            // Time Label
            Text(formatHour(hour))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: Layout.timeLabelWidth, alignment: .trailing)
                .id("hour_\(hour)")

            // Divider line
            Rectangle()
                .fill(Color(.separator))
                .frame(width: Layout.dividerWidth)

            // Spacer for the interactive area (gesture handled by overlay)
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: hourHeight)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .accessibilityElement()
        .accessibilityLabel("Time slot \(formatHour(hour))")
        .accessibilityHint("Tap to create an event at this time")
    }

    // MARK: - Global Drag Overlay
    private var globalDragOverlay: some View {
        // Position overlay over the interactive area only (not time labels)
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .padding(.leading, Layout.horizontalPadding + Layout.timeLabelWidth + Layout.spacing + Layout.dividerWidth + Layout.spacing)
            .padding(.trailing, Layout.horizontalPadding)
            .gesture(
                DragGesture(minimumDistance: Layout.dragThreshold)
                    .onChanged { value in
                        let globalY = value.startLocation.y + value.translation.height

                        if !isDragging {
                            // First drag event - start the drag
                            isDragging = true
                            onDragStarted?(value.startLocation.y)
                        }

                        onDragChanged?(globalY)
                    }
                    .onEnded { _ in
                        isDragging = false
                        onDragEnded?()
                    }
            )
            .onTapGesture { location in
                // Only trigger tap if not dragging
                if !isDragging {
                    onSlotTap?(location.y)
                }
            }
    }

    // MARK: - Helper Methods
    private func formatHour(_ hour: Int) -> String {
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return AppDateFormatters.hourFormatter.string(from: date).lowercased()
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        TimeGridView(
            startHour: 6,
            endHour: 24,
            hourHeight: 60,
            onSlotTap: { globalY in
                print("Tapped at Y: \(globalY)")
            },
            onDragChanged: { globalY in
                print("Dragging at Y: \(globalY)")
            },
            onDragStarted: { globalY in
                print("Drag started at Y: \(globalY)")
            },
            onDragEnded: {
                print("Drag ended")
            }
        )
    }
}
