//
//  AudioManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import AVFoundation
import Combine

/// Manages ambient sound playback for focus sessions
@MainActor
class AudioManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AudioManager()

    // MARK: - Published Properties
    @Published var selectedSound: AmbientSound = .none
    @Published var isPlaying: Bool = false
    @Published var volume: Float = 0.7

    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var audioSession: AVAudioSession { AVAudioSession.sharedInstance() }

    // MARK: - Settings
    @UserDefault(key: "ambientSoundVolume", defaultValue: 0.7)
    private var storedVolume: Float

    @UserDefault(key: "lastAmbientSound", defaultValue: "none")
    private var lastSoundRawValue: String

    // MARK: - Initialization

    private init() {
        volume = storedVolume
        if let lastSound = AmbientSound(rawValue: lastSoundRawValue) {
            selectedSound = lastSound
        }
        configureAudioSession()
    }

    // MARK: - Audio Session Configuration

    private func configureAudioSession() {
        do {
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("AudioManager: Failed to configure audio session - \(error)")
        }
    }

    // MARK: - Playback Control

    /// Play the specified ambient sound
    func play(_ sound: AmbientSound) {
        // Stop current playback
        stop()

        // Update selection
        selectedSound = sound
        lastSoundRawValue = sound.rawValue

        // Don't play if none selected
        guard sound != .none, let fileName = sound.fileName else {
            return
        }

        // Load and play audio
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "mp3") else {
            print("AudioManager: Audio file not found - \(fileName).mp3")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = volume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("AudioManager: Failed to play audio - \(error)")
        }
    }

    /// Pause current playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
    }

    /// Resume paused playback
    func resume() {
        guard selectedSound != .none else { return }
        audioPlayer?.play()
        isPlaying = true
    }

    /// Stop playback completely
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    /// Toggle between play and pause
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    // MARK: - Volume Control

    /// Update playback volume (0.0 to 1.0)
    func setVolume(_ newVolume: Float) {
        let clampedVolume = max(0, min(1, newVolume))
        volume = clampedVolume
        storedVolume = clampedVolume
        audioPlayer?.volume = clampedVolume
    }

    // MARK: - Sound Selection

    /// Select a sound without immediately playing
    func selectSound(_ sound: AmbientSound) {
        selectedSound = sound
        lastSoundRawValue = sound.rawValue
    }

    // MARK: - Session Integration

    /// Start ambient sound for focus session (resumes last sound if any)
    func startForSession() {
        guard selectedSound != .none else { return }
        play(selectedSound)
    }

    /// Stop ambient sound when session ends
    func stopForSession() {
        stop()
    }

    /// Pause ambient sound when session is paused
    func pauseForSession() {
        pause()
    }

    /// Resume ambient sound when session resumes
    func resumeForSession() {
        guard selectedSound != .none else { return }
        resume()
    }
}
