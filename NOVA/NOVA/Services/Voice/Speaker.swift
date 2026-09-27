//
//  Speaker.swift
//  NOVA
//

import AVFoundation

protocol VoiceSpeaking: AnyObject {
    /// Speaks `text` and returns when it has finished or was stopped.
    func say(_ text: String, language: VoiceLanguage) async
    func stop()
}

/// Apple's built-in voices: free, offline, and already on the phone.
final class Speaker: NSObject, VoiceSpeaking, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// Which utterance the pending `say` is waiting on. A cancelled utterance's delegate
    /// callback arrives late, and without this check it would end the *next* line early.
    private var current: ObjectIdentifier?
    private var finished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, language: VoiceLanguage) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: language)
        // A beat between highlights, so ten lines don't run together into one.
        utterance.postUtteranceDelay = 0.25
        await withCheckedContinuation { continuation in
            finished = continuation
            current = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        current = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finished?.resume()
        finished = nil
    }

    private func ended(_ id: ObjectIdentifier) {
        guard id == current else { return }
        current = nil
        finished?.resume()
        finished = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }

    /// The best installed voice for the exact locale, then any voice for the language.
    /// Enhanced and premium voices are much easier to listen to for ninety seconds, and
    /// readers who have downloaded one get it automatically.
    static func voice(for language: VoiceLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let exact = voices.filter { $0.language == language.localeIdentifier }
        let family = voices.filter { $0.language.hasPrefix(language.rawValue) }
        return (exact.isEmpty ? family : exact).max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language.localeIdentifier)
    }
}
