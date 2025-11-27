//
//  AmbientSoundPicker.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 26.11.2025.
//

import SwiftUI

/// Grid picker for selecting ambient sounds during focus sessions
struct AmbientSoundPicker: View {

    // MARK: - Properties
    @ObservedObject var audioManager: AudioManager
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Sound Grid
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(AmbientSound.allCases) { sound in
                        SoundOptionCell(
                            sound: sound,
                            isSelected: audioManager.selectedSound == sound,
                            isPlaying: audioManager.isPlaying && audioManager.selectedSound == sound
                        ) {
                            selectSound(sound)
                        }
                    }
                }
                .padding(.horizontal)

                // Volume Slider (only show when a sound is selected)
                if audioManager.selectedSound != .none {
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "speaker.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Slider(
                                value: Binding(
                                    get: { Double(audioManager.volume) },
                                    set: { audioManager.setVolume(Float($0)) }
                                ),
                                in: 0...1
                            )
                            .tint(.orange)

                            Image(systemName: "speaker.wave.3.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text("Volume: \(Int(audioManager.volume * 100))%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 32)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()

                // Note about audio files
                Text("Audio plays during focus sessions")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.bottom)
            }
            .padding(.top, 24)
            .navigationTitle("Ambient Sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Actions

    private func selectSound(_ sound: AmbientSound) {
        HapticManager.shared.selectionChanged()

        if sound == .none {
            audioManager.stop()
            audioManager.selectSound(.none)
        } else if audioManager.selectedSound == sound && audioManager.isPlaying {
            // Tapping same sound toggles playback
            audioManager.pause()
        } else {
            audioManager.play(sound)
        }
    }
}

// MARK: - Sound Option Cell

private struct SoundOptionCell: View {
    let sound: AmbientSound
    let isSelected: Bool
    let isPlaying: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    // Background circle
                    Circle()
                        .fill(isSelected ? sound.iconColor : Color(.systemGray5))
                        .frame(width: 64, height: 64)

                    // Playing animation ring
                    if isPlaying {
                        Circle()
                            .stroke(sound.iconColor.opacity(0.5), lineWidth: 2)
                            .frame(width: 72, height: 72)
                            .scaleEffect(isPlaying ? 1.1 : 1.0)
                            .opacity(isPlaying ? 0 : 1)
                            .animation(
                                reduceMotion ? .none : .easeOut(duration: 1).repeatForever(autoreverses: false),
                                value: isPlaying
                            )
                    }

                    // Icon
                    Image(systemName: sound.icon)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : sound.iconColor)
                }

                // Label
                Text(sound.displayName)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? sound.iconColor : .primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sound.displayName) sound")
        .accessibilityHint(isSelected ? "Currently selected" : "Double tap to select")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview {
    AmbientSoundPicker(audioManager: AudioManager.shared)
}
