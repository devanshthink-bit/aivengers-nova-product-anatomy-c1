//
//  VoiceAssistantTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, _ category: StoryCategory, hoursAgo: Double = 0) -> Story {
    Story(id: StoryID(id), title: "Headline \(id)", summary: "", source: "Src",
          category: category, publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
          artwork: .none)
}

private let pool = [
    story("t1", .technology, hoursAgo: 0), story("t2", .technology, hoursAgo: 1),
    story("t3", .technology, hoursAgo: 2), story("i1", .india, hoursAgo: 3)
]

private final class FakeListener: VoiceListening {
    enum Reply { case heard(String), localeUnavailable }

    var replies: [Reply]
    let granted: Bool
    var onPartial: ((String) -> Void)?
    private(set) var languages: [VoiceLanguage] = []

    init(_ replies: [Reply], granted: Bool = true) {
        self.replies = replies
        self.granted = granted
    }

    func requestPermission() async -> Bool { granted }

    func listen(language: VoiceLanguage) async throws -> String {
        languages.append(language)
        guard !replies.isEmpty else { return "" }
        switch replies.removeFirst() {
        case .heard(let text):
            onPartial?(text)
            return text
        case .localeUnavailable:
            throw ListenError.localeUnavailable
        }
    }

    func stop() {}
}

private final class FakeSpeaker: VoiceSpeaking {
    private(set) var lines: [String] = []
    /// Called as each line starts, so a test can stop or restart mid-briefing.
    var onSay: ((String) -> Void)?

    func say(_ text: String, language: VoiceLanguage) async {
        lines.append(text)
        onSay?(text)
    }

    func stop() {}
}

private final class FakeAudio: VoiceAudioSession {
    private(set) var begins = 0
    private(set) var ends = 0
    var onInterruption: (() -> Void)?
    func beginVoice() { begins += 1 }
    func endVoice() { ends += 1 }
    /// What a phone call or unplugged headphones would do.
    func interrupt() { onInterruption?() }
}

/// Behaves like the real listener on `stop()`: a listen that is still waiting returns
/// whatever was heard so far, rather than nothing.
private final class MidSentenceListener: VoiceListening {
    var onPartial: ((String) -> Void)?
    /// Called once the listen is waiting, so a test can stop it mid-sentence.
    var onListening: (() -> Void)?
    private var pending: CheckedContinuation<String, Never>?

    func requestPermission() async -> Bool { true }

    func listen(language: VoiceLanguage) async throws -> String {
        await withCheckedContinuation { continuation in
            pending = continuation
            onPartial?("tech ne")
            onListening?()
        }
    }

    func stop() {
        pending?.resume(returning: "tech ne")
        pending = nil
    }
}

private struct NoTranslation: HeadlineTranslating {
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? { nil }
}

@Suite("Voice assistant")
struct VoiceAssistantTests {

    private func assistant(_ listener: FakeListener, _ speaker: FakeSpeaker) -> VoiceAssistant {
        VoiceAssistant(listener: listener, speaker: speaker,
                       writer: RuleBriefingWriter(translator: NoTranslation()))
    }

