//
//  PersonalBestCard.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Personal best achievement card
struct PersonalBestCard: View {

    // MARK: - Properties
    let personalBest: PersonalBest?

    // MARK: - Body
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Text("🏅")
                .font(.system(size: 40))

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text("Personal Best")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                if let best = personalBest {
                    Text("Your best week: \(best.value) tasks in \(best.period)")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                } else {
                    Text("Complete more tasks to set a record!")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        PersonalBestCard(
            personalBest: PersonalBest(
                metric: "tasks",
                value: 23,
                period: "Oct 2024"
            )
        )

        PersonalBestCard(personalBest: nil)
    }
    .padding()
}
