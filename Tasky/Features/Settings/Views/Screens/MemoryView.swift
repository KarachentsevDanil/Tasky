//
//  MemoryView.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import SwiftUI

// MARK: - Loading State
private enum MemoryLoadingState {
    case loading
    case loaded(items: [UserContextEntity], insights: [PatternInsight])
    case error(Error)

    var items: [UserContextEntity] {
        if case .loaded(let items, _) = self { return items }
        return []
    }

    var insights: [PatternInsight] {
        if case .loaded(_, let insights) = self { return insights }
        return []
    }
}

/// Full view for managing AI memory and context
/// Shows all stored context items organized by category
struct MemoryView: View {

    // MARK: - State
    @State private var loadingState: MemoryLoadingState = .loading
    @State private var selectedCategory: ContextCategory?
    @State private var showingClearConfirmation = false
    @State private var categoryToClear: ContextCategory?
    @State private var showingClearAllConfirmation = false

    // MARK: - Environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Services
    private let contextService = ContextService.shared
    private let patternService = PatternTrackingService.shared

    // MARK: - Computed Properties
    private var contextItems: [UserContextEntity] { loadingState.items }
    private var insights: [PatternInsight] { loadingState.insights }

    // MARK: - Body
    var body: some View {
        Group {
            switch loadingState {
            case .loading:
                ProgressView("Loading memory...")
                    .accessibilityLabel("Loading AI memory")
            case .loaded(let items, _) where items.isEmpty:
                emptyStateView
            case .loaded:
                contentView
            case .error(let error):
                errorStateView(error)
            }
        }
        .navigationTitle("AI Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if !contextItems.isEmpty {
                    Menu {
                        Button(role: .destructive) {
                            showingClearAllConfirmation = true
                        } label: {
                            Label("Clear All Memory", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear All Memory?",
            isPresented: $showingClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All", role: .destructive) {
                clearAllContext()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all stored context. This action cannot be undone.")
        }
        .confirmationDialog(
            "Clear \(categoryToClear?.displayName ?? "Category")?",
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear", role: .destructive) {
                if let category = categoryToClear {
                    clearCategory(category)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all items in this category.")
        }
        .task {
            await loadData()
        }
        .refreshable {
            await loadData()
        }
    }

    // MARK: - Content View
    private var contentView: some View {
        List {
            // Insights Section
            if !insights.isEmpty {
                Section {
                    ForEach(insights.prefix(3), id: \.title) { insight in
                        InsightRow(insight: insight)
                    }
                } header: {
                    Label("Insights", systemImage: "lightbulb")
                } footer: {
                    Text("Based on your patterns and behavior")
                }
            }

            // Memory Stats
            Section {
                HStack {
                    Label("Total Items", systemImage: "brain")
                    Spacer()
                    Text("\(contextItems.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Label("Categories", systemImage: "folder")
                    Spacer()
                    Text("\(uniqueCategories.count)")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Overview")
            }

            // Category Sections
            ForEach(uniqueCategories, id: \.self) { category in
                categorySection(category)
            }
        }
    }

    // MARK: - Category Section
    private func categorySection(_ category: ContextCategory) -> some View {
        Section {
            ForEach(itemsForCategory(category), id: \.id) { item in
                ContextItemRow(item: item)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        } header: {
            HStack {
                Label(category.displayName, systemImage: category.iconName)
                Spacer()
                Text("\(itemsForCategory(category).count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if itemsForCategory(category).count > 1 {
                Button("Clear \(category.displayName)") {
                    categoryToClear = category
                    showingClearConfirmation = true
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Memory Yet", systemImage: "brain")
        } description: {
            Text("As you use Tasky, I'll learn about you and remember important details to provide personalized assistance.")
        } actions: {
            Text("Try saying \"Remember that John is my manager\"")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No AI memory yet. I'll learn about you as we chat. Try saying Remember that John is my manager.")
    }

    // MARK: - Error State
    private func errorStateView(_ error: Error) -> some View {
        ContentUnavailableView {
            Label("Unable to Load", systemImage: "exclamationmark.triangle")
        } description: {
            Text("Something went wrong loading your AI memory.")
        } actions: {
            Button("Try Again") {
                Task { await loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Unable to load AI memory. Double tap Try Again to retry.")
    }

    // MARK: - Helpers
    private var uniqueCategories: [ContextCategory] {
        let categories = Set(contextItems.map { $0.categoryEnum })
        return ContextCategory.allCases.filter { categories.contains($0) }
    }

    private func itemsForCategory(_ category: ContextCategory) -> [UserContextEntity] {
        contextItems
            .filter { $0.categoryEnum == category }
            .sorted { $0.effectiveConfidence > $1.effectiveConfidence }
    }

    // MARK: - Data Loading
    @MainActor
    private func loadData() async {
        loadingState = .loading

        do {
            let items = try contextService.fetchAllContext()
            let generatedInsights = try patternService.generateInsights()
            withAnimation(reduceMotion ? .none : .default) {
                loadingState = .loaded(items: items, insights: generatedInsights)
            }
        } catch {
            print("Failed to load context: \(error)")
            loadingState = .error(error)
        }
    }

    // MARK: - Actions
    @MainActor
    private func deleteItem(_ item: UserContextEntity) {
        do {
            try contextService.deleteContext(item)
            // Reload to refresh the state
            Task { await loadData() }
            HapticManager.shared.success()
        } catch {
            print("Failed to delete item: \(error)")
            HapticManager.shared.error()
        }
    }

    @MainActor
    private func clearCategory(_ category: ContextCategory) {
        do {
            _ = try contextService.deleteAllContext(category: category)
            // Reload to refresh the state
            Task { await loadData() }
            HapticManager.shared.success()
        } catch {
            print("Failed to clear category: \(error)")
            HapticManager.shared.error()
        }
    }

    @MainActor
    private func clearAllContext() {
        do {
            _ = try contextService.deleteAllContext()
            withAnimation(reduceMotion ? .none : .default) {
                loadingState = .loaded(items: [], insights: [])
            }
            HapticManager.shared.success()
        } catch {
            print("Failed to clear all context: \(error)")
            HapticManager.shared.error()
        }
    }
}

// MARK: - Context Item Row
struct ContextItemRow: View {
    let item: UserContextEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.key.capitalized)
                    .font(.headline)

                Spacer()

                confidenceBadge
            }

            Text(item.value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack {
                sourceLabel
                Spacer()
                Text(item.updatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.key.capitalized): \(item.value)")
        .accessibilityValue("\(confidenceAccessibilityLabel), \(item.sourceEnum.displayName)")
        .accessibilityHint("Swipe left to delete")
    }

    private var confidenceAccessibilityLabel: String {
        let confidence = item.effectiveConfidence
        if confidence > 0.7 { return "High confidence" }
        if confidence > 0.4 { return "Medium confidence" }
        return "Low confidence"
    }

    private var confidenceBadge: some View {
        let confidence = item.effectiveConfidence
        let color: Color = confidence > 0.7 ? .green : confidence > 0.4 ? .orange : .gray

        return Text(item.formattedConfidence)
            .font(.caption2.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    private var sourceLabel: some View {
        let source = item.sourceEnum

        return HStack(spacing: 4) {
            Image(systemName: sourceIcon)
                .font(.caption2)
            Text(source.displayName)
                .font(.caption2)
        }
        .foregroundStyle(.tertiary)
    }

    private var sourceIcon: String {
        switch item.sourceEnum {
        case .explicit: return "quote.bubble"
        case .extracted: return "doc.text.magnifyingglass"
        case .inferred: return "sparkles"
        }
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let insight: PatternInsight

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: insightIcon)
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
                Text(insight.title)
                    .font(.subheadline.weight(.medium))
            }

            Text(insight.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Insight: \(insight.title). \(insight.description)")
    }

    private var insightIcon: String {
        switch insight.type {
        case .productivityPeak: return "sun.max.fill"
        case .activeDays: return "calendar"
        case .goalFocus: return "target"
        case .frequentCollaborator: return "person.2.fill"
        case .listUsage: return "folder.fill"
        }
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        MemoryView()
    }
}
