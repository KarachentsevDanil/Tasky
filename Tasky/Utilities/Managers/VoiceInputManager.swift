//
//  VoiceInputManager.swift
//  Tasky
//
//  Created by Danylo Karachentsev on 07.11.2025.
//

import Foundation
import Combine
import Speech
import AVFoundation

/// Manager for voice input and speech recognition
@MainActor
class VoiceInputManager: ObservableObject {

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var isAvailable = false
    @Published var transcribedText = ""
    @Published var errorMessage: String?

    // MARK: - Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // MARK: - Initialization
    init() {
        checkAvailability()
    }

    // MARK: - Availability
    private func checkAvailability() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        guard let recognizer = speechRecognizer else {
            isAvailable = false
            return
        }

        isAvailable = recognizer.isAvailable

        // Observe availability changes
        recognizer.delegate = self as? SFSpeechRecognizerDelegate
    }

    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        // Request speech recognition authorization
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        guard speechStatus else {
            errorMessage = "Speech recognition not authorized"
            return false
        }

        // Request microphone authorization
        let micStatus = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }

        guard micStatus else {
            errorMessage = "Microphone access not authorized"
            return false
        }

        return true
    }

    // MARK: - Recording Control
    func startRecording() async throws {
        // Cancel any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            throw VoiceInputError.recognitionRequestFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Get input node
        let inputNode = audioEngine.inputNode

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            Task { @MainActor in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self.recognitionRequest = nil
                    self.recognitionTask = nil
                    self.isRecording = false
                }
            }
        }

        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        transcribedText = ""
    }

    func stopRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
        }

        isRecording = false
    }

    // MARK: - Cleanup
    func reset() {
        stopRecording()
        transcribedText = ""
        errorMessage = nil
    }
}

// MARK: - Voice Input Error
enum VoiceInputError: LocalizedError {
    case recognitionRequestFailed
    case notAuthorized
    case notAvailable

    var errorDescription: String? {
        switch self {
        case .recognitionRequestFailed:
            return "Failed to create speech recognition request"
        case .notAuthorized:
            return "Speech recognition or microphone not authorized"
        case .notAvailable:
            return "Speech recognition not available on this device"
        }
    }
}
