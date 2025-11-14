//
//  Constants.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 01.11.2025.
//

import SwiftUI

// MARK: - App Constants
enum Constants {

    // MARK: - List Limits
    enum Limits {
        static let maxCustomLists = 5
        static let maxTaskTitleLength = 200
        static let maxTaskNotesLength = 1000
        static let maxListNameLength = 50
    }

    // MARK: - UI Constants
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let rowHeight: CGFloat = 56
        static let iconSize: CGFloat = 24
        static let padding: CGFloat = 16
        static let smallPadding: CGFloat = 8
    }

    // MARK: - Default List Icons
    enum Icons {
        static let inbox = "tray.fill"
        static let today = "calendar"
        static let upcoming = "calendar.badge.clock"
        static let completed = "checkmark.circle.fill"
        static let list = "list.bullet"
        static let add = "plus"
        static let delete = "trash"
        static let edit = "pencil"
        static let chevronRight = "chevron.right"
    }

    // MARK: - Icon Rendering
    enum IconScale {
        static let small: Image.Scale = .small
        static let medium: Image.Scale = .medium
        static let large: Image.Scale = .large
    }

    enum IconRendering {
        static let hierarchical: SymbolRenderingMode = .hierarchical
        static let monochrome: SymbolRenderingMode = .monochrome
        static let multicolor: SymbolRenderingMode = .multicolor
        static let palette: SymbolRenderingMode = .palette
    }

    // MARK: - Color Palette for Lists
    enum Colors {
        static let listColors: [(name: String, hex: String, color: Color)] = [
            ("Blue", "007AFF", .blue),
            ("Green", "34C759", .green),
            ("Orange", "FF9500", .orange),
            ("Red", "FF3B30", .red),
            ("Purple", "AF52DE", .purple),
            ("Pink", "FF2D55", .pink),
            ("Teal", "5AC8FA", .teal),
            ("Indigo", "5856D6", .indigo)
        ]

        static let defaultListColor = "007AFF"
    }

    // MARK: - Default Lists
    enum DefaultLists {
        static let inboxName = "Inbox"
    }

    // MARK: - Task Priority
    enum TaskPriority: Int16, CaseIterable {
        case none = 0
        case low = 1
        case medium = 2
        case high = 3

        var displayName: String {
            switch self {
            case .none: return "None"
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }

        var color: Color {
            switch self {
            case .none: return .gray
            case .low: return .blue
            case .medium: return .orange
            case .high: return .red
            }
        }
    }

    // MARK: - Animation Constants
    enum Animation {
        /// No animation (0s) - for reduce motion accessibility
        static let instant: Double = 0.0

        /// Fast animation (0.15s) - for quick feedback
        static let fast: Double = 0.15

        /// Standard animation (0.25s) - default for most interactions
        static let standard: Double = 0.25

        /// Slow animation (0.35s) - for more prominent transitions
        static let slow: Double = 0.35

        /// Celebration animation (0.8s) - for confetti and achievements
        static let celebration: Double = 0.8

        /// Spring animation parameters
        enum Spring {
            /// Response time for spring animations
            static let response: Double = 0.3

            /// Damping fraction for spring animations
            static let dampingFraction: Double = 0.7
        }
    }
}
