//
//  DurationSelector.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI

/// Time duration selection with presets and custom picker
/// Supports both "deadline only" (just start time) and "duration" mode (start + end)
struct DurationSelector: View {

    // MARK: - Properties
    @Binding var startTime: Date?
    @Binding var endTime: Date?
    var referenceDate: Date = Date()

    // MARK: - Private State
    @State private var internalStartTime: Date = Date()
    @State private var internalEndTime: Date = Date()
    @State private var isDeadlineOnly: Bool = false

    // MARK: - Duration Presets (0 = deadline only)
    private let presets: [(label: String, minutes: Int)] = [
        ("1 Min", 0),    // Deadline only - just time, no duration
        ("15m", 15),
        ("30m", 30),
        ("1h", 60),
        ("2h", 120)
    ]

    // MARK: - Computed Properties
    private var hasTime: Bool {
        startTime != nil
    }

    private var selectedDuration: Int? {
        guard startTime != nil else { return nil }
        if isDeadlineOnly || endTime == nil { return 0 }
        guard let start = startTime, let end = endTime else { return nil }
        return Int(end.timeIntervalSince(start) / 60)
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Duration presets - scrollable to fit all
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Constants.Spacing.sm) {
                    ForEach(presets, id: \.minutes) { preset in
                        durationChip(preset.label, minutes: preset.minutes)
                    }
                }
            }

            // Time pickers (shown when time is set)
            if hasTime {
                VStack(spacing: Constants.Spacing.sm) {
                    HStack {
                        Text(isDeadlineOnly ? "Time" : "Start")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 50, alignment: .leading)

                        DatePicker(
                            "",
                            selection: $internalStartTime,
                            displayedComponents: .hourAndMinute
                        )
                        .labelsHidden()
                        .onChange(of: internalStartTime) { _, newValue in
                            startTime = combineDateTime(referenceDate, time: newValue)
                            // Ensure end time is after start (if not deadline only)
                            if !isDeadlineOnly && internalEndTime <= newValue {
                                let newEnd = newValue.addingTimeInterval(1800)
                                internalEndTime = newEnd
                                endTime = combineDateTime(referenceDate, time: newEnd)
                            }
                        }

                        Spacer()
                    }

                    // Only show end time picker when not in deadline-only mode
                    if !isDeadlineOnly {
                        HStack {
                            Text("End")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 50, alignment: .leading)

                            DatePicker(
                                "",
                                selection: $internalEndTime,
                                in: internalStartTime.addingTimeInterval(900)...,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .onChange(of: internalEndTime) { _, newValue in
                                endTime = combineDateTime(referenceDate, time: newValue)
                            }

                            Spacer()
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            setupInitialTimes()
        }
    }

    // MARK: - Duration Chip
    @ViewBuilder
    private func durationChip(_ label: String, minutes: Int) -> some View {
        let isSelected = selectedDuration == minutes

        Button {
            selectDuration(minutes)
            HapticManager.shared.selectionChanged()
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .fixedSize(horizontal: true, vertical: false)
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers
    private func setupInitialTimes() {
        if let start = startTime {
            internalStartTime = start
        } else {
            internalStartTime = roundToNearest15(Date())
        }

        if let end = endTime {
            internalEndTime = end
            isDeadlineOnly = false
        } else if startTime != nil {
            // Has start time but no end time = deadline only
            isDeadlineOnly = true
            internalEndTime = internalStartTime.addingTimeInterval(3600)
        } else {
            internalEndTime = internalStartTime.addingTimeInterval(3600)
        }
    }

    private func selectDuration(_ minutes: Int) {
        let roundedStart = roundToNearest15(Date())
        internalStartTime = roundedStart

        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if minutes == 0 {
                // Deadline only mode - just time, no end time
                isDeadlineOnly = true
                startTime = combineDateTime(referenceDate, time: internalStartTime)
                endTime = nil
            } else {
                // Duration mode - start + end time
                isDeadlineOnly = false
                internalEndTime = roundedStart.addingTimeInterval(TimeInterval(minutes * 60))
                startTime = combineDateTime(referenceDate, time: internalStartTime)
                endTime = combineDateTime(referenceDate, time: internalEndTime)
            }
        }
    }

    private func roundToNearest15(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let minute = components.minute ?? 0
        let roundedMinute = ((minute + 7) / 15) * 15
        var newComponents = components
        newComponents.minute = roundedMinute % 60
        if roundedMinute >= 60 {
            newComponents.hour = (components.hour ?? 0) + 1
        }
        return calendar.date(from: newComponents) ?? date
    }

    private func combineDateTime(_ date: Date, time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? date
    }
}

// MARK: - Time Display Helper
extension DurationSelector {
    /// Format time range for display
    static func formatTimeRange(start: Date?, end: Date?) -> String? {
        guard let start else { return nil }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        // If no end time, just show start time (deadline only)
        if end == nil {
            return formatter.string(from: start)
        }

        return "\(formatter.string(from: start)) - \(formatter.string(from: end!))"
    }
}

// MARK: - Preview
#Preview("No Time Set") {
    struct PreviewWrapper: View {
        @State private var startTime: Date?
        @State private var endTime: Date?

        var body: some View {
            VStack(spacing: 20) {
                Text("Time: \(DurationSelector.formatTimeRange(start: startTime, end: endTime) ?? "Not set")")
                    .font(.headline)

                DurationSelector(
                    startTime: $startTime,
                    endTime: $endTime
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("With Duration") {
    struct PreviewWrapper: View {
        @State private var startTime: Date? = Date()
        @State private var endTime: Date? = Date().addingTimeInterval(3600)

        var body: some View {
            DurationSelector(
                startTime: $startTime,
                endTime: $endTime
            )
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("Deadline Only") {
    struct PreviewWrapper: View {
        @State private var startTime: Date? = Date()
        @State private var endTime: Date?

        var body: some View {
            VStack(spacing: 20) {
                Text("Time: \(DurationSelector.formatTimeRange(start: startTime, end: endTime) ?? "Not set")")
                    .font(.headline)

                DurationSelector(
                    startTime: $startTime,
                    endTime: $endTime
                )
            }
            .padding()
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
