//
//  WeeklyReviewFlowView.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Container view for the weekly review flow
struct WeeklyReviewFlowView: View {

    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - ViewModel
    @StateObject private var viewModel = WeeklyReviewViewModel()

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                // Content
                switch viewModel.loadingState {
                case .loading:
                    loadingView

                case .loaded:
                    reviewContent

                case .error(let error):
                    errorView(error)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .principal) {
                    progressIndicator
                }
            }
        }
        .interactiveDismissDisabled(viewModel.currentStep != .celebrate)
        .task {
            await viewModel.loadReviewData()
        }
    }

    // MARK: - Progress Indicator
    private var progressIndicator: some View {
        HStack(spacing: Constants.Spacing.xs) {
            ForEach(ReviewStep.allCases, id: \.self) { step in
                Circle()
                    .fill(step.rawValue <= viewModel.currentStep.rawValue ? Color.accentColor : Color(.tertiarySystemFill))
                    .frame(width: 8, height: 8)
                    .animation(reduceMotion ? .none : .spring(response: 0.3), value: viewModel.currentStep)
            }
        }
        .accessibilityLabel("Step \(viewModel.currentStep.rawValue + 1) of \(ReviewStep.allCases.count)")
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: Constants.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Loading your week...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error View
    private func errorView(_ error: Error) -> some View {
        VStack(spacing: Constants.Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Unable to Load Review")
                .font(.headline)

            Text(error.localizedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Constants.Spacing.xl)

            Button("Try Again") {
                Task {
                    await viewModel.loadReviewData()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Review Content
    @ViewBuilder
    private var reviewContent: some View {
        TabView(selection: $viewModel.currentStep) {
            // Step 1: Celebrate
            if let data = viewModel.weekData {
                ReviewCelebrateStep(
                    data: data,
                    showConfetti: viewModel.showConfetti,
                    onContinue: { viewModel.goToNextStep() }
                )
                .tag(ReviewStep.celebrate)
            }

            // Step 2: Incomplete Tasks
            ReviewIncompleteStep(
                tasks: viewModel.incompleteTasks,
                onAction: { task, action in
                    viewModel.handleIncompleteTask(task, action: action)
                },
                onSkip: { viewModel.skipIncomplete() },
                onContinue: { viewModel.goToNextStep() }
            )
            .tag(ReviewStep.incomplete)

            // Step 3: Overdue Tasks
            ReviewOverdueStep(
                tasks: viewModel.overdueTasks,
                onAction: { task, action in
                    viewModel.handleOverdueTask(task, action: action)
                },
                onSkip: { viewModel.skipOverdue() },
                onContinue: { viewModel.goToNextStep() }
            )
            .tag(ReviewStep.overdue)

            // Step 4: Upcoming Tasks
            ReviewUpcomingStep(
                tasks: viewModel.upcomingTasks,
                onContinue: { viewModel.goToNextStep() }
            )
            .tag(ReviewStep.upcoming)

            // Step 5: Summary
            ReviewSummaryStep(
                newStreak: viewModel.newStreak,
                deletedCount: viewModel.deletedCount,
                rescheduledCount: viewModel.rescheduledCount,
                keptCount: viewModel.keptCount,
                onComplete: {
                    viewModel.completeReview()
                    dismiss()
                }
            )
            .tag(ReviewStep.summary)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .animation(reduceMotion ? .none : .spring(response: 0.3, dampingFraction: 0.8), value: viewModel.currentStep)
    }
}

// MARK: - Preview
#Preview {
    WeeklyReviewFlowView()
}
