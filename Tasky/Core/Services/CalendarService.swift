//
//  CalendarService.swift
//  Tasky
//
//  Created by Claude Code on 27.11.2025.
//

import Combine
import EventKit
import SwiftUI

/// Service for accessing user's calendar events via EventKit
@MainActor
final class CalendarService: ObservableObject {

    // MARK: - Singleton

    static let shared = CalendarService()

    // MARK: - Properties

    private let eventStore = EKEventStore()
    private var cachedEvents: [Date: [ExternalEvent]] = [:]
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 15 * 60 // 15 minutes

    @Published private(set) var permissionStatus: CalendarPermissionStatus = .notDetermined
    @Published private(set) var availableCalendars: [CalendarInfo] = []

    /// UserDefaults key for disabled calendars
    private let disabledCalendarsKey = "CalendarService.disabledCalendarIds"

    // MARK: - Initialization

    private init() {
        updatePermissionStatus()
    }

    // MARK: - Permission Handling

    /// Check current authorization status
    func updatePermissionStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)

        switch status {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .authorized, .fullAccess:
            permissionStatus = .authorized
            Task {
                await loadAvailableCalendars()
            }
        case .denied:
            permissionStatus = .denied
        case .restricted, .writeOnly:
            permissionStatus = .restricted
        @unknown default:
            permissionStatus = .denied
        }
    }

    /// Request calendar access permission
    /// - Returns: True if access was granted
    func requestAccess() async -> Bool {
        do {
            // iOS 17+ uses requestFullAccessToEvents
            if #available(iOS 17.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    permissionStatus = granted ? .authorized : .denied
                }
                if granted {
                    await loadAvailableCalendars()
                }
                return granted
            } else {
                // Fallback for older iOS
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run {
                    permissionStatus = granted ? .authorized : .denied
                }
                if granted {
                    await loadAvailableCalendars()
                }
                return granted
            }
        } catch {
            print("CalendarService: Failed to request access: \(error)")
            await MainActor.run {
                permissionStatus = .denied
            }
            return false
        }
    }

    // MARK: - Calendar Management

    /// Load all available calendars
    private func loadAvailableCalendars() async {
        guard permissionStatus.hasAccess else { return }

        let calendars = eventStore.calendars(for: .event)
        let disabledIds = getDisabledCalendarIds()

        let calendarInfos = calendars.map { calendar -> CalendarInfo in
            let colorHex = calendar.cgColor.map { UIColor(cgColor: $0).hexString } ?? "808080"
            return CalendarInfo(
                id: calendar.calendarIdentifier,
                title: calendar.title,
                colorHex: colorHex,
                source: calendar.source.title,
                isEnabled: !disabledIds.contains(calendar.calendarIdentifier)
            )
        }.sorted { $0.title < $1.title }

        await MainActor.run {
            availableCalendars = calendarInfos
        }
    }

    /// Enable or disable a specific calendar
    func setCalendarEnabled(_ calendarId: String, enabled: Bool) {
        var disabledIds = getDisabledCalendarIds()

        if enabled {
            disabledIds.remove(calendarId)
        } else {
            disabledIds.insert(calendarId)
        }

        UserDefaults.standard.set(Array(disabledIds), forKey: disabledCalendarsKey)

        // Update local state
        if let index = availableCalendars.firstIndex(where: { $0.id == calendarId }) {
            availableCalendars[index].isEnabled = enabled
        }

        // Invalidate cache
        clearCache()
    }

    private func getDisabledCalendarIds() -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: disabledCalendarsKey) ?? []
        return Set(array)
    }

    private func getEnabledCalendars() -> [EKCalendar] {
        let disabledIds = getDisabledCalendarIds()
        return eventStore.calendars(for: .event).filter { !disabledIds.contains($0.calendarIdentifier) }
    }

    // MARK: - Event Fetching

    /// Fetch events for a specific day
    func fetchEventsForDay(_ date: Date) async throws -> [ExternalEvent] {
        guard permissionStatus.hasAccess else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        return try await fetchEvents(from: startOfDay, to: endOfDay)
    }

    /// Fetch events for a date range
    func fetchEvents(from startDate: Date, to endDate: Date) async throws -> [ExternalEvent] {
        guard permissionStatus.hasAccess else { return [] }

        // Check cache
        let cacheKey = Calendar.current.startOfDay(for: startDate)
        if let cached = cachedEvents[cacheKey],
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached.filter { event in
                event.startDate >= startDate && event.startDate < endDate
            }
        }

        let enabledCalendars = getEnabledCalendars()
        guard !enabledCalendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: enabledCalendars
        )

        let ekEvents = eventStore.events(matching: predicate)

        let externalEvents = ekEvents.map { event -> ExternalEvent in
            let colorHex = event.calendar.cgColor.map { UIColor(cgColor: $0).hexString } ?? "808080"

            return ExternalEvent(
                id: event.eventIdentifier,
                title: event.title ?? "Untitled Event",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                calendarTitle: event.calendar.title,
                calendarColorHex: colorHex,
                location: event.location,
                notes: event.notes
            )
        }.sorted { $0.startDate < $1.startDate }

        // Update cache
        cachedEvents[cacheKey] = externalEvents
        cacheTimestamp = Date()

        return externalEvents
    }

    /// Fetch events for planning (today + 7 days)
    func fetchEventsForPlanning() async throws -> [ExternalEvent] {
        guard permissionStatus.hasAccess else { return [] }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .day, value: 8, to: startDate)!

        return try await fetchEvents(from: startDate, to: endDate)
    }

    /// Get blocked time slots for a specific date (for AI planning)
    func getBlockedTimeSlots(for date: Date) async throws -> [BlockedTimeSlot] {
        let events = try await fetchEventsForDay(date)

        return events.map { event in
            BlockedTimeSlot(
                startDate: event.startDate,
                endDate: event.endDate,
                title: event.title,
                isAllDay: event.isAllDay
            )
        }
    }

    /// Calculate available minutes for a day (excluding calendar events)
    func calculateAvailableMinutes(for date: Date, workdayStart: Int = 9, workdayEnd: Int = 17) async throws -> Int {
        let blockedSlots = try await getBlockedTimeSlots(for: date)

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // Create workday boundaries
        guard let workStart = calendar.date(bySettingHour: workdayStart, minute: 0, second: 0, of: startOfDay),
              let workEnd = calendar.date(bySettingHour: workdayEnd, minute: 0, second: 0, of: startOfDay) else {
            return (workdayEnd - workdayStart) * 60
        }

        let totalWorkMinutes = (workdayEnd - workdayStart) * 60

        // Calculate blocked minutes during work hours
        var blockedMinutes = 0
        for slot in blockedSlots {
            guard !slot.isAllDay else {
                // All-day event blocks everything
                return 0
            }

            // Calculate overlap with work hours
            let overlapStart = max(slot.startDate, workStart)
            let overlapEnd = min(slot.endDate, workEnd)

            if overlapEnd > overlapStart {
                blockedMinutes += Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
            }
        }

        return max(0, totalWorkMinutes - blockedMinutes)
    }

    // MARK: - Cache Management

    func clearCache() {
        cachedEvents.removeAll()
        cacheTimestamp = nil
    }

    func refreshCalendars() async {
        await loadAvailableCalendars()
        clearCache()
    }
}

// MARK: - UIColor Extension for Hex

private extension UIColor {
    var hexString: String {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0

        getRed(&r, green: &g, blue: &b, alpha: &a)

        let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255)
        return String(format: "%06X", rgb)
    }
}
