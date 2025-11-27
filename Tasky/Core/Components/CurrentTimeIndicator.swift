//
//  CurrentTimeIndicator.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Red line indicator showing current time in calendar view
struct CurrentTimeIndicator: View {

    // MARK: - Properties
    let startHour: Int
    let hourHeight: CGFloat
    let containerWidth: CGFloat

    // MARK: - Constants
    private enum Layout {
        static let timeLabelWidth: CGFloat = 40
        static let spacing: CGFloat = 8
        static let dividerWidth: CGFloat = 1
        static let horizontalPadding: CGFloat = 12
        static let indicatorDotSize: CGFloat = 10
        static let indicatorLineHeight: CGFloat = 2
    }

    // MARK: - Computed
    private var leftOffset: CGFloat {
        Layout.horizontalPadding + Layout.timeLabelWidth + Layout.spacing + Layout.dividerWidth + Layout.spacing
    }

    // MARK: - Body
    var body: some View {
        TimelineView(.everyMinute) { context in
            let yPosition = calculateTimeIndicatorPosition(for: context.date)

            HStack(alignment: .center, spacing: 0) {
                // Orange dot
                Circle()
                    .fill(Color.orange)
                    .frame(width: Layout.indicatorDotSize, height: Layout.indicatorDotSize)

                // Orange horizontal line
                Rectangle()
                    .fill(Color.orange)
                    .frame(height: Layout.indicatorLineHeight)
            }
            .padding(.leading, leftOffset)
            .padding(.trailing, Layout.horizontalPadding)
            .offset(y: yPosition - Layout.indicatorDotSize / 2)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Current time: \(formatTime(context.date))")
        }
    }

    // MARK: - Helper Methods
    private func calculateTimeIndicatorPosition(for date: Date) -> CGFloat {
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: date)
        let currentMinute = calendar.component(.minute, from: date)

        let hoursFromStart = CGFloat(currentHour) - CGFloat(startHour) + (CGFloat(currentMinute) / 60.0)
        return hoursFromStart * hourHeight
    }

    private func formatTime(_ date: Date) -> String {
        AppDateFormatters.timeFormatter.string(from: date)
    }
}

// MARK: - Preview
#Preview {
    ZStack(alignment: .topLeading) {
        Color.gray.opacity(0.1)
            .frame(height: 1000)

        CurrentTimeIndicator(
            startHour: 6,
            hourHeight: 60,
            containerWidth: 400
        )
    }
}
