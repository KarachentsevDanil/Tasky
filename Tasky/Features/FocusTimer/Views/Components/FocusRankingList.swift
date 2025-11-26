//
//  FocusRankingList.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI

/// List showing tasks ranked by focus time
struct FocusRankingList: View {

    // MARK: - Properties
    let rankings: [TaskFocusRanking]
    let maxItems: Int

    init(rankings: [TaskFocusRanking], maxItems: Int = 10) {
        self.rankings = rankings
        self.maxItems = maxItems
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if rankings.isEmpty {
                emptyState
            } else {
                ForEach(Array(rankings.prefix(maxItems).enumerated()), id: \.element.id) { index, ranking in
                    RankingRow(rank: index + 1, ranking: ranking, maxSeconds: rankings.first?.totalSeconds ?? 1)

                    if index < min(rankings.count, maxItems) - 1 {
                        Divider()
                            .padding(.leading, 44)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)

                Text("No focus sessions yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 24)
            Spacer()
        }
    }
}

// MARK: - Ranking Row

private struct RankingRow: View {
    let rank: Int
    let ranking: TaskFocusRanking
    let maxSeconds: Int

    var body: some View {
        HStack(spacing: 12) {
            // Rank badge
            rankBadge

            // Task info
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.taskTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                if let listName = ranking.taskListName {
                    Text(listName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Duration and progress
            VStack(alignment: .trailing, spacing: 4) {
                Text(ranking.formattedDuration)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.orange)

                Text("\(ranking.sessionCount) sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var rankBadge: some View {
        ZStack {
            Circle()
                .fill(rankColor.opacity(0.15))
                .frame(width: 32, height: 32)

            if rank <= 3 {
                Image(systemName: "medal.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rankColor)
            } else {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(rankColor)
            }
        }
    }

    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleRankings = [
        TaskFocusRanking(id: UUID(), taskTitle: "Write iOS Documentation", taskListName: "Work", totalSeconds: 12600, sessionCount: 6),
        TaskFocusRanking(id: UUID(), taskTitle: "Study Swift Concurrency", taskListName: "Learning", totalSeconds: 9000, sessionCount: 4),
        TaskFocusRanking(id: UUID(), taskTitle: "Code Review", taskListName: "Work", totalSeconds: 5400, sessionCount: 3),
        TaskFocusRanking(id: UUID(), taskTitle: "Design System Updates", taskListName: nil, totalSeconds: 3600, sessionCount: 2),
        TaskFocusRanking(id: UUID(), taskTitle: "Bug Fixes", taskListName: "Work", totalSeconds: 1800, sessionCount: 1)
    ]

    return ScrollView {
        FocusRankingList(rankings: sampleRankings)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}

#Preview("Empty State") {
    FocusRankingList(rankings: [])
        .padding()
        .background(Color(.systemGroupedBackground))
}
