//
//  SuggestionChipsView.swift
//  Tasky
//
//  Created by Claude Code on 25.11.2025.
//

import SwiftUI

/// Horizontal scrolling suggestion chips for AI chat
/// Follows iOS HIG patterns (like Maps, Messages app suggestions)
struct SuggestionChipsView: View {

    // MARK: - Properties
    let suggestions: [SuggestionEngine.Suggestion]
    let onSuggestionTapped: (SuggestionEngine.Suggestion) -> Void

    // MARK: - Body
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.Spacing.sm) {
                ForEach(suggestions) { suggestion in
                    SuggestionChip(suggestion: suggestion) {
                        onSuggestionTapped(suggestion)
                    }
                }
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .padding(.vertical, Constants.Spacing.sm)
        }
        .scrollClipDisabled()
        .mask(
            // Fade edges to hint at scrollability
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [.clear, .white],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 8)

                Color.white

                LinearGradient(
                    colors: [.white, .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: 8)
            }
        )
    }
}

// MARK: - Suggestion Chip
struct SuggestionChip: View {

    let suggestion: SuggestionEngine.Suggestion
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            action()
        }) {
            HStack(spacing: 6) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(iconColor)

                Text(suggestion.text)
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color(.systemGray6))
                    .overlay(
                        Capsule()
                            .strokeBorder(Color(.systemGray4).opacity(0.5), lineWidth: 0.5)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(suggestion.text)
        .accessibilityHint("Double tap to use this suggestion")
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = true
                    }
                }
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = false
                    }
                }
        )
    }

    private var iconColor: Color {
        switch suggestion.type {
        case .query:
            return .blue
        case .action:
            return .orange
        case .contextual:
            return .purple
        }
    }
}

// MARK: - Preview
#Preview {
    VStack {
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
                    type: .contextual
                ),
                SuggestionEngine.Suggestion(
                    text: "High priority",
                    prompt: "Show high priority tasks",
                    icon: "flag.fill",
                    type: .query
                )
            ],
            onSuggestionTapped: { suggestion in
                print("Tapped: \(suggestion.text)")
            }
        )

        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}
