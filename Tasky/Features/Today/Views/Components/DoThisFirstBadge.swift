//
//  DoThisFirstBadge.swift
//  Tasky
//
//  Created by Claude Code on 24.11.2025.
//

import SwiftUI

/// Badge displayed on the highest priority task to guide user focus
struct DoThisFirstBadge: View {

    var body: some View {
        HStack(spacing: Constants.Spacing.xxs) {
            Image(systemName: "sparkles")
                .font(.caption2.weight(.semibold))

            Text("Do this first")
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Constants.Spacing.sm)
        .padding(.vertical, Constants.Spacing.xxs)
        .background(
            LinearGradient(
                colors: [.blue, .purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: Constants.Spacing.md) {
        DoThisFirstBadge()

        // In context preview
        VStack(alignment: .leading, spacing: Constants.Spacing.xs) {
            DoThisFirstBadge()

            Text("Finish the quarterly report")
                .font(.body.weight(.medium))

            Text("Due in 2 hours")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .padding()
    }
}
