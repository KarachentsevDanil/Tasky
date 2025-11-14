//
//  ActionableInsightCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Single actionable insight card with tap action
struct ActionableInsightCard: View {

    // MARK: - Properties
    let icon: String
    let text: String
    let onTap: () -> Void

    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Icon
                Text(icon)
                    .font(.title2)

                // Text
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                // Arrow
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
        }
        .buttonStyle(.plain)
    }
}

/// Container for multiple actionable insights
struct ActionableInsightsSection: View {

    // MARK: - Properties
    let insights: [String]
    let onInsightTap: (String) -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Text("✨")
                    .font(.title2)

                Text("Insights")
                    .font(.title3.weight(.bold))

                Spacer()
            }

            // Insights list (max 3)
            VStack(spacing: 12) {
                ForEach(Array(insights.prefix(3).enumerated()), id: \.offset) { index, insight in
                    ActionableInsightCard(
                        icon: insightIcon(for: index),
                        text: insight,
                        onTap: { onInsightTap(insight) }
                    )
                }
            }
        }
    }

    // MARK: - Icon Selection
    private func insightIcon(for index: Int) -> String {
        let icons = ["💡", "🎯", "🚀"]
        return icons[index % icons.count]
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ActionableInsightsSection(
            insights: [
                "You're most productive on Fridays",
                "Try tackling high-priority tasks in the evening (after 6 PM)",
                "You're on track! 19 tasks completed overall"
            ],
            onInsightTap: { insight in
                print("Tapped: \(insight)")
            }
        )
    }
    .padding()
}
