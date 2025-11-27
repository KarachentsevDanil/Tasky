//
//  TodayEmptyStateView.swift
//  Tasky
//
//  Created by Claude Code on 14.11.2025.
//

import SwiftUI

/// Enhanced empty state for Today view with contextual tips and animations
struct TodayEmptyStateView: View {

    // MARK: - Properties
    @AppStorage("tasksCreatedCount") private var tasksCreatedCount: Int = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    // MARK: - State
    @State private var isAnimating = false

    // MARK: - Computed Properties
    private var userType: UserType {
        if tasksCreatedCount == 0 {
            return .firstTime
        } else if tasksCreatedCount < 20 {
            return .returning
        } else {
            return .powerUser
        }
    }

    private var title: String {
        switch userType {
        case .firstTime:
            return "Welcome to Tasky!"
        case .returning:
            return "All caught up!"
        case .powerUser:
            return "You're on fire!"
        }
    }

    private var subtitle: String {
        switch userType {
        case .firstTime:
            return "Let's create your first task"
        case .returning:
            return "What's your next goal?"
        case .powerUser:
            return "Ready to tackle more?"
        }
    }

    private var tips: [Tip] {
        switch userType {
        case .firstTime:
            return [
                Tip(icon: "clock", text: "\"tomorrow at 3pm\" – dates & times", color: .orange),
                Tip(icon: "hourglass", text: "\"in 3 days for 30 min\" – relative dates", color: .green),
                Tip(icon: "number", text: "\"2-3pm #work\" – time ranges & lists", color: .purple),
                Tip(icon: "flag.fill", text: "\"urgent\" or \"!!\" – set priority", color: .red)
            ]
        case .returning:
            return [
                Tip(icon: "clock.badge.questionmark", text: "Try \"noon\", \"evening\", \"eod\"", color: .orange),
                Tip(icon: "mic.fill", text: "Use voice input for hands-free", color: .blue),
                Tip(icon: "sparkles", text: "AI understands natural language", color: .purple)
            ]
        case .powerUser:
            return [
                Tip(icon: "calendar", text: "Block time on calendar", color: .blue),
                Tip(icon: "timer", text: "Track focus time", color: .green),
                Tip(icon: "chart.line.uptrend.xyaxis", text: "Review your progress", color: .purple)
            ]
        }
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            // Animated Icon
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isAnimating ? 1.1 : 1.0)
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
            }
            .frame(width: 110, height: 110) // Fixed frame to prevent layout shifts
            .accessibilityHidden(true)

            // Title & Subtitle
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)

            // Tips Section
            VStack(alignment: .leading, spacing: 12) {
                Text("Quick tips:")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(tips) { tip in
                    tipRow(tip)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))

            // Call to Action
            HStack(spacing: 4) {
                Text("Tap")
                    .foregroundStyle(.tertiary)

                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)

                Text("above to create a task")
                    .foregroundStyle(.tertiary)
            }
            .font(.caption)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 40)
        .onAppear {
            startAnimation()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
    }

    // MARK: - Tip Row
    @ViewBuilder
    private func tipRow(_ tip: Tip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: tip.icon)
                .font(.callout)
                .foregroundStyle(tip.color)
                .frame(width: 24)

            Text(tip.text)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Animation
    private func startAnimation() {
        guard !reduceMotion else { return }
        isAnimating = true
    }
}

// MARK: - Supporting Types
extension TodayEmptyStateView {

    enum UserType {
        case firstTime
        case returning
        case powerUser
    }

    struct Tip: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let color: Color
    }
}

// MARK: - Preview
#Preview("First Time User") {
    TodayEmptyStateView()
        .background(Color(.systemGroupedBackground))
}

#Preview("Returning User") {
    @Previewable @AppStorage("tasksCreatedCount") var count = 10

    return TodayEmptyStateView()
        .background(Color(.systemGroupedBackground))
}

#Preview("Power User") {
    @Previewable @AppStorage("tasksCreatedCount") var count = 50

    return TodayEmptyStateView()
        .background(Color(.systemGroupedBackground))
}
