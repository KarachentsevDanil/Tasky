//
//  FocusTimerView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI
internal import CoreData

/// Focus timer component with compact and expanded modes
struct FocusTimerView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: FocusTimerViewModel
    let task: TaskEntity
    @State private var isExpanded = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - Body
    var body: some View {
        compactBadge
            .sheet(isPresented: $isExpanded) {
                NavigationStack {
                    expandedView
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button {
                                    isExpanded = false
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .interactiveDismissDisabled(false)
            }
    }

    // MARK: - Compact Badge
    private var compactBadge: some View {
        Button {
            isExpanded = true
            if viewModel.timerState == .idle {
                viewModel.startTimer(for: task)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: timerIcon)
                    .font(.caption2)

                if viewModel.currentTask?.id == task.id && viewModel.timerState != .idle {
                    Text(viewModel.formattedTime)
                        .font(.caption2.monospacedDigit())
                } else if task.focusTimeSeconds > 0 {
                    Text(task.formattedFocusTime)
                        .font(.caption2)
                }
            }
            .foregroundStyle(timerColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(timerColor.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded View
    private var expandedView: some View {
        ZStack {
            // Animated background gradient
            LinearGradient(
                colors: [
                    timerColor.opacity(viewModel.timerState == .running ? 0.08 : 0.05),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.8), value: viewModel.timerState)

            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 24)

                    // Task title and session type
                    VStack(spacing: 16) {
                        Text(task.title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .padding(.horizontal, 32)
                            .foregroundStyle(.primary)

                        // Session type badge with animated background
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.isBreak ? "cup.and.saucer.fill" : "brain.head.profile")
                                .font(.caption)

                            Text(viewModel.sessionType)
                                .font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(timerColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(timerColor.opacity(0.15))
                                .overlay(
                                    Capsule()
                                        .stroke(timerColor.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: timerColor.opacity(0.2), radius: 8, y: 4)
                    }

                    // Progress Ring
                    FocusTimerProgressRing(
                        viewModel: viewModel,
                        timerColor: timerColor
                    )

                    // Controls
                    FocusTimerControls(
                        task: task,
                        viewModel: viewModel,
                        timerColor: timerColor,
                        onDismiss: { isExpanded = false }
                    )

                    // Stats Section
                    if !viewModel.isBreak {
                        FocusTimerStats(task: task)
                    }

                    Spacer()
                        .frame(height: 40)
                }
            }
        }
    }

    // MARK: - Computed Properties
    private var timerIcon: String {
        if viewModel.currentTask?.id == task.id {
            switch viewModel.timerState {
            case .idle: return "timer"
            case .running: return "timer.circle.fill"
            case .paused: return "pause.circle.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
        return "timer"
    }

    private var timerColor: Color {
        if viewModel.isBreak {
            return .green
        }
        switch viewModel.timerState {
        case .idle: return .blue
        case .running: return .orange
        case .paused: return .yellow
        case .completed: return .green
        }
    }
}

// MARK: - Preview
#Preview {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.isCompleted = false
    task.createdAt = Date()
    task.focusTimeSeconds = 1800 // 30 minutes

    return VStack(spacing: 40) {
        // Compact badge
        FocusTimerView(viewModel: FocusTimerViewModel(), task: task)

        // Expanded view preview
        FocusTimerView(viewModel: {
            let vm = FocusTimerViewModel()
            vm.startTimer(for: task)
            return vm
        }(), task: task)
    }
    .padding()
}
