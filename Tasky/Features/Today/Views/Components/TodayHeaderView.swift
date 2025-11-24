//
//  TodayHeaderView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Header view for Today screen showing title, date, and progress
struct TodayHeaderView: View {
    let formattedDate: String
    var completedCount: Int = 0
    var totalCount: Int = 0

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Title and date
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today")
                        .font(.largeTitle.weight(.bold))

                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            // Progress bar + count
            if totalCount > 0 {
                VStack(alignment: .leading, spacing: Constants.Spacing.xs) {
                    HStack {
                        Text("\(completedCount)/\(totalCount)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(progress * 100))%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    // Mini progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(.systemGray5))
                                .frame(height: 4)

                            // Progress
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * progress, height: 4)
                                .animation(reduceMotion ? .none : .spring(response: 0.4, dampingFraction: 0.8), value: progress)
                        }
                    }
                    .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: Constants.Spacing.lg) {
        TodayHeaderView(
            formattedDate: "Monday, Nov 24",
            completedCount: 3,
            totalCount: 7
        )

        TodayHeaderView(
            formattedDate: "Monday, Nov 24",
            completedCount: 0,
            totalCount: 5
        )

        TodayHeaderView(
            formattedDate: "Monday, Nov 24",
            completedCount: 0,
            totalCount: 0
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
