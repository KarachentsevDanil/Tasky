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
                    Image(systemName: "house.fill")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("Today")
                }
                .tag(0)

            // Calendar Tab - Unified view with Day/Week/Month modes
            CalendarMainView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "calendar")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("Calendar")
                }
                .tag(1)

            // AI Assistant Tab - Chat-based task creation
            AIChatView(dataService: viewModel.dataService)
                .tabItem {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("AI Coach")
                }
                .tag(2)

            // Progress Tab - Stats, streaks, and achievements
            ProgressTabView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("Progress")
                }
                .tag(3)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
