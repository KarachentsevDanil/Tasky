//
//  TodayHeaderView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Header view for Today screen showing title and current date
struct TodayHeaderView: View {
    let formattedDate: String

    var body: some View {
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
        .padding(.horizontal, 8)
    }
}

// MARK: - Preview
#Preview {
    TodayHeaderView(formattedDate: AppDateFormatters.dayMonthFormatter.string(from: Date()))
        .padding()
        .background(Color(.systemGroupedBackground))
}
