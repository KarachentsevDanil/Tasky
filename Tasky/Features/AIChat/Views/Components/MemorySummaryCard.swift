//
//  MemorySummaryCard.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

/// Inline card showing AI recall results in chat
/// Triggered when user asks "what do you know about me"
struct MemorySummaryCard: View {

    let items: [ContextDisplayItem]
    var onDismiss: (() -> Void)?
    var onManageMemory: (() -> Void)?

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Label("What I Remember", systemImage: "brain")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Spacer()

                if onDismiss != nil {
                    Button {
                        onDismiss?()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Dismiss memory card")
                    .accessibilityHint("Double tap to close this card")
                }
            }

            // Items grouped by category
            if items.isEmpty {
                emptyState
            } else {
                itemsList
            }

            // Footer
            if onManageMemory != nil {
                Divider()

                Button {
                    onManageMemory?()
                } label: {
                    HStack {
                        Image(systemName: "gear")
                        Text("Manage Memory")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                }
                .accessibilityLabel("Manage AI memory")
                .accessibilityHint("Double tap to view and manage stored memories")
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Empty State
    private var emptyState: some View {
        HStack {
            Image(systemName: "brain")
                .font(.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("No memories yet")
                    .font(.subheadline.weight(.medium))
                Text("I'll learn about you as we chat")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No memories yet. I'll learn about you as we chat.")
    }

    // MARK: - Items List
    private var itemsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(groupedItems.keys.sorted(by: { $0.rawValue < $1.rawValue }), id: \.self) { category in
                if let categoryItems = groupedItems[category] {
                    categorySection(category: category, items: categoryItems)
                }
            }
        }
    }

    private func categorySection(category: ContextCategory, items: [ContextDisplayItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Category header
            HStack(spacing: 4) {
                Image(systemName: category.iconName)
                    .font(.caption)
                Text(category.displayName)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(.secondary)

            // Items
            ForEach(items.prefix(3), id: \.key) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(confidenceColor(item.confidence))
                        .frame(width: 6, height: 6)
                        .padding(.top, 6)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.key.capitalized)
                            .font(.subheadline.weight(.medium))
                        Text(item.value)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(item.key.capitalized): \(item.value)")
                .accessibilityValue(confidenceAccessibilityLabel(item.confidence))
            }

            if items.count > 3 {
                Text("+ \(items.count - 3) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 14)
            }
        }
    }

    // MARK: - Helpers
    private var groupedItems: [ContextCategory: [ContextDisplayItem]] {
        Dictionary(grouping: items, by: { $0.category })
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        if confidence > 0.7 { return .green }
        if confidence > 0.4 { return .orange }
        return .gray
    }

    private func confidenceAccessibilityLabel(_ confidence: Float) -> String {
        if confidence > 0.7 { return "High confidence" }
        if confidence > 0.4 { return "Medium confidence" }
        return "Low confidence"
    }
}

// MARK: - Display Model
struct ContextDisplayItem: Identifiable {
    let id: UUID
    let category: ContextCategory
    let key: String
    let value: String
    let confidence: Float

    init(from entity: UserContextEntity) {
        self.id = entity.id
        self.category = entity.categoryEnum
        self.key = entity.key
        self.value = entity.value
        self.confidence = entity.effectiveConfidence
    }

    // Preview initializer
    init(id: UUID, category: ContextCategory, key: String, value: String, confidence: Float) {
        self.id = id
        self.category = category
        self.key = key
        self.value = value
        self.confidence = confidence
    }
}

// MARK: - Preview
#Preview("With Items") {
    MemorySummaryCard(
        items: [
            ContextDisplayItem(
                id: UUID(),
                category: .person,
                key: "john",
                value: "John is my manager at work",
                confidence: 0.85
            ),
            ContextDisplayItem(
                id: UUID(),
                category: .person,
                key: "sarah",
                value: "Sarah is a colleague",
                confidence: 0.65
            ),
            ContextDisplayItem(
                id: UUID(),
                category: .goal,
                key: "fitness",
                value: "Working on fitness goals",
                confidence: 0.72
            ),
            ContextDisplayItem(
                id: UUID(),
                category: .schedule,
                key: "standup",
                value: "Daily standup at 9am",
                confidence: 0.55
            )
        ],
        onDismiss: {},
        onManageMemory: {}
    )
    .padding()
}

#Preview("Empty") {
    MemorySummaryCard(
        items: [],
        onDismiss: {},
        onManageMemory: {}
    )
    .padding()
}
