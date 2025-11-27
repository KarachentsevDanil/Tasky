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
    @StateObject private var reviewService = WeeklyReviewService.shared
    @StateObject private var morningBriefService = MorningBriefService.shared

    // MARK: - State
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("appearanceMode") private var appearanceMode = AppearanceMode.system
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("taskDueReminders") private var taskDueReminders = true
    @AppStorage("scheduledTimeReminders") private var scheduledTimeReminders = true
    @AppStorage("advanceReminders") private var advanceReminders = true
    @AppStorage("timerNotifications") private var timerNotifications = true
    @AppStorage("aiTaskPreview") private var aiTaskPreview = true

    @State private var showingExportSheet = false
    @State private var showingPermissionAlert = false
    @State private var showingWeeklyReview = false
    @State private var pendingNotificationCount = 0
    @State private var memoryItemCount = 0
    @State private var morningBriefTime = Date()
    @State private var weekendBriefTime = Date()

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

                // Weekly Review Section
                Section {
                    // Start Review Button
                    Button {
                        showingWeeklyReview = true
                    } label: {
                        HStack {
                            Label("Start Weekly Review", systemImage: "calendar.badge.checkmark")
                            Spacer()
                            if reviewService.currentStreak > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame.fill")
                                        .foregroundStyle(.orange)
                                    Text("\(reviewService.currentStreak)")
                                        .foregroundStyle(.orange)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }

                    // Review Day Picker
                    Picker(selection: Binding(
                        get: { reviewService.reviewDay },
                        set: { reviewService.reviewDay = $0 }
                    )) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    } label: {
                        Label("Review Day", systemImage: "calendar")
                    }

                    // Review Time Picker
                    Picker(selection: Binding(
                        get: { reviewService.reviewHour },
                        set: { reviewService.reviewHour = $0 }
                    )) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    } label: {
                        Label("Review Time", systemImage: "clock")
                    }

                    // Reminder Toggle
                    Toggle(isOn: Binding(
                        get: { reviewService.isEnabled },
                        set: { reviewService.isEnabled = $0 }
                    )) {
                        Label("Weekly Reminder", systemImage: "bell.badge")
                    }
                } header: {
                    Text("Weekly Review")
                } footer: {
                    if let nextReview = reviewService.nextScheduledReview {
                        Text("Next review: \(nextReview.formatted(date: .abbreviated, time: .shortened))")
                    } else {
                        Text("Take 5-10 minutes each week to reflect and plan ahead")
                    }
                }

                // Goals Section
                Section {
                    NavigationLink {
                        GoalsListView()
                    } label: {
                        Label("Goals", systemImage: "target")
                    }
                } header: {
                    Text("Goals")
                } footer: {
                    Text("Track progress on larger projects by linking tasks to goals")
                }

                // Morning Brief Section
                Section {
                    // Enable Toggle
                    Toggle(isOn: Binding(
                        get: { morningBriefService.isBriefEnabled },
                        set: { morningBriefService.isBriefEnabled = $0 }
                    )) {
                        Label("Morning Brief", systemImage: "sun.max.fill")
                    }

                    if morningBriefService.isBriefEnabled {
                        // Brief Time Picker
                        Picker(selection: Binding(
                            get: { morningBriefService.briefHour },
                            set: { morningBriefService.briefHour = $0 }
                        )) {
                            ForEach(5..<12, id: \.self) { hour in
                                Text(formatHour(hour)).tag(hour)
                            }
                        } label: {
                            Label("Weekday Time", systemImage: "clock")
                        }

                        // Weekend Time Toggle
                        Toggle(isOn: Binding(
                            get: { morningBriefService.useWeekendTime },
                            set: { morningBriefService.useWeekendTime = $0 }
                        )) {
                            Label("Different Weekend Time", systemImage: "bed.double")
                        }

                        // Weekend Time Picker (if enabled)
                        if morningBriefService.useWeekendTime {
                            Picker(selection: Binding(
                                get: { morningBriefService.weekendBriefHour },
                                set: { morningBriefService.weekendBriefHour = $0 }
                            )) {
                                ForEach(5..<14, id: \.self) { hour in
                                    Text(formatHour(hour)).tag(hour)
                                }
                            } label: {
                                Label("Weekend Time", systemImage: "clock")
                            }
                        }
                    }
                } header: {
                    Text("Morning Brief")
                } footer: {
                    Text("Get a daily overview of your tasks each morning with top priorities and schedule preview")
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

                // AI Assistant Section
                Section {
                    Toggle(isOn: $aiTaskPreview) {
                        Label("Task Preview", systemImage: "eye")
                    }

                    NavigationLink {
                        MemoryView()
                    } label: {
                        HStack {
                            Label("AI Memory", systemImage: "brain")
                            Spacer()
                            Text("\(memoryItemCount) items")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("AI Assistant")
                } footer: {
                    Text("Task Preview shows a card after creating tasks via AI. Memory stores context the AI learns about you.")
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
            .fullScreenCover(isPresented: $showingWeeklyReview) {
                WeeklyReviewFlowView()
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
                await loadMemoryCount()
            }
            .refreshable {
                await loadNotificationStatus()
                await loadMemoryCount()
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

    @MainActor
    private func loadMemoryCount() async {
        do {
            memoryItemCount = try ContextService.shared.fetchContextCount()
        } catch {
            memoryItemCount = 0
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        var components = DateComponents()
        components.hour = hour
        if let date = Calendar.current.date(from: components) {
            return formatter.string(from: date)
        }
        return "\(hour):00"
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
