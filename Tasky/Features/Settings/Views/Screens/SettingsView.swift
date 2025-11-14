//
//  SettingsView.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 14.11.2025.
//

import SwiftUI

/// Settings modal view following iOS native patterns
struct SettingsView: View {

    // MARK: - Environment
    @StateObject private var notificationManager = NotificationManager.shared

    // MARK: - State
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("taskDueReminders") private var taskDueReminders = true
    @AppStorage("scheduledTimeReminders") private var scheduledTimeReminders = true
    @AppStorage("advanceReminders") private var advanceReminders = true
    @AppStorage("timerNotifications") private var timerNotifications = true

    @State private var showingExportSheet = false
    @State private var showingPermissionAlert = false
    @State private var pendingNotificationCount = 0

    // MARK: - Body
    var body: some View {
        Form {
                // Appearance Section
                Section {
                    Picker("Theme", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.iconName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Choose how Tasky looks on your device")
                }

                // Notifications Section
                Section {
                    notificationStatusRow

                    if notificationManager.authorizationStatus == .authorized {
                        Toggle(isOn: $taskDueReminders) {
                            Label("Task Due Reminders", systemImage: "bell.badge")
                        }

                        Toggle(isOn: $scheduledTimeReminders) {
                            Label("Scheduled Time Alerts", systemImage: "clock.badge")
                        }

                        Toggle(isOn: $advanceReminders) {
                            Label("15-Min Advance Reminders", systemImage: "bell.badge.clock")
                        }

                        Toggle(isOn: $timerNotifications) {
                            Label("Focus Timer Alerts", systemImage: "timer")
                        }

                        if pendingNotificationCount > 0 {
                            HStack {
                                Text("Pending Notifications")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(pendingNotificationCount)")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    notificationFooter
                }

                // Feedback Section
                Section {
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap")
                    }
                    .onChange(of: hapticsEnabled) { oldValue, newValue in
                        HapticManager.shared.setEnabled(newValue)
                        if newValue {
                            HapticManager.shared.lightImpact()
                        }
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Feel subtle vibrations when interacting with tasks")
                }

                // Data Section
                Section {
                    Button {
                        showingExportSheet = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export your tasks and statistics as CSV")
                }

                // About Section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/yourusername/tasky")!) {
                        Label("GitHub Repository", systemImage: "link")
                    }

                    Link(destination: URL(string: "mailto:support@tasky.app")!) {
                        Label("Contact Support", systemImage: "envelope")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingExportSheet) {
                ExportDataView()
            }
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Open Settings", role: .none) {
                    openAppSettings()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to receive reminders for your tasks and timers.")
            }
            .task {
                await loadNotificationStatus()
            }
            .refreshable {
                await loadNotificationStatus()
            }
    }

    // MARK: - Notification Status Row
    @ViewBuilder
    private var notificationStatusRow: some View {
        switch notificationManager.authorizationStatus {
        case .notDetermined:
            Button {
                requestNotificationPermission()
            } label: {
                HStack {
                    Label("Enable Notifications", systemImage: "bell.badge")
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

        case .authorized, .provisional, .ephemeral:
            HStack {
                Label("Notifications", systemImage: "bell.badge.fill")
                    .foregroundStyle(.green)
                Spacer()
                Text("Enabled")
                    .foregroundStyle(.secondary)
            }

        case .denied:
            Button {
                showingPermissionAlert = true
            } label: {
                HStack {
                    Label("Notifications", systemImage: "bell.slash")
                        .foregroundStyle(.orange)
                    Spacer()
                    Text("Disabled")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Notification Footer
    @ViewBuilder
    private var notificationFooter: some View {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Text("Get notified about task deadlines and focus session completions")
        case .denied:
            Text("Notifications are disabled. Tap to enable them in Settings.")
        case .notDetermined:
            Text("Tap to enable notifications for task reminders and timer alerts")
        @unknown default:
            EmptyView()
        }
    }

    // MARK: - Computed Properties
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Methods
    private func requestNotificationPermission() {
        Task {
            do {
                try await notificationManager.requestAuthorization()
                await loadNotificationStatus()
                HapticManager.shared.success()
            } catch {
                print("❌ Failed to request notification permission: \(error)")
                HapticManager.shared.error()
            }
        }
    }

    private func loadNotificationStatus() async {
        await notificationManager.checkAuthorizationStatus()
        pendingNotificationCount = await notificationManager.getPendingNotificationCount()
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
}

// MARK: - Appearance Mode Enum
enum AppearanceMode: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "Auto"
        }
    }

    var iconName: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

// MARK: - Export Data View
struct ExportDataView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var showShareSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "doc.text")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Export Your Data")
                    .font(.title2.weight(.bold))

                Text("Export all your tasks, lists, and statistics as a CSV file")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                if isExporting {
                    ProgressView("Preparing export...")
                } else {
                    Button {
                        exportData()
                    } label: {
                        Label("Export to CSV", systemImage: "arrow.down.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = exportURL {
                    ShareSheet(items: [url])
                }
            }
        }
    }

    private func exportData() {
        isExporting = true

        // TODO: Implement actual CSV export logic
        // For now, just simulate the export process
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

            // Create a temporary CSV file
            let fileName = "Tasky_Export_\(Date().formatted(date: .abbreviated, time: .omitted)).csv"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

            let csvContent = """
            Task,List,Status,Due Date,Priority
            Sample Task,Inbox,Completed,2025-11-14,High
            Another Task,Work,Pending,2025-11-15,Medium
            """

            try? csvContent.write(to: tempURL, atomically: true, encoding: .utf8)

            exportURL = tempURL
            isExporting = false
            showShareSheet = true
        }
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview
#Preview("Settings") {
    SettingsView()
}

#Preview("Export") {
    ExportDataView()
}
