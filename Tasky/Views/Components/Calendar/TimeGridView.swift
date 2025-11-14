//
//  TimeGridView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Time grid view showing hourly time slots for the calendar
struct TimeGridView: View {

    // MARK: - Properties
    let startHour: Int
    let endHour: Int
    let hourHeight: CGFloat
    let onSlotTap: ((Int, CGPoint) -> Void)?
    let onSlotDragChanged: ((Int, CGPoint) -> Void)?
    let onSlotDragEnded: (() -> Void)?

    // MARK: - Constants
    private enum Layout {
        static let timeLabelWidth: CGFloat = 60
        static let spacing: CGFloat = 12
        static let dividerWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 16
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            ForEach(startHour..<endHour, id: \.self) { hour in
                timeSlot(for: hour)
            }
        }
    }

    // MARK: - Time Slot
    private func timeSlot(for hour: Int) -> some View {
        HStack(alignment: .top, spacing: Layout.spacing) {
            // Time Label
            Text(formatHour(hour))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: Layout.timeLabelWidth, alignment: .trailing)
                .accessibilityLabel("Time slot \(formatHour(hour))")
                .id("hour_\(hour)")

            // Divider line
            Rectangle()
                .fill(Color(.separator))
                .frame(width: Layout.dividerWidth)

            // Interactive area
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: hourHeight)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            onSlotDragChanged?(hour, value.location)
                        }
                        .onEnded { _ in
                            onSlotDragEnded?()
                        }
                )
                .onTapGesture { location in
                    onSlotTap?(hour, location)
                }
                .accessibilityElement()
                .accessibilityLabel("Time slot \(formatHour(hour))")
                .accessibilityHint("Tap to create an event at this time")
        }
        .padding(.horizontal, Layout.horizontalPadding)
    }

    // MARK: - Helper Methods
    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "ha"
        let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date).lowercased()
    }
}

// MARK: - Preview
#Preview {
    ScrollView {
        TimeGridView(
            startHour: 6,
            endHour: 24,
            hourHeight: 60,
            onSlotTap: { hour, location in
                print("Tapped hour \(hour) at location \(location)")
            },
            onSlotDragChanged: { hour, location in
                print("Dragging hour \(hour) at location \(location)")
            },
            onSlotDragEnded: {
                print("Drag ended")
            }
        )
    }
}
