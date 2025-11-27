//
//  FocusTimerSettings.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI
internal import CoreData

/// Settings panel for focus timer (duration presets, session count, sound toggle)
struct FocusTimerSettings: View {
    @ObservedObject var viewModel: FocusTimerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Focus Duration Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Focus Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(FocusTimerViewModel.focusDurationPresets, id: \.self) { minutes in
                                    DurationChip(
                                        minutes: minutes,
                                        isSelected: viewModel.currentFocusDurationMinutes == minutes,
                                        color: .orange
                                    ) {
                                        viewModel.updateFocusDuration(minutes: minutes)
                                        HapticManager.shared.selectionChanged()
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Label("Focus", systemImage: "brain.head.profile")
                }

                // Break Duration Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Break Duration")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(FocusTimerViewModel.breakDurationPresets, id: \.self) { minutes in
                                    DurationChip(
                                        minutes: minutes,
                                        isSelected: viewModel.currentBreakDurationMinutes == minutes,
                                        color: .green
                                    ) {
                                        viewModel.updateBreakDuration(minutes: minutes)
                                        HapticManager.shared.selectionChanged()
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Label("Break", systemImage: "cup.and.saucer.fill")
                }

                // Session Goal Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Daily Session Goal")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text("\(viewModel.targetSessionCount) sessions")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }

                        HStack(spacing: 8) {
                            ForEach([2, 4, 6, 8], id: \.self) { count in
                                SessionCountChip(
                                    count: count,
                                    isSelected: viewModel.targetSessionCount == count
                                ) {
                                    viewModel.updateTargetSessions(count)
                                    HapticManager.shared.selectionChanged()
                                }
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Label("Goal", systemImage: "target")
                }

                // Sound Settings
                Section {
                    Toggle(isOn: Binding(
                        get: { viewModel.isSoundEnabled },
                        set: { _ in viewModel.toggleSound() }
                    )) {
                        Label {
                            Text("Completion Sound")
                        } icon: {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                } header: {
                    Label("Sound", systemImage: "speaker.wave.2")
                }

                // Tips Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pomodoro Technique Tips")
                            .font(.subheadline.weight(.semibold))

                        Text("• Work in focused 25-minute intervals")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("• Take short 5-minute breaks between sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text("• After 4 sessions, take a longer 15-30 min break")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Label("Tips", systemImage: "lightbulb.fill")
                }
            }
            .navigationTitle("Timer Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Duration Chip

private struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(minutes)m")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? color : color.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Session Count Chip

private struct SessionCountChip: View {
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(count)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? Color.purple : Color(.systemGray5))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FocusTimerSettings(viewModel: FocusTimerViewModel())
}
