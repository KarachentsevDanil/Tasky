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
    @StateObject private var focusTimerViewModel = FocusTimerViewModel.shared
    @StateObject private var morningBriefService = MorningBriefService.shared
    @State private var selectedTab = 0
    @State private var showMorningBrief = false
    @State private var hasCheckedMorningBrief = false
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system

    // MARK: - Body
    var body: some View {
        mainTabView
            .fullScreenCover(isPresented: $focusTimerViewModel.isTimerSheetPresented) {
                if let task = focusTimerViewModel.currentTask {
                    FocusTimerSheet(viewModel: focusTimerViewModel, task: task)
                }
            }
            .fullScreenCover(isPresented: $showMorningBrief) {
                MorningBriefView {
                    showMorningBrief = false
                }
            }
            .preferredColorScheme(appearanceMode.colorScheme)
            .task {
                // Check if morning brief should be shown on first app open of day
                if !hasCheckedMorningBrief {
                    hasCheckedMorningBrief = true
                    checkMorningBrief()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenMorningBrief"))) { _ in
                showMorningBrief = true
            }
    }

    // MARK: - Morning Brief Check
    private func checkMorningBrief() {
        // Small delay to let the app settle before showing modal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if morningBriefService.shouldShowBrief() {
                showMorningBrief = true
            }
        }
    }

    // MARK: - Main Tab View

    private var mainTabView: some View {
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
            AIChatView(dataService: viewModel.dataService, taskListViewModel: viewModel)
                .tabItem {
                    Image(systemName: "sparkles")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("AI Assistant")
                }
                .tag(2)

            // Browse Tab - Lists, Progress, and Settings
            BrowseTabView(viewModel: viewModel)
                .tabItem {
                    Image(systemName: "folder.fill")
                        .symbolRenderingMode(Constants.IconRendering.multicolor)
                    Text("Browse")
                }
                .tag(3)
        }
    }

}

// MARK: - Preview
#Preview {
    ContentView()
}
