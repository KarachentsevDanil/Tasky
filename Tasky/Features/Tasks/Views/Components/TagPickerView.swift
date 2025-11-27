//
//  TagPickerView.swift
//  Tasky
//
//  Created by Claude on 27.11.2025.
//

import SwiftUI

/// View for selecting tags for a task
struct TagPickerView: View {

    @ObservedObject var viewModel: TaskListViewModel
    @Binding var selectedTags: Set<TagEntity>
    @State private var newTagName = ""
    @State private var showingNewTagSheet = false
    @FocusState private var isNewTagFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.md) {
            // Selected tags
            if !selectedTags.isEmpty {
                selectedTagsSection
            }

            // Available tags
            if !viewModel.tags.isEmpty {
                availableTagsSection
            }

            // Create new tag
            createTagButton
        }
    }

    // MARK: - Selected Tags Section

    private var selectedTagsSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Selected")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: Constants.Spacing.sm) {
                ForEach(Array(selectedTags)) { tag in
                    TagPillView(tag: tag, showRemoveButton: true) {
                        _ = withAnimation(.spring(response: 0.3)) {
                            selectedTags.remove(tag)
                        }
                        HapticManager.shared.lightImpact()
                    }
                }
            }
        }
    }

    // MARK: - Available Tags Section

    private var availableTagsSection: some View {
        VStack(alignment: .leading, spacing: Constants.Spacing.sm) {
            Text("Available")
                .font(.caption)
                .foregroundStyle(.secondary)

            FlowLayout(spacing: Constants.Spacing.sm) {
                ForEach(viewModel.tags.filter { !selectedTags.contains($0) }) { tag in
                    TagPillView(tag: tag)
                        .opacity(0.7)
                        .onTapGesture {
                            _ = withAnimation(.spring(response: 0.3)) {
                                selectedTags.insert(tag)
                            }
                            HapticManager.shared.lightImpact()
                        }
                }
            }
        }
    }

    // MARK: - Create Tag

    private var createTagButton: some View {
        Button {
            showingNewTagSheet = true
        } label: {
            HStack(spacing: Constants.Spacing.sm) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Create New Tag")
                    .font(.subheadline)
            }
            .foregroundStyle(.tint)
        }
        .buttonStyle(.plain)
        .padding(.top, Constants.Spacing.sm)
        .sheet(isPresented: $showingNewTagSheet) {
            CreateTagSheet(viewModel: viewModel) { newTag in
                selectedTags.insert(newTag)
            }
            .presentationDetents([.height(280)])
        }
    }
}

// MARK: - Create Tag Sheet

struct CreateTagSheet: View {

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TaskListViewModel
    var onTagCreated: ((TagEntity) -> Void)?

    @State private var tagName = ""
    @State private var selectedColorHex = Constants.Colors.defaultListColor
    @FocusState private var isNameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $tagName)
                        .focused($isNameFocused)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: Constants.Spacing.md) {
                        ForEach(Constants.Colors.listColors, id: \.hex) { colorOption in
                            Circle()
                                .fill(colorOption.color)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    if selectedColorHex == colorOption.hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .onTapGesture {
                                    selectedColorHex = colorOption.hex
                                    HapticManager.shared.selectionChanged()
                                }
                        }
                    }
                    .padding(.vertical, Constants.Spacing.sm)
                }

                // Preview
                if !tagName.isEmpty {
                    Section("Preview") {
                        HStack {
                            Spacer()
                            previewPill
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTag()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
    }

    private var previewPill: some View {
        Text(tagName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .padding(.horizontal, Constants.Spacing.sm)
            .padding(.vertical, Constants.Spacing.xs)
            .background(Color(hex: selectedColorHex) ?? .blue)
            .clipShape(Capsule())
    }

    private func createTag() {
        let trimmedName = tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        Task {
            await viewModel.createTag(name: trimmedName, colorHex: selectedColorHex)
            // Find the newly created tag
            if let newTag = viewModel.tags.first(where: { $0.name == trimmedName }) {
                onTagCreated?(newTag)
            }
            dismiss()
        }
    }
}

// MARK: - Flow Layout

/// A layout that arranges views in a flowing manner
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? 0,
            subviews: subviews,
            spacing: spacing
        )
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }

            height = currentY + lineHeight
        }
    }
}

// MARK: - Preview
#Preview("Tag Picker") {
    struct PreviewWrapper: View {
        @StateObject var viewModel = TaskListViewModel(
            dataService: DataService(persistenceController: .preview)
        )
        @State var selectedTags: Set<TagEntity> = []

        var body: some View {
            TagPickerView(viewModel: viewModel, selectedTags: $selectedTags)
                .padding()
        }
    }

    return PreviewWrapper()
}

#Preview("Create Tag Sheet") {
    CreateTagSheet(
        viewModel: TaskListViewModel(dataService: DataService(persistenceController: .preview))
    )
}
