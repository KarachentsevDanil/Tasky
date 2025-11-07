//
//  HapticManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import UIKit

/// Manages haptic feedback throughout the app
class HapticManager {

    // MARK: - Singleton
    static let shared = HapticManager()

    // MARK: - Generators
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    // MARK: - Settings
    @UserDefault(key: "hapticsEnabled", defaultValue: true)
    private var isEnabled: Bool

    // MARK: - Initialization
    private init() {
        // Prepare generators
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selection.prepare()
        notification.prepare()
    }

    // MARK: - Public Methods

    /// Trigger light impact haptic (for button taps, minor interactions)
    func lightImpact() {
        guard isEnabled else { return }
        impactLight.impactOccurred()
    }

    /// Trigger medium impact haptic (for task creation, drag events)
    func mediumImpact() {
        guard isEnabled else { return }
        impactMedium.impactOccurred()
    }

    /// Trigger heavy impact haptic (for task completion, timer start/stop)
    func heavyImpact() {
        guard isEnabled else { return }
        impactHeavy.impactOccurred()
    }

    /// Trigger selection haptic (for picker changes, reordering)
    func selectionChanged() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }

    /// Trigger success notification haptic (for task completion, achievements)
    func success() {
        guard isEnabled else { return }
        notification.notificationOccurred(.success)
    }

    /// Trigger warning notification haptic (for validation errors)
    func warning() {
        guard isEnabled else { return }
        notification.notificationOccurred(.warning)
    }

    /// Trigger error notification haptic (for errors)
    func error() {
        guard isEnabled else { return }
        notification.notificationOccurred(.error)
    }

    /// Toggle haptics on/off
    func toggle() {
        isEnabled.toggle()
    }

    /// Set haptics enabled state
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
}

// MARK: - UserDefault Property Wrapper
@propertyWrapper
struct UserDefault<T> {
    let key: String
    let defaultValue: T

    init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }

    var wrappedValue: T {
        get {
            return UserDefaults.standard.object(forKey: key) as? T ?? defaultValue
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }
}
