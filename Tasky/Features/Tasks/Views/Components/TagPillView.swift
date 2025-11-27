//
//  TagPillView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI
internal import CoreData

/// Small colored pill displaying a tag
struct TagPillView: View {

    let tag: TagEntity
    var showRemoveButton: Bool = false
    var onRemove: (() -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            Text(tag.name)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if showRemoveButton {
                Button {
                    onRemove?()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, Constants.Spacing.sm)
        .padding(.vertical, Constants.Spacing.xs)
        .background(tag.color)
        .clipShape(Capsule())
    }
}

/// Horizontal row of tag pills with overflow indicator
struct TagPillsRow: View {

    let tags: [TagEntity]
    var maxVisible: Int = 3
    var onTagTap: ((TagEntity) -> Void)?

    var body: some View {
        HStack(spacing: Constants.Spacing.xs) {
            ForEach(Array(tags.prefix(maxVisible))) { tag in
                TagPillView(tag: tag)
                    .onTapGesture {
                        onTagTap?(tag)
                    }
            }

            if tags.count > maxVisible {
                Text("+\(tags.count - maxVisible)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, Constants.Spacing.xs)
            }
        }
    }
}

// MARK: - Preview
#Preview("Single Tag") {
    let context = PersistenceController.preview.viewContext
    let tag = TagEntity(context: context)
    tag.id = UUID()
    tag.name = "Work"
    tag.colorHex = "007AFF"
    tag.createdAt = Date()

    return TagPillView(tag: tag)
        .padding()
}

#Preview("Tag with Remove") {
    let context = PersistenceController.preview.viewContext
    let tag = TagEntity(context: context)
    tag.id = UUID()
    tag.name = "Personal"
    tag.colorHex = "34C759"
    tag.createdAt = Date()

    return TagPillView(tag: tag, showRemoveButton: true) {
        print("Remove tapped")
    }
    .padding()
}

#Preview("Multiple Tags") {
    let context = PersistenceController.preview.viewContext

    let tags = ["Work", "Urgent", "Meeting", "Project"].enumerated().map { index, name -> TagEntity in
        let tag = TagEntity(context: context)
        tag.id = UUID()
        tag.name = name
        tag.colorHex = Constants.Colors.listColors[index % Constants.Colors.listColors.count].hex
        tag.createdAt = Date()
        return tag
    }

    return TagPillsRow(tags: tags)
        .padding()
}