    @Test("Greets, listens, and reads the briefing")
    func happyPath() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([.heard("tech news")]), speaker)
        voice.start(pool: pool, readerName: "Prakash", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(voice.phase == .done)
        #expect(voice.transcript == "tech news")
        #expect(voice.briefing?.items.map(\.storyID.rawValue) == ["t1", "t2", "t3"])
        #expect(speaker.lines == [
            "Hi Prakash, what news summary do you want?",
            "Here are the top 3 technology stories.",
            "1. Src: Headline t1", "2. Src: Headline t2", "3. Src: Headline t3"
        ])
        #expect(audio.begins == 1 && audio.ends == 1)
    }

    @Test("A denied permission says nothing and takes no audio")
    func permissionDenied() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([], granted: false), speaker)
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.permissionDenied))
        #expect(speaker.lines.isEmpty)
        #expect(audio.begins == 0)
    }

    @Test("An empty store says the stories are loading")
    func storiesLoading() async {
        let speaker = FakeSpeaker()
        let voice = assistant(FakeListener([]), speaker)
        voice.start(pool: [], readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.storiesLoading))
        #expect(speaker.lines == [VoiceLanguage.english.storiesLoading])
    }

    @Test("Hearing nothing asks once more, then gives up")
    func nothingHeard() async {
        let speaker = FakeSpeaker()
        let listener = FakeListener([.heard(""), .heard("  ")])
        let voice = assistant(listener, speaker)
        voice.start(pool: pool, readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.nothingHeard))
        #expect(listener.languages.count == 2)
        #expect(speaker.lines.filter { $0 == VoiceLanguage.english.didNotCatch }.count == 1)
    }

    @Test("No Hindi recognition switches to English and says so")
    func hindiFallsBackToEnglish() async {
        let speaker = FakeSpeaker()
        let listener = FakeListener([.localeUnavailable, .heard("tech news")])
        let voice = assistant(listener, speaker)
        voice.start(pool: pool, readerName: "", language: .hindi, audio: nil)
        await voice.waitUntilFinished()

        #expect(listener.languages == [.hindi, .english])
        #expect(speaker.lines.contains(VoiceLanguage.hindiRecognitionUnavailable))
        #expect(voice.language == .english)
        #expect(voice.phase == .done)
    }

    @Test("A topic with no stories today reads the newest of everything")
    func emptyCategoryFallsBackToAll() async {
        let voice = assistant(FakeListener([.heard("science news")]), FakeSpeaker())
        voice.start(pool: pool, readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.briefing?.items.count == 4)
        #expect(voice.phase == .done)
    }

    @Test("Stopping mid-briefing reads nothing more and hands back the audio")
    func stopMidBriefing() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([.heard("tech news")]), speaker)
        speaker.onSay = { line in if line.hasPrefix("2.") { voice.stop() } }
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(speaker.lines.last?.hasPrefix("2.") == true)
        #expect(!speaker.lines.contains { $0.hasPrefix("3.") })
        #expect(voice.phase == .done)
        #expect(audio.ends == 1)
    }

    @Test("Starting again mid-run abandons the first run cleanly")
    func restartMidRun() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let listener = FakeListener([.heard("tech news"), .heard("india news")])
        let voice = assistant(listener, speaker)
        var restarted = false
        speaker.onSay = { line in
            if line.hasPrefix("1."), !restarted {
                restarted = true
                voice.start(pool: pool, readerName: "", language: .english, audio: audio)
            }
        }
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()
        // Let the abandoned first run reach its cancellation checks.
        await Task.yield()

        #expect(!speaker.lines.contains("2. Src: Headline t2"))
        #expect(voice.briefing?.items.first?.storyID.rawValue == "i1")
        #expect(voice.phase == .done)
        #expect(audio.begins == 2 && audio.ends == 2)
    }

    @Test("Stopping mid-sentence settles the phase instead of going on to think")
    func stopWhileListening() async {
        let listener = MidSentenceListener()
        let voice = VoiceAssistant(listener: listener, speaker: FakeSpeaker(),
                                   writer: RuleBriefingWriter(translator: NoTranslation()))
        listener.onListening = { voice.stop() }
        voice.start(pool: pool, readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.phase == .idle)
        #expect(!voice.isActive)
        #expect(voice.briefing == nil)
    }

    @Test("An audio interruption mid-briefing stops it and hands back the audio")
    func interruptionStops() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([.heard("tech news")]), speaker)
        speaker.onSay = { line in if line.hasPrefix("2.") { audio.interrupt() } }
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(!speaker.lines.contains { $0.hasPrefix("3.") })
        #expect(voice.phase == .done)
        #expect(audio.ends == 1)
        #expect(audio.onInterruption == nil)
    }
}
