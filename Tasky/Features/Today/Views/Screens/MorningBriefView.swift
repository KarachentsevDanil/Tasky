//
//  MorningBriefView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 27.11.2025.
//

import SwiftUI

/// Morning Brief view - glanceable daily overview
struct MorningBriefView: View {

    // MARK: - Properties
    @StateObject private var viewModel: MorningBriefViewModel
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Initialization
    init(onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: MorningBriefViewModel(onDismiss: onDismiss))
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background gradient
            backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerSection
                    .padding(.top, Constants.Spacing.xl)

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Constants.Spacing.lg) {
                        // Date card
                        dateCard

                        // Stats overview
                        statsOverview

                        // Focus tasks
                        if !viewModel.focusTasks.isEmpty {
                            focusTasksSection
                        }

                        // Schedule preview
                        if viewModel.hasSchedule {
                            scheduleSection
                        }

                        // Empty state
                        if viewModel.briefData?.isEmpty == true {
                            emptyStateCard
                        }
                    }
                    .padding(.horizontal, Constants.Spacing.lg)
                    .padding(.top, Constants.Spacing.md)
                    .padding(.bottom, 120) // Space for buttons
                }

                Spacer()
            }

            // Bottom actions
            VStack {
                Spacer()
                actionButtons
            }
        }
        .opacity(viewModel.isDismissing ? 0 : 1)
        .scaleEffect(viewModel.isDismissing ? 0.9 : 1)
        .task {
            await viewModel.loadBrief()
        }
    }

    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.05, green: 0.05, blue: 0.1)]
                : [Color(red: 0.95, green: 0.95, blue: 1.0), Color(red: 0.9, green: 0.92, blue: 1.0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: Constants.Spacing.xs) {
            Text(viewModel.greeting)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(viewModel.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Constants.Spacing.lg)
    }

    // MARK: - Date Card
    private var dateCard: some View {
        HStack {
            Image(systemName: "calendar")
                .font(.title2)
                .foregroundStyle(.blue)

            Text(viewModel.formattedDate)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(Constants.Spacing.md)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }

    // MARK: - Stats Overview
    private var statsOverview: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Total tasks
            StatCard(
                icon: "checklist",
                value: "\(viewModel.briefData?.totalTasksToday ?? 0)",
                label: "Tasks",
                color: .blue
            )

            // High priority
            StatCard(
                icon: "flag.fill",
                value: "\(viewModel.briefData?.highPriorityCount ?? 0)",
                label: "Priority",
                color: .orange
            )

            // Overdue
            if viewModel.hasOverdue {
                StatCard(
                    icon: "exclamationmark.triangle.fill",
                    value: "\(viewModel.briefData?.overdueCount ?? 0)",
                    label: "Overdue",
                    color: .red
                )
            }
        }
    }

    // MARK: - Focus Tasks Section
    private var focusTasksSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            HStack {
                Image(systemName: "target")
                    .foregroundStyle(.purple)
                Text("Focus on these")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, Constants.Spacing.xs)

            VStack(spacing: Constants.Spacing.sm) {
                ForEach(Array(viewModel.focusTasks.enumerated()), id: \.element.id) { index, task in
                    FocusTaskRow(
                        task: task,
                        rank: index + 1,
                        priorityColor: viewModel.priorityColor(for: task),
                        timeString: viewModel.formattedTime(for: task)
                    )
                }
            }
            .padding(Constants.Spacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        }
    }

    // MARK: - Schedule Section
    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.teal)
                Text("Today's Schedule")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, Constants.Spacing.xs)

            VStack(spacing: 0) {
                ForEach(viewModel.scheduleBlocks) { block in
                    ScheduleBlockRow(block: block)

                    if block.id != viewModel.scheduleBlocks.last?.id {
                        Divider()
                            .padding(.leading, 60)
                    }
                }
            }
            .padding(Constants.Spacing.md)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        }
    }

    // MARK: - Empty State
    private var emptyStateCard: some View {
        VStack(spacing: Constants.Spacing.md) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("All clear!")
                .font(.title2.weight(.semibold))

            Text("No tasks for today. Enjoy your free time or add something new.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(Constants.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }

    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: Constants.Spacing.sm) {
            // Start My Day button
            Button {
                viewModel.startMyDay()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start My Day")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: Constants.ButtonStyle.prominentHeight)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
            }
            .buttonStyle(.plain)

            // Skip button
            Button {
                viewModel.skipBrief()
            } label: {
                Text("Skip for today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.bottom, Constants.Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground).opacity(0),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 160)
            .ignoresSafeArea()
        )
    }

    // MARK: - Card Background
    private var cardBackground: some View {
        Color(.systemBackground)
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Stat Card Component
private struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: Constants.Spacing.xs) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Constants.Spacing.md)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

// MARK: - Focus Task Row Component
private struct FocusTaskRow: View {
    let task: BriefTask
    let rank: Int
    let priorityColor: Color
    let timeString: String?

    var body: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Rank badge
            Text("\(rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(priorityColor)
                .clipShape(Circle())

            // Task info
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)

                HStack(spacing: Constants.Spacing.xs) {
                    if let time = timeString {
                        Label(time, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let listName = task.listName {
                        Text(listName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - Schedule Block Row Component
private struct ScheduleBlockRow: View {
    let block: ScheduleBlock

    var body: some View {
        HStack(spacing: Constants.Spacing.md) {
            // Time
            Text(block.timeString)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // Task
            Text(block.taskTitle)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            // High priority indicator
            if block.isHighPriority {
                Image(systemName: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.vertical, Constants.Spacing.xs)
    }
}

// MARK: - Preview
#Preview("Morning Brief") {
    MorningBriefView(onDismiss: {})
}

#Preview("Morning Brief - Dark") {
    MorningBriefView(onDismiss: {})
        .preferredColorScheme(.dark)
}
