//
//  BackgroundTaskManager.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import BackgroundTasks
import Foundation

/// Manager for background tasks including context maintenance
class BackgroundTaskManager {

    // MARK: - Singleton
    static let shared = BackgroundTaskManager()

    // MARK: - Task Identifiers
    private let contextMaintenanceTaskId = "com.tasky.contextMaintenance"

    // MARK: - Dependencies
    private let contextService: ContextService

    // MARK: - Initialization
    init(contextService: ContextService = .shared) {
        self.contextService = contextService
    }

    // MARK: - Registration

    /// Register all background tasks with the system
    /// Call this in application(_:didFinishLaunchingWithOptions:) or app init
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: contextMaintenanceTaskId,
            using: nil
        ) { [weak self] task in
            self?.handleContextMaintenanceTask(task as! BGProcessingTask)
        }

        print("BackgroundTaskManager: Registered background tasks")
    }

    // MARK: - Scheduling

    /// Schedule the daily context maintenance task
    /// Best called when app moves to background
    func scheduleContextMaintenance() {
        let request = BGProcessingTaskRequest(identifier: contextMaintenanceTaskId)

        // Run once per day, preferably at night
        request.earliestBeginDate = Date(timeIntervalSinceNow: 24 * 60 * 60) // 24 hours
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("BackgroundTaskManager: Scheduled context maintenance")
        } catch {
            print("BackgroundTaskManager: Failed to schedule context maintenance: \(error)")
        }
    }

    /// Cancel all scheduled background tasks
    func cancelAllTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        print("BackgroundTaskManager: Cancelled all background tasks")
    }

    // MARK: - Task Handlers

    /// Handle the context maintenance background task
    private func handleContextMaintenanceTask(_ task: BGProcessingTask) {
        print("BackgroundTaskManager: Starting context maintenance task")

        // Schedule the next run
        scheduleContextMaintenance()

        // Create a task to perform maintenance
        let maintenanceTask = Task { @MainActor in
            do {
                try await contextService.performDailyMaintenance()
                task.setTaskCompleted(success: true)
                print("BackgroundTaskManager: Context maintenance completed successfully")
            } catch {
                task.setTaskCompleted(success: false)
                print("BackgroundTaskManager: Context maintenance failed: \(error)")
            }
        }

        // Handle task expiration
        task.expirationHandler = {
            maintenanceTask.cancel()
            print("BackgroundTaskManager: Context maintenance task expired")
        }
    }

    // MARK: - Manual Maintenance

    /// Perform maintenance immediately (called from app foreground)
    @MainActor
    func performImmediateMaintenance() async {
        do {
            try await contextService.performLightMaintenance()
            print("BackgroundTaskManager: Immediate maintenance completed")
        } catch {
            print("BackgroundTaskManager: Immediate maintenance failed: \(error)")
        }
    }
}

// MARK: - App Lifecycle Integration

extension BackgroundTaskManager {

    /// Call when app enters foreground
    @MainActor
    func handleAppDidBecomeActive() async {
        // Perform light maintenance on app activation
        await performImmediateMaintenance()
    }

    /// Call when app enters background
    func handleAppDidEnterBackground() {
        // Schedule background task
        scheduleContextMaintenance()
    }
}
