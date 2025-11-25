//
//  SuggestionChipsView.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// View displaying data-driven suggestion chips for AI chat
struct SuggestionChipsView: View {

    // MARK: - Properties
    let suggestions: [SuggestionEngine.Suggestion]
    let onSuggestionTapped: (SuggestionEngine.Suggestion) -> Void

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Suggestions")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 4)

            FlowLayout(spacing: Constants.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    SuggestionChip(suggestion: suggestion) {
                        onSuggestionTapped(suggestion)
                    }
                }
            }
        }
        .padding(.horizontal, Constants.Spacing.lg)
        .padding(.vertical, Constants.Spacing.md)
    }
}

// MARK: - Suggestion Chip
struct SuggestionChip: View {

    let suggestion: SuggestionEngine.Suggestion
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 4) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(suggestion.text)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(suggestion.text)
        .accessibilityHint("Double tap to use this suggestion")
    }
}

// MARK: - Flow Layout for Wrapping Chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: currentX, y: currentY), size: size))
            lineHeight = max(lineHeight, size.height)
            maxX = max(maxX, currentX + size.width)
            currentX += size.width + spacing
        }

        return (CGSize(width: maxX, height: currentY + lineHeight), frames)
    }
}

// MARK: - Preview
#Preview {
    SuggestionChipsView(
        suggestions: [
            SuggestionEngine.Suggestion(
                text: "What's due today?",
                prompt: "What's due today?",
                icon: "calendar",
                type: .query
            ),
            SuggestionEngine.Suggestion(
                text: "Process inbox (5)",
                prompt: "What's in my inbox?",
                icon: "tray.full",
                type: .query
            ),
            SuggestionEngine.Suggestion(
                text: "Add to Work",
                prompt: "Add task to Work list: ",
                icon: "folder",
                type: .action
            ),
            SuggestionEngine.Suggestion(
                text: "Plan tomorrow",
                prompt: "What's due tomorrow?",
                icon: "moon.stars",
                type: .query
            )
        ],
        onSuggestionTapped: { suggestion in
            print("Tapped: \(suggestion.text)")
        }
    )
    .background(Color(.systemGroupedBackground))
}
