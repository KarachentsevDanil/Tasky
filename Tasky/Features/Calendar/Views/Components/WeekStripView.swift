//
//  WeekStripView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 25.11.2025.
//

import SwiftUI

/// Modern floating week strip with elegant navigation
struct WeekStripView: View {
    @Binding var selectedDate: Date
    let tasksForDate: (Date) -> [TaskEntity]

    @State private var showMonthPicker = false
    @State private var weekOffset: Int = 0
    @GestureState private var dragOffset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let calendar = Calendar.current
    private let swipeThreshold: CGFloat = 50

    // MARK: - Computed Properties

    private var weekDates: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: startOfWeek)
        }
    }

    private var monthText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: selectedDate)
    }

    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: selectedDate)
    }

    private var isCurrentWeek: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var isCurrentYear: Bool {
        calendar.isDate(selectedDate, equalTo: Date(), toGranularity: .year)
    }

    private var totalTasksThisWeek: Int {
        weekDates.reduce(0) { sum, date in
            sum + tasksForDate(date).filter { !$0.isCompleted }.count
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header with month/year
            headerView

            // Week strip card
            weekStripCard
        }
        .sheet(isPresented: $showMonthPicker) {
            monthPickerSheet
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack(alignment: .firstTextBaseline) {
            // Month and year
            Button {
                HapticManager.shared.lightImpact()
                showMonthPicker = true
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Constants.Spacing.sm) {
                    Text(monthText)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    if !isCurrentYear {
                        Text(yearText)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.down.circle.fill")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Select month, currently \(monthText) \(yearText)")
            .accessibilityHint("Opens calendar picker")

            Spacer()

            // Navigation buttons
            HStack(spacing: Constants.Spacing.xs) {
                // Previous week
                Button {
                    navigateWeek(direction: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous week")

                // Today button
                if !isCurrentWeek {
                    Button {
                        HapticManager.shared.mediumImpact()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            selectedDate = Date()
                        }
                    } label: {
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, Constants.Spacing.md)
                            .padding(.vertical, Constants.Spacing.sm)
                            .background(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Go to today")
                }

                // Next week
                Button {
                    navigateWeek(direction: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next week")
            }
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.top, Constants.Spacing.md)
        .padding(.bottom, Constants.Spacing.sm)
    }

    // MARK: - Week Strip Card

    private var weekStripCard: some View {
        VStack(spacing: 0) {
            // Week days
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    let tasks = tasksForDate(date)
                    let incompleteTasks = tasks.filter { !$0.isCompleted }
                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let isToday = calendar.isDateInToday(date)
                    let isCurrentMonth = calendar.isDate(date, equalTo: selectedDate, toGranularity: .month)

                    WeekDayCell(
                        date: date,
                        isSelected: isSelected,
                        isToday: isToday,
                        isCurrentMonth: isCurrentMonth,
                        taskCount: incompleteTasks.count,
                        allCompleted: !tasks.isEmpty && incompleteTasks.isEmpty,
                        onTap: {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                selectedDate = date
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, Constants.Spacing.xs)
            .padding(.vertical, Constants.Spacing.sm)
        }
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .shadow(
                    color: colorScheme == .dark ? .clear : .black.opacity(0.06),
                    radius: 8,
                    y: 2
                )
        )
        .padding(.horizontal, Constants.Spacing.md)
        .padding(.bottom, Constants.Spacing.sm)
        .offset(x: dragOffset)
        .gesture(swipeGesture)
    }

    // MARK: - Navigation

    private func navigateWeek(direction: Int) {
        HapticManager.shared.lightImpact()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            selectedDate = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) ?? selectedDate
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($dragOffset) { value, state, _ in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // Rubber band effect
                let resistance: CGFloat = 0.4
                state = value.translation.width * resistance
            }
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let velocity = value.predictedEndTranslation.width - value.translation.width
                let shouldNavigate = abs(value.translation.width) > swipeThreshold ||
                                     (abs(value.translation.width) > 25 && abs(velocity) > 80)

                if shouldNavigate {
                    let direction = value.translation.width > 0 ? -1 : 1
                    navigateWeek(direction: direction)
                }
            }
    }

    // MARK: - Month Picker Sheet

    private var monthPickerSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Quick navigation buttons
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Constants.Spacing.sm) {
                        quickDateButton(label: "Today", date: Date())
                        quickDateButton(label: "Tomorrow", date: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
                        quickDateButton(label: "Next Week", date: calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date())
                        quickDateButton(label: "Next Month", date: calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date())
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Constants.Spacing.sm)
                }

                Divider()

                DatePicker(
                    "Select Date",
                    selection: Binding(
                        get: { selectedDate },
                        set: { newDate in
                            HapticManager.shared.selectionChanged()
                            selectedDate = newDate
                            showMonthPicker = false
                        }
                    ),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
            }
            .navigationTitle("Jump to Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showMonthPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func quickDateButton(label: String, date: Date) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            selectedDate = date
            showMonthPicker = false
        } label: {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(calendar.isDate(date, inSameDayAs: selectedDate) ? .white : .primary)
                .padding(.horizontal, Constants.Spacing.md)
                .padding(.vertical, Constants.Spacing.sm)
                .background(
                    Capsule()
                        .fill(calendar.isDate(date, inSameDayAs: selectedDate) ? Color.accentColor : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview("Week Strip") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Date()

        var body: some View {
            VStack(spacing: 0) {
                WeekStripView(
                    selectedDate: $selectedDate,
                    tasksForDate: { date in
                        // Mock tasks for preview
                        if Calendar.current.isDateInToday(date) {
                            return []
                        }
                        return []
                    }
                )

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}

#Preview("Week Strip - Different Week") {
    struct PreviewWrapper: View {
        @State private var selectedDate = Calendar.current.date(byAdding: .weekOfYear, value: 2, to: Date())!

        var body: some View {
            VStack(spacing: 0) {
                WeekStripView(
                    selectedDate: $selectedDate,
                    tasksForDate: { _ in [] }
                )

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
        }
    }

    return PreviewWrapper()
}
