//
//  ExpandableOptionRow.swift
//  Tasky
//
//  Created by Claude Code on 26.11.2025.
//

import SwiftUI

/// Things 3 style expandable row with inline content expansion
struct ExpandableOptionRow<ExpandedContent: View>: View {

    // MARK: - Properties
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    @Binding var isExpanded: Bool
    var canClear: Bool = false
    var onClear: (() -> Void)?
    @ViewBuilder let expandedContent: () -> ExpandedContent

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Animation
    private var animation: SwiftUI.Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button {
                withAnimation(animation) {
                    isExpanded.toggle()
                }
                HapticManager.shared.selectionChanged()
            } label: {
                HStack(spacing: Constants.Spacing.md) {
                    // Icon
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(value != nil ? iconColor : .secondary)
                        .frame(width: 24)

                    // Label or Value
                    Text(value ?? label)
                        .font(.body)
                        .foregroundStyle(value != nil ? .primary : .secondary)

                    Spacer()

                    // Clear button or Chevron
                    if canClear && value != nil && isExpanded {
                        Button {
                            onClear?()
                            HapticManager.shared.lightImpact()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    }
                }
                .padding(.horizontal, Constants.Spacing.lg)
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Expanded content
            if isExpanded {
                expandedContent()
                    .padding(.horizontal, Constants.Spacing.lg)
                    .padding(.bottom, Constants.Spacing.md)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }
}

// MARK: - Simple Row (No Expansion)
struct SimpleOptionRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Constants.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(value != nil ? iconColor : .secondary)
                    .frame(width: 24)

                Text(value ?? label)
                    .font(.body)
                    .foregroundStyle(value != nil ? .primary : .secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, Constants.Spacing.lg)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: Constants.Layout.cornerRadiusMedium))
    }
}

// MARK: - Preview
#Preview("Collapsed") {
    VStack(spacing: Constants.Spacing.sm) {
        ExpandableOptionRow(
            icon: "calendar",
            iconColor: .blue,
            label: "No date",
            value: "Today",
            isExpanded: .constant(false)
        ) {
            Text("Date picker content")
        }

        ExpandableOptionRow(
            icon: "clock",
            iconColor: .orange,
            label: "Add time",
            value: nil,
            isExpanded: .constant(false)
        ) {
            Text("Time picker content")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Expanded") {
    ExpandableOptionRow(
        icon: "calendar",
        iconColor: .blue,
        label: "No date",
        value: "Today",
        isExpanded: .constant(true),
        canClear: true,
        onClear: {}
    ) {
        HStack(spacing: 8) {
            ForEach(["Today", "Tomorrow", "+3"], id: \.self) { option in
                Text(option)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
