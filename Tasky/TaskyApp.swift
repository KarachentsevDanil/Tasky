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

    // MARK: - Body
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .task {
                    // Request notification permissions on app launch
                    try? await NotificationManager.shared.requestAuthorization()
                }
        }
    }
}
