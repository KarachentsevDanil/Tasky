//
//  FocusTimerView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI
internal import CoreData

/// Focus timer component with compact badge that opens full timer sheet
struct FocusTimerView: View {

    // MARK: - Properties
    @ObservedObject var viewModel: FocusTimerViewModel
    let task: TaskEntity
    @State private var isExpanded = false

    // MARK: - Body
    var body: some View {
        compactBadge
            .sheet(isPresented: $isExpanded) {
                FocusTimerSheet(viewModel: viewModel, task: task)
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
