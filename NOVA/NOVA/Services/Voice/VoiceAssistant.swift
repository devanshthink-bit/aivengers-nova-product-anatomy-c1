//
//  VoiceAssistant.swift
//  NOVA
//

import Foundation
import Observation

/// Whoever owns the audio session. `SoundPlayer` in the app; a counter in tests.
protocol VoiceAudioSession: AnyObject {
    func beginVoice()
    func endVoice()
}

/// One spoken briefing: greet, listen once, answer, done.
///
/// Holds the flow and nothing device-specific. The microphone, the voice and the
/// writers come in through protocols, which is what lets the whole flow be tested
/// without a phone.
@Observable
final class VoiceAssistant {
    enum Phase: Equatable {
        case idle
        case greeting
        case listening
        case thinking
        /// Reading the item at this index.
        case speaking(Int)
        case done
        case failed(Failure)
    }

    enum Failure: Equatable {
        case permissionDenied
        case nothingHeard
        case storiesLoading
        case briefingFailed
    }

    private(set) var phase: Phase = .idle
    private(set) var transcript = ""
    private(set) var briefing: Briefing?
    /// The language in use, which can drop from Hindi to English mid-run.
    private(set) var language: VoiceLanguage = .english

    var isActive: Bool {
        switch phase {
        case .idle, .done, .failed: false
        default: true
        }
    }

    private let listener: any VoiceListening
    private let speaker: any VoiceSpeaking
    private let writer: any BriefingWriter

    private var run: Task<Void, Never>?
    /// Identifies the current run. An abandoned run finishes later than the one that
    /// replaced it, and must not release the audio the new run is holding.
    private var runID = 0
    private var audio: (any VoiceAudioSession)?
    private var holdsAudio = false

    init(
        listener: any VoiceListening = SpeechListener(),
        speaker: any VoiceSpeaking = Speaker(),
        writer: any BriefingWriter = FallbackBriefingWriter.standard
    ) {
        self.listener = listener
        self.speaker = speaker
        self.writer = writer
        listener.onPartial = { [weak self] text in self?.transcript = text }
    }

    func start(pool: [Story], readerName: String, language: VoiceLanguage, audio: (any VoiceAudioSession)?) {
        stop()
        runID += 1
        let id = runID
        self.audio = audio
        self.language = language
        transcript = ""
        briefing = nil
        run = Task { await perform(pool: pool, readerName: readerName, runID: id) }
    }

    func stop() {
        run?.cancel()
        run = nil
        listener.stop()
        speaker.stop()
        releaseAudio()
        if isActive { phase = briefing == nil ? .idle : .done }
    }

    /// Resolves when the latest run ends. Only tests wait on it.
    ///
    /// Loops because a run can be replaced while it's being awaited. Restarting mid-run
    /// swaps `run`, and waiting on the old one alone would return too early.
    func waitUntilFinished() async {
        while let current = run {
            await current.value
            if run == current { return }
        }
    }

    // MARK: - The run

    private func perform(pool: [Story], readerName: String, runID id: Int) async {
        defer { if id == runID { releaseAudio() } }

        guard await listener.requestPermission() else {
            if !Task.isCancelled { phase = .failed(.permissionDenied) }
            return
        }
        guard !Task.isCancelled else { return }
        takeAudio()

        guard !pool.isEmpty else {
            phase = .failed(.storiesLoading)
            await speaker.say(language.storiesLoading, language: language)
            return
        }

        phase = .greeting
        await speaker.say(language.greeting(name: readerName), language: language)
        guard !Task.isCancelled else { return }

        guard let heard = await listenForRequest() else {
            if !Task.isCancelled { phase = .failed(.nothingHeard) }
            return
        }

        phase = .thinking
        var intent = VoiceIntent.parse(heard)
        var candidates = Highlights.candidates(for: intent, from: pool, limit: Highlights.aiCandidateLimit)
        if candidates.isEmpty {
            // Nothing in that topic today. The newest of everything beats silence, and the
            // intro names no topic, so it doesn't claim these are what was asked for.
            intent.category = nil
            candidates = Highlights.candidates(for: intent, from: pool, limit: Highlights.aiCandidateLimit)
        }

        let result = try? await writer.brief(request: heard, intent: intent, language: language, candidates: candidates)
        guard !Task.isCancelled else { return }
        guard let result else {
            phase = .failed(.briefingFailed)
            return
        }
        briefing = result

        await speaker.say(result.intro, language: language)
        for (index, item) in result.items.enumerated() {
            guard !Task.isCancelled else { return }
            phase = .speaking(index)
            await speaker.say("\(index + 1). \(item.line)", language: result.lineLanguage)
        }
        guard !Task.isCancelled else { return }
        phase = .done
    }

    /// Listens up to twice. Returns nil when nothing usable was heard.
    private func listenForRequest() async -> String? {
        var misses = 0
        while misses < 2 {
            guard !Task.isCancelled else { return nil }
            phase = .listening
            transcript = ""
            do {
                let heard = try await listener.listen(language: language)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !heard.isEmpty { return heard }
            } catch ListenError.localeUnavailable where language == .hindi {
                // This phone can't recognise Hindi. Say so in Hindi, then carry on in
                // English: a briefing in the other language beats none.
                await speaker.say(VoiceLanguage.hindiRecognitionUnavailable, language: .hindi)
                language = .english
                continue
            } catch {
                // Anything else counts as not hearing the reader.
            }
            misses += 1
            if misses < 2, !Task.isCancelled {
                await speaker.say(language.didNotCatch, language: language)
            }
        }
        return nil
    }

    // MARK: - Audio

    private func takeAudio() {
        guard !holdsAudio else { return }
        audio?.beginVoice()
        holdsAudio = true
    }

    private func releaseAudio() {
        guard holdsAudio else { return }
        audio?.endVoice()
        holdsAudio = false
    }
}
