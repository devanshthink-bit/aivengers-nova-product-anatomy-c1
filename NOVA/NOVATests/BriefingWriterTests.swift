//
//  BriefingWriterTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, title: String? = nil, hoursAgo: Double = 0) -> Story {
    Story(
        id: StoryID(id),
        title: title ?? "Headline \(id)",
        summary: "Summary \(id)",
        source: "Source \(id)",
        category: .technology,
        publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
        artwork: .none
    )
}

private let pool = [story("a"), story("b", hoursAgo: 1), story("c", hoursAgo: 2)]
private let intent = VoiceIntent(category: .technology, count: 10)

private struct StubWriter: BriefingWriter {
    enum Behaviour: Sendable {
        case fail
        case hang
        case answer(Briefing.Tier, ids: [String], after: Duration = .zero)
    }

    let behaviour: Behaviour

    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        switch behaviour {
        case .fail:
            throw BriefingError.unavailable
        case .hang:
            try await Task.sleep(for: .seconds(60))
            throw BriefingError.timedOut
        case .answer(let tier, let ids, let delay):
            if delay > .zero { try await Task.sleep(for: delay) }
            return Briefing(intro: "", items: ids.map { .init(storyID: StoryID($0), line: "Line \($0)") },
                            tier: tier, lineLanguage: language)
        }
    }
}

private struct FixedTranslator: HeadlineTranslating {
    let result: [String]?
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? { result }
}

@Suite("Fallback briefing writer")
struct FallbackBriefingWriterTests {

    private func run(_ writers: [StubWriter], timeout: Duration = .milliseconds(200)) async throws -> Briefing {
        try await FallbackBriefingWriter(writers: writers, timeout: timeout)
            .brief(request: "tech", intent: intent, language: .english, candidates: pool)
    }

    @Test("The first tier that answers wins")
    func firstWins() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["a"])),
                                      .init(behaviour: .answer(.rules, ids: ["b"]))])
        #expect(briefing.tier == .zeroAPI)
    }

    @Test("A failing tier falls through to the next")
    func failureFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .fail), .init(behaviour: .answer(.onDevice, ids: ["a"]))])
        #expect(briefing.tier == .onDevice)
    }

    @Test("A hanging tier is abandoned after the timeout")
    func hangFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .hang), .init(behaviour: .answer(.rules, ids: ["a"]))])
        #expect(briefing.tier == .rules)
    }

    @Test("A tier whose items are all invalid falls through")
    func invalidBriefingFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["made-up"])),
                                      .init(behaviour: .answer(.rules, ids: ["c"]))])
        #expect(briefing.tier == .rules)
        #expect(briefing.items.map(\.storyID.rawValue) == ["c"])
    }

    @Test("The last tier is never timed out, because it is the one that must answer")
    func lastTierNotTimed() async throws {
        let briefing = try await run([.init(behaviour: .fail),
                                      .init(behaviour: .answer(.rules, ids: ["a"], after: .milliseconds(400)))],
                                     timeout: .milliseconds(100))
        #expect(briefing.tier == .rules)
    }

    @Test("Every tier failing throws")
    func allFail() async {
        await #expect(throws: BriefingError.noValidItems) {
            try await run([.init(behaviour: .fail), .init(behaviour: .fail)])
        }
    }

    @Test("A missing intro is filled from the language")
    func fillsIntro() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["a", "b"]))])
        #expect(briefing.intro == "Here are the top 3 technology stories.")
    }
}

@Suite("Rule briefing writer")
struct RuleBriefingWriterTests {

    @Test("Lines are source and headline, newest first, up to the count")
    func englishLines() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: nil))
        let briefing = try await writer.brief(request: "", intent: VoiceIntent(category: .technology, count: 2),
                                              language: .english, candidates: pool)
        #expect(briefing.items.map(\.line) == ["Source a: Headline a", "Source b: Headline b"])
        #expect(briefing.intro == "Here are the top 2 technology stories.")
        #expect(briefing.tier == .rules)
        #expect(briefing.lineLanguage == .english)
    }

    @Test("Long headlines are cut to twelve words")
    func trimsTitles() async throws {
        let long = story("x", title: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen")
        let briefing = try await RuleBriefingWriter(translator: FixedTranslator(result: nil))
            .brief(request: "", intent: intent, language: .english, candidates: [long])
        #expect(briefing.items.first?.line == "Source x: one two three four five six seven eight nine ten eleven twelve…")
    }

    @Test("Hindi uses the translation when there is one")
    func hindiTranslated() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: ["क", "ख", "ग"]))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.items.map(\.line) == ["क", "ख", "ग"])
        #expect(briefing.lineLanguage == .hindi)
    }

    @Test("Hindi without a translation reads English lines and says so")
    func hindiUntranslated() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: nil))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.lineLanguage == .english)
        #expect(briefing.intro.hasSuffix(VoiceLanguage.headlinesInEnglish))
    }

    @Test("A translation of the wrong length is ignored")
    func partialTranslation() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: ["क"]))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.lineLanguage == .english)
    }

    @Test("An empty pool is the one thing it can't brief")
    func emptyPool() async {
        await #expect(throws: BriefingError.noStories) {
            try await RuleBriefingWriter(translator: FixedTranslator(result: nil))
                .brief(request: "", intent: intent, language: .english, candidates: [])
        }
    }
}

@Suite("AI briefing tiers")
struct AIBriefingTierTests {

    /// A host that can't resolve: the closest stand-in for ZeroAPI being down, the same
    /// trick `QuestionGeneratorTests` uses.
    private var offlineZeroAPI: ZeroAPIBriefingWriter {
        var writer = ZeroAPIBriefingWriter()
        writer.endpoint = URL(string: "https://nova-tests.invalid/api/ai")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        writer.session = URLSession(configuration: configuration)
        return writer
    }

    @Test("ZeroAPI being down throws rather than inventing a briefing")
    func zeroAPIOfflineThrows() async {
        await #expect(throws: (any Error).self) {
            try await offlineZeroAPI.brief(request: "tech", intent: intent, language: .english, candidates: pool)
        }
    }

    @Test("With ZeroAPI down, the chain still briefs from the rules")
    func chainSurvivesOutage() async throws {
        let chain = FallbackBriefingWriter(writers: [offlineZeroAPI, RuleBriefingWriter(translator: FixedTranslator(result: nil))])
        let briefing = try await chain.brief(request: "tech", intent: intent, language: .english, candidates: pool)
        #expect(briefing.tier == .rules)
        #expect(briefing.items.count == 3)
    }

    @Test("The on-device tier refuses an empty pool whether or not the model exists")
    func onDeviceEmptyPool() async {
        await #expect(throws: (any Error).self) {
            try await OnDeviceBriefingWriter().brief(request: "tech", intent: intent, language: .english, candidates: [])
        }
    }
}
