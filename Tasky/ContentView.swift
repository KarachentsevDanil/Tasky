//
//  ContentView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

/// Main content view with enhanced tab navigation
struct ContentView: View {

    // MARK: - State
    @StateObject private var viewModel = TaskListViewModel()
    @State private var selectedTab = 0

    // MARK: - Body
    var body: some View {
        TabView(selection: $selectedTab) {
            // Today Tab - Enhanced with completion ring and celebrations
            TodayView(viewModel: viewModel)
                .tabItem {
                    Label("Today", systemImage: "house.fill")
                }
                .tag(0)

            // Calendar Tab - Unified view with Day/Week/Month modes
            UpcomingView(viewModel: viewModel)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
                .tag(1)

            // AI Assistant Tab - Chat-based task creation
            AIChatView(dataService: viewModel.dataService)
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(2)

            // Progress Tab - Stats, streaks, and achievements
            ProgressTabView(viewModel: viewModel)
                .tabItem {
                    Label("Progress", systemImage: "chart.bar.fill")
                }
                .tag(3)
        }
        .tint(.accentColor)
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
