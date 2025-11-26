//
//  AmbientSound.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI

/// Ambient sound options for focus timer sessions
enum AmbientSound: String, CaseIterable, Identifiable {
    case none
    case clock
    case rain
    case forest
    case campfire
    case cafe
    case whiteNoise

    var id: String { rawValue }

    // MARK: - Display Properties

    var displayName: String {
        switch self {
        case .none: return "None"
        case .clock: return "Clock"
        case .rain: return "Rain"
        case .forest: return "Forest"
        case .campfire: return "Campfire"
        case .cafe: return "Cafe"
        case .whiteNoise: return "White Noise"
        }
    }

    var icon: String {
        switch self {
        case .none: return "speaker.slash.fill"
        case .clock: return "clock.fill"
        case .rain: return "cloud.rain.fill"
        case .forest: return "leaf.fill"
        case .campfire: return "flame.fill"
        case .cafe: return "cup.and.saucer.fill"
        case .whiteNoise: return "waveform"
        }
    }

    var iconColor: Color {
        switch self {
        case .none: return .secondary
        case .clock: return .brown
        case .rain: return .blue
        case .forest: return .green
        case .campfire: return .orange
        case .cafe: return .brown
        case .whiteNoise: return .purple
        }
    }

    /// File name for the audio resource (without extension)
    var fileName: String? {
        switch self {
        case .none: return nil
        case .clock: return "clock"
        case .rain: return "rain"
        case .forest: return "forest"
        case .campfire: return "campfire"
        case .cafe: return "cafe"
        case .whiteNoise: return "whitenoise"
        }
    }

    // MARK: - Playable Sounds

    /// Returns all sounds that have audio files (excludes .none)
    static var playableSounds: [AmbientSound] {
        allCases.filter { $0 != .none }
    }
}
