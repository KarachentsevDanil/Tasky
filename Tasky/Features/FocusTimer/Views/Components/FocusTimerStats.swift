//
//  FocusTimerStats.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI
internal import CoreData

/// Statistics cards showing total focus time and completed sessions
struct FocusTimerStats: View {
    let task: TaskEntity

    var body: some View {
        VStack(spacing: 20) {
            // Subtle divider
            Capsule()
                .fill(Color(.systemGray5))
                .frame(width: 60, height: 4)
                .padding(.top, 8)

            HStack(spacing: 24) {
                // Total Focus Time Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.blue.opacity(0.15),
                                        Color.blue.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                            )

                        Image(systemName: "clock.fill")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 4) {
                        Text(task.formattedFocusTime)
                            .font(.title2.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        Text("Total Focus")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                )

                // Sessions Completed Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.15),
                                        Color.green.opacity(0.08)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(Color.green.opacity(0.2), lineWidth: 1)
                            )

                        Image(systemName: "target")
                            .font(.title2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .green.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }

                    VStack(spacing: 4) {
                        if let sessions = task.focusSessions as? Set<FocusSessionEntity> {
                            Text("\(sessions.filter { $0.completed }.count)")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("0")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                        }

                        Text("Sessions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color(.secondarySystemBackground))
                        .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
    }
}

// MARK: - Preview
#Preview {
    let context = PersistenceController.preview.viewContext
    let task = TaskEntity(context: context)
    task.id = UUID()
    task.title = "Write documentation"
    task.focusTimeSeconds = 3600 // 1 hour

    return FocusTimerStats(task: task)
        .padding()
        .background(Color(.systemBackground))
}

#Preview("With Sessions") {
    FocusTimerStats(task: {
        let context = PersistenceController.preview.viewContext
        let task = TaskEntity(context: context)
        task.id = UUID()
        task.title = "Write documentation"
        task.focusTimeSeconds = 7200 // 2 hours

        // Create mock sessions
        let session1 = FocusSessionEntity(context: context)
        session1.id = UUID()
        session1.completed = true
        session1.duration = 1500

        let session2 = FocusSessionEntity(context: context)
        session2.id = UUID()
        session2.completed = true
        session2.duration = 1500

        task.addToFocusSessions(session1)
        task.addToFocusSessions(session2)

        return task
    }())
    .padding()
    .background(Color(.systemBackground))
}
