//
//  ProductivityScoreView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Circular productivity score with status message
struct ProductivityScoreView: View {

    // MARK: - Properties
    let score: Int
    @State private var animateProgress = false

    // MARK: - Body
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("PRODUCTIVITY SCORE")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)
                .tracking(1.5)

            // Circular progress
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 12)
                    .frame(width: 140, height: 140)

                // Progress circle
                Circle()
                    .trim(from: 0, to: animateProgress ? CGFloat(score) / 100.0 : 0)
                    .stroke(
                        Color.blue.gradient,
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 140, height: 140)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 1.0, dampingFraction: 0.7).delay(0.2), value: animateProgress)

                // Score text
                VStack(spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(score)")
                            .font(.system(size: 48, weight: .bold))
                            .contentTransition(.numericText())

                        Text("/100")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Description
            Text("Based on completion rate and consistency")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            // Status message
            Text(statusMessage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        )
        .onAppear {
            animateProgress = true
        }
    }

    // MARK: - Status Message
    private var statusMessage: String {
        switch score {
        case 90...100:
            return "🎉 Excellent work!"
        case 75...89:
            return "💪 Great job!"
        case 60...74:
            return "👍 Good progress!"
        default:
            return "📈 Keep going!"
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        ProductivityScoreView(score: 85)
        ProductivityScoreView(score: 92)
        ProductivityScoreView(score: 58)
    }
    .padding()
}
