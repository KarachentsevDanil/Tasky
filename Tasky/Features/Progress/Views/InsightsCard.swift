//
//  InsightsCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// AI-generated insights card with actionable recommendations
struct InsightsCard: View {

    // MARK: - Properties
    let insights: [String]

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Text("✨")
                    .font(.system(size: 24))

                Text("Insights")
                    .font(.system(size: 17, weight: .bold))

                Spacer()
            }

            // Insights list
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(insights.enumerated()), id: \.offset) { index, insight in
                    insightRow(insight, icon: insightIcon(for: index))
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.1),
                            Color.purple.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: - Insight Row
    private func insightRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(icon)
                .font(.system(size: 20))

            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Icon Selection
    private func insightIcon(for index: Int) -> String {
        let icons = ["💡", "🎯", "🚀", "⚡", "🌟"]
        return icons[index % icons.count]
    }
}

// MARK: - Preview
#Preview {
    InsightsCard(
        insights: [
            "You're most productive on Tuesday afternoons",
            "Try scheduling deep work between 9-11 AM",
            "You're on track to beat your monthly record!"
        ]
    )
    .padding()
}
