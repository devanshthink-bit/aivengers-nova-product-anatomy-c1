//
//  BriefingTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, _ category: StoryCategory = .technology,
                   title: String? = nil, hoursAgo: Double = 0) -> Story {
    Story(
        id: StoryID(id),
        title: title ?? "Headline \(id)",
        summary: "Summary \(id)",
        source: "Source \(id)",
        category: category,
        publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
        artwork: .none
    )
}

@Suite("Highlights")
struct HighlightsTests {

    @Test("Candidates are one category, newest first, capped")
    func filtersAndSorts() {
        let pool = [
            story("old", hoursAgo: 5), story("india", .india, hoursAgo: 0),
            story("new", hoursAgo: 1), story("mid", hoursAgo: 3)
        ]
        let picked = Highlights.candidates(for: VoiceIntent(category: .technology), from: pool, limit: 2)
        #expect(picked.map(\.id.rawValue) == ["new", "mid"])
    }

    @Test("No category takes everything")
    func allCategories() {
        let pool = [story("a", .india, hoursAgo: 1), story("b", .world, hoursAgo: 0)]
        #expect(Highlights.candidates(for: VoiceIntent(category: nil), from: pool, limit: 10).map(\.id.rawValue) == ["b", "a"])
    }

    @Test("The same headline from two feeds is read once")
    func dedupes() {
        let pool = [story("a", title: "Chip ships", hoursAgo: 0), story("b", title: "CHIP SHIPS", hoursAgo: 1)]
        #expect(Highlights.candidates(for: VoiceIntent(category: nil), from: pool, limit: 10).count == 1)
    }
}

@Suite("Briefing")
struct BriefingTests {

    private let candidates = [story("a"), story("b"), story("c")]

    private func briefing(_ items: [(String, String)], intro: String = "Intro") -> Briefing {
        Briefing(intro: intro,
                 items: items.map { Briefing.Item(storyID: StoryID($0.0), line: $0.1) },
                 tier: .zeroAPI, lineLanguage: .english)
    }

    @Test("Validation drops unknown, repeated and empty items, and caps the count")
    func validationDropsBadItems() throws {
        let raw = briefing([("a", "One"), ("zzz", "Made up"), ("a", "Again"), ("b", "   "), ("c", "Three"), ("b", "Two")])
        let valid = try raw.validated(against: candidates, limit: 2, defaultIntro: "Default")
        #expect(valid.items.map(\.storyID.rawValue) == ["a", "c"])
        #expect(valid.items.map(\.line) == ["One", "Three"])
        #expect(valid.intro == "Intro")
    }

    @Test("A briefing with nothing valid is a failure")
    func nothingValid() {
        #expect(throws: BriefingError.noValidItems) {
            try briefing([("zzz", "Made up")]).validated(against: candidates, limit: 10, defaultIntro: "D")
        }
    }

    @Test("An empty intro is replaced")
    func defaultIntro() throws {
        let valid = try briefing([("a", "One")], intro: " ").validated(against: candidates, limit: 10, defaultIntro: "Default")
        #expect(valid.intro == "Default")
    }

    @Test("JSON wrapped in prose decodes, and story numbers map to IDs")
    func decodesWrappedJSON() throws {
        let content = """
        Sure! ```json
        {"intro": "Here you go.", "items": [{"id": "2", "line": "Source b: thing"}, {"id": 1, "line": "Source a: other"}, {"id": 9, "line": "Nope"}]}
        ```
        """
        let decoded = try Briefing.decoding(content, candidates: candidates, tier: .zeroAPI, language: .english)
        #expect(decoded.intro == "Here you go.")
        #expect(decoded.items.map(\.storyID.rawValue) == ["b", "a", ""])
        let valid = try decoded.validated(against: candidates, limit: 10, defaultIntro: "D")
        #expect(valid.items.count == 2)
    }

    @Test("Text without JSON is rejected")
    func rejectsProse() {
        #expect(throws: BriefingError.notJSON) {
            try Briefing.decoding("I can't help with that.", candidates: candidates, tier: .zeroAPI, language: .english)
        }
    }

    @Test("The prompt numbers stories from one")
    func promptNumbers() {
        let prompt = BriefingPrompt.request(transcript: "tech news", candidates: candidates)
        #expect(prompt.contains("1 | Source a | Headline a"))
        #expect(prompt.contains("3 | Source c | Headline c"))
        #expect(prompt.contains("\"tech news\""))
        #expect(BriefingPrompt.instructions(language: .hindi, count: 10).contains("Devanagari"))
    }
}
