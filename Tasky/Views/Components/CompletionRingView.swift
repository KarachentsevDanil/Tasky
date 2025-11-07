//
//  CompletionRingView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Circular progress ring showing task completion for the day
struct CompletionRingView: View {

    // MARK: - Properties
    let completed: Int
    let total: Int
    let lineWidth: CGFloat

    @State private var animatedProgress: Double = 0

    // MARK: - Initialization
    init(completed: Int, total: Int, lineWidth: CGFloat = 12) {
        self.completed = completed
        self.total = total
        self.lineWidth = lineWidth
    }

    // MARK: - Computed Properties
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private var percentageText: String {
        guard total > 0 else { return "0%" }
        let percentage = Int(progress * 100)
        return "\(percentage)%"
    }

    private var ringColor: Color {
        switch progress {
        case 0..<0.5:
            return .orange
        case 0.5..<0.8:
            return .blue
        case 0.8..<1.0:
            return .green
        default:
            return .purple
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringColor.gradient,
                    style: StrokeStyle(
                        lineWidth: lineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedProgress)

            // Center content - simplified
            Text("\(completed) / \(total)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
        }
        .onAppear {
            // Animate progress on appear
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            // Animate progress changes
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Compact Variant
struct CompactCompletionRingView: View {

    // MARK: - Properties
    let completed: Int
    let total: Int
    let size: CGFloat

    @State private var animatedProgress: Double = 0

    // MARK: - Initialization
    init(completed: Int, total: Int, size: CGFloat = 40) {
        self.completed = completed
        self.total = total
        self.size = size
    }

    // MARK: - Computed Properties
    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    private var ringColor: Color {
        switch progress {
        case 0..<0.5:
            return .orange
        case 0.5..<0.8:
            return .blue
        case 0.8..<1.0:
            return .green
        default:
            return .purple
        }
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 4)

            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    ringColor.gradient,
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            // Center text
            Text("\(completed)")
                .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
                .foregroundStyle(ringColor)
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Preview
#Preview("Standard Ring") {
    VStack(spacing: 40) {
        CompletionRingView(completed: 0, total: 10)
            .frame(width: 120, height: 120)

        CompletionRingView(completed: 5, total: 10)
            .frame(width: 120, height: 120)

        CompletionRingView(completed: 8, total: 10)
            .frame(width: 120, height: 120)

        CompletionRingView(completed: 10, total: 10)
            .frame(width: 120, height: 120)
    }
    .padding()
}

#Preview("Compact Ring") {
    HStack(spacing: 20) {
        CompactCompletionRingView(completed: 0, total: 10)
        CompactCompletionRingView(completed: 5, total: 10)
        CompactCompletionRingView(completed: 8, total: 10)
        CompactCompletionRingView(completed: 10, total: 10)
    }
    .padding()
}
