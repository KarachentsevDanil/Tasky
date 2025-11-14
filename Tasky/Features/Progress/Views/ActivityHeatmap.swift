//
//  ActivityHeatmap.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// GitHub-style contribution heatmap for task completion activity
struct ActivityHeatmap: View {

    // MARK: - Properties
    let data: [Int]
    let columns: Int = 7

    // MARK: - Constants
    private let squareSize: CGFloat = 30
    private let spacing: CGFloat = 4

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Activity Pattern")
                    .font(.system(size: 17, weight: .bold))

                Text("Your productivity heatmap")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            // Heatmap grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(Array(data.enumerated()), id: \.offset) { index, count in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(colorForCount(count))
                        .frame(width: squareSize, height: squareSize)
                }
            }

            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 12, height: 12)
                }

                Text("More")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
    }

    // MARK: - Color Mapping
    private func colorForCount(_ count: Int) -> Color {
        switch count {
        case 0:
            return Color(hex: "F2F2F7") ?? Color(.systemGray6)
        case 1...2:
            return Color(hex: "C6E9D5") ?? Color.green.opacity(0.3)
        case 3...5:
            return Color(hex: "7DD3A7") ?? Color.green.opacity(0.5)
        case 6...8:
            return Color(hex: "4CBB8B") ?? Color.green.opacity(0.7)
        default:
            return Color(hex: "34C759") ?? Color.green
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0:
            return Color(hex: "F2F2F7") ?? Color(.systemGray6)
        case 1:
            return Color(hex: "C6E9D5") ?? Color.green.opacity(0.3)
        case 2:
            return Color(hex: "7DD3A7") ?? Color.green.opacity(0.5)
        case 3:
            return Color(hex: "4CBB8B") ?? Color.green.opacity(0.7)
        default:
            return Color(hex: "34C759") ?? Color.green
        }
    }
}

// MARK: - Preview
#Preview {
    ActivityHeatmap(
        data: Array(repeating: [3, 5, 2, 6, 4, 8, 1, 0, 3, 7, 5, 9, 4, 2, 6, 4, 7, 5, 3, 8, 6, 2, 4, 5, 7, 3, 2, 0], count: 1).flatMap { $0 }
    )
    .padding()
}
