//
//  WeekDayCell.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 25.11.2025.
//

import SwiftUI

/// Modern day cell with pill-shaped selection inspired by Things 3 and Apple Calendar
struct WeekDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let taskCount: Int
    let allCompleted: Bool
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Properties

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private var weekdaySymbol: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }

    private var isWeekend: Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    // MARK: - Body

    var body: some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            onTap()
        }) {
            VStack(spacing: Constants.Spacing.xs) {
                // Weekday label
                Text(weekdaySymbol)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(weekdayColor)
                    .textCase(.uppercase)

                // Day number with selection pill
                ZStack {
                    // Selection background
                    if isSelected {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 2)
                    }

                    // Today ring (when not selected)
                    if isToday && !isSelected {
                        Circle()
                            .stroke(Color.accentColor, lineWidth: 2)
                            .frame(width: 36, height: 36)
                    }

                    // Day number
                    Text(dayNumber)
                        .font(.body.weight(isToday ? .bold : .medium))
                        .foregroundStyle(dayNumberColor)
                        .frame(width: 36, height: 36)
                }

                // Task indicator dots
                taskIndicator
            }
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(DayCellButtonStyle())
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Double tap to view tasks for this day")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Weekday Color

    private var weekdayColor: Color {
        if isSelected {
            return .accentColor
        } else if isToday {
            return .accentColor
        } else if isWeekend {
            return .secondary.opacity(0.6)
        } else {
            return .secondary
        }
    }

    // MARK: - Day Number Color

    private var dayNumberColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return .accentColor
        } else if !isCurrentMonth {
            return .secondary.opacity(0.4)
        } else if isWeekend {
            return .primary.opacity(0.6)
        } else {
            return .primary
        }
    }

    // MARK: - Task Indicator

    @ViewBuilder
    private var taskIndicator: some View {
        HStack(spacing: 3) {
            if allCompleted && taskCount > 0 {
                // Checkmark for all completed
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.green)
            } else if taskCount > 0 {
                // Minimal dots (max 3 visible)
                ForEach(0..<min(taskCount, 3), id: \.self) { _ in
                    Circle()
                        .fill(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                        .frame(width: 5, height: 5)
                }
                // Plus indicator for more tasks
                if taskCount > 3 {
                    Text("+")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.accentColor)
                }
            }
        }
        .frame(height: 8)
    }

    // MARK: - Accessibility

    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        var label = formatter.string(from: date)

        if isToday {
            label += ", today"
        }

        if isSelected {
            label += ", selected"
        }

        if allCompleted && taskCount > 0 {
            label += ", all \(taskCount) tasks completed"
        } else if taskCount > 0 {
            label += ", \(taskCount) task\(taskCount == 1 ? "" : "s")"
        } else {
            label += ", no tasks"
        }

        return label
    }
}

// MARK: - Custom Button Style

private struct DayCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview("Week Strip") {
    VStack(spacing: 20) {
        // Light mode preview
        HStack(spacing: 0) {
            WeekDayCell(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                isSelected: false,
                isToday: false,
                isCurrentMonth: true,
                taskCount: 0,
                allCompleted: false,
                onTap: {}
            )

            WeekDayCell(
                date: Date(),
                isSelected: true,
                isToday: true,
                isCurrentMonth: true,
                taskCount: 3,
                allCompleted: false,
                onTap: {}
            )

            WeekDayCell(
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date())!,
                isSelected: false,
                isToday: false,
                isCurrentMonth: true,
                taskCount: 2,
                allCompleted: true,
                onTap: {}
            )

            WeekDayCell(
                date: Calendar.current.date(byAdding: .day, value: 2, to: Date())!,
                isSelected: false,
                isToday: false,
                isCurrentMonth: true,
                taskCount: 5,
                allCompleted: false,
                onTap: {}
            )

            WeekDayCell(
                date: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
                isSelected: false,
                isToday: false,
                isCurrentMonth: true,
                taskCount: 0,
                allCompleted: false,
                onTap: {}
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))

        // Today not selected
        HStack(spacing: 0) {
            WeekDayCell(
                date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
                isSelected: true,
                isToday: false,
                isCurrentMonth: true,
                taskCount: 1,
                allCompleted: false,
                onTap: {}
            )

            WeekDayCell(
                date: Date(),
                isSelected: false,
                isToday: true,
                isCurrentMonth: true,
                taskCount: 2,
                allCompleted: false,
                onTap: {}
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
