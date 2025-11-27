//
//  TaskyApp.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

@main
struct TaskyApp: App {

    // MARK: - Properties
    let persistenceController = PersistenceController.shared
    let backgroundTaskManager = BackgroundTaskManager.shared

    // MARK: - Environment
    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization
    init() {
        // Register background tasks on app launch
        backgroundTaskManager.registerBackgroundTasks()

        // Initialize context extraction service (starts listening for notifications)
        _ = ContextExtractionService.shared

        // Initialize morning brief service (ensures defaults are set)
        _ = MorningBriefService.shared
    }

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .task {
                    // Request notification permissions on app launch
                    try? await NotificationManager.shared.requestAuthorization()

                    // Schedule morning brief notification if enabled
                    await MorningBriefService.shared.scheduleMorningBriefNotification()
                }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
    }

    // MARK: - Scene Phase Handling
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            Task { @MainActor in
                await backgroundTaskManager.handleAppDidBecomeActive()
            }
        case .background:
            backgroundTaskManager.handleAppDidEnterBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}
