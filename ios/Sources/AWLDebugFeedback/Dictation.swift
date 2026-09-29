//
//  Created by Apps with love.
//  Copyright © 2026 Apps with love AG. All rights reserved.
//

import AVFoundation
import Combine
import Speech

/// On-device speech-to-text. Audio never leaves the device: without an on-device model for the
/// user's language dictation is unavailable rather than falling back to Apple's servers.
@MainActor
final class Dictation: ObservableObject {
    @Published private(set) var isRecording = false
    /// Shown below the text field when dictation cannot run; typing always stays possible.
    @Published private(set) var problem: String?

    private var audioEngine: AVAudioEngine?
    private var task: SFSpeechRecognitionTask?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var onTranscript: ((String) -> Void)?

    /// `onTranscript` receives the full transcript of this recording each time it changes.
    func start(onTranscript: @escaping (String) -> Void) async {
        guard !isRecording else {
            return
        }
        problem = nil
        guard await Self.requestSpeechPermission() else {
            problem = "Speech recognition is not allowed. Enable it in Settings to dictate."
            return
        }
        guard await Self.requestRecordPermission() else {
            problem = "Microphone access is not allowed. Enable it in Settings to dictate."
            return
        }
        guard let recognizer = Self.onDeviceRecognizer() else {
            problem = "On-device dictation is not available for this language."
            return
        }
        do {
            try begin(with: recognizer)
            self.onTranscript = onTranscript
            isRecording = true
        } catch {
            stop()
            problem = "Dictation could not start."
        }
    }

    func stop() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        audioEngine = nil
        request = nil
        task = nil
        onTranscript = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func begin(with recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        let engine = AVAudioEngine()
        let input = engine.inputNode
        input.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: input.outputFormat(forBus: 0),
            block: Self.tap(feeding: request)
        )
        engine.prepare()
        try engine.start()

        audioEngine = engine
        self.request = request
        task = recognizer.recognitionTask(
            with: request,
            resultHandler: Self.resultHandler { [weak self] text, isFinal in
                self?.handle(text: text, isFinal: isFinal)
            }
        )
    }

    private func handle(text: String?, isFinal: Bool) {
        if let text {
            onTranscript?(text)
        }
        if isFinal {
            stop()
        }
    }

    private static func onDeviceRecognizer() -> SFSpeechRecognizer? {
        let current = Locale.current
        let candidates = [current, Locale(identifier: current.language.languageCode?.identifier ?? "en")]
        return candidates
            .lazy
            .compactMap { SFSpeechRecognizer(locale: $0) }
            .first { $0.supportsOnDeviceRecognition && $0.isAvailable }
    }

    private nonisolated static func requestRecordPermission() async -> Bool {
        if #available(iOS 17, *) {
            return await AVAudioApplication.requestRecordPermission()
        }
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private nonisolated static func requestSpeechPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// The tap and the result handler run on audio and recognition queues, so they must not
    /// inherit this class's main-actor isolation.
    private nonisolated static func tap(feeding request: SFSpeechAudioBufferRecognitionRequest) -> AVAudioNodeTapBlock {
        nonisolated(unsafe) let request = request
        return { buffer, _ in request.append(buffer) }
    }

    private nonisolated static func resultHandler(
        _ handler: @escaping @MainActor @Sendable (String?, Bool) -> Void
    ) -> @Sendable (SFSpeechRecognitionResult?, Error?) -> Void {
        { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in handler(text, isFinal) }
        }
    }
}
