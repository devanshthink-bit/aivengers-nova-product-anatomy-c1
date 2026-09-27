//
//  SpeechListener.swift
//  NOVA
//

import AVFoundation
// The recognition request is fed from the audio thread by design; Speech predates
// Sendable annotations, so its types are taken on trust here.
@preconcurrency import Speech

protocol VoiceListening: AnyObject {
    /// The transcript so far, as the reader speaks.
    var onPartial: ((String) -> Void)? { get set }
    func requestPermission() async -> Bool
    /// Listens until the reader pauses, then returns what they said. Returns "" if
    /// nothing was heard.
    func listen(language: VoiceLanguage) async throws -> String
    func stop()
}

enum ListenError: Error {
    /// This phone can't recognise that language right now.
    case localeUnavailable
}

/// The microphone and Apple's speech recogniser.
final class SpeechListener: VoiceListening {
    /// Long enough for a breath mid-sentence, short enough not to feel ignored.
    static let silenceTimeout: Duration = .milliseconds(1500)
    /// A cap for when nothing is ever said: the recogniser would otherwise wait for good.
    static let maximumDuration: Duration = .seconds(10)

    var onPartial: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Never>?
    private var transcript = ""
    private var silenceTimer: Task<Void, Never>?
    private var capTimer: Task<Void, Never>?
    /// Bumped on every listen, so a late callback from a cancelled recognition can't
    /// write into the next one.
    private var generation = 0
    /// Tracked apart from `engine.isRunning`: the engine stops *itself* on an interruption
    /// or a route change, and a tap left behind then makes the next `installTap` trap.
    private var tapInstalled = false

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func listen(language: VoiceLanguage) async throws -> String {
        finish()
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else {
            throw ListenError.localeUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device where this phone can do it for this language: free, private, offline.
        // Otherwise Apple's server recognises it, which is still free and keyless, but the
        // audio leaves the phone. The usage string says so.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        // `@Sendable` matters. The tap runs on the audio thread, and under this target's
        // default MainActor isolation an unannotated closure would be inferred main-actor
        // and trap the first time audio arrived.
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { @Sendable buffer, _ in
            request.append(buffer)
        }
        tapInstalled = true
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            tapInstalled = false
            throw error
        }

        self.request = request
        transcript = ""
        generation += 1
        let current = generation

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                let listener = self
                Task { @MainActor in
                    listener?.handle(text: text, isFinal: isFinal, failed: failed, generation: current)
                }
            }
            capTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.maximumDuration)
                if !Task.isCancelled { self?.finish() }
            }
        }
    }

    func stop() {
        finish()
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool, generation: Int) {
        guard generation == self.generation, continuation != nil else { return }
        if let text, !text.isEmpty {
            transcript = text
            onPartial?(text)
            silenceTimer?.cancel()
            silenceTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.silenceTimeout)
                if !Task.isCancelled { self?.finish() }
            }
        }
        // "No speech detected" arrives as an error. It ends the turn with whatever was
        // heard, usually nothing, and the assistant decides what that means.
        if isFinal || failed { finish() }
    }

    private func finish() {
        silenceTimer?.cancel()
        capTimer?.cancel()
        if engine.isRunning {
            engine.stop()
        }
        if tapInstalled {
            engine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        continuation?.resume(returning: transcript)
        continuation = nil
    }
}
