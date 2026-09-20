//
//  QuestionGeneratorTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Question generation")
struct QuestionGeneratorTests {

    private func story(_ id: String, summary: String) -> Story {
        Story(
            id: StoryID(id),
            title: "Headline \(id)",
            summary: summary,
            source: "Test",
            category: .world,
            publishedAt: .now,
            artwork: .none
        )
    }

    /// Points the generator at a host that cannot resolve, which is the closest stand-in
    /// for ZeroAPI being down — the case the whole fallback exists for.
    private var offlineGenerator: QuestionGenerator {
        var generator = QuestionGenerator()
        generator.endpoint = URL(string: "https://nova-tests.invalid/api/ai")!

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        generator.session = URLSession(configuration: configuration)

        return generator
    }

    @Test("With the generator unreachable, every story still comes back readable")
    func fallsBackWhenOffline() async {
        let long = Array(repeating: "word", count: 80).joined(separator: " ")
        let stories = [story("a", summary: long), story("b", summary: "Short summary.")]

        let deck = await offlineGenerator.generate(for: stories)

        #expect(deck.count == 2)
        // No questions, but the deck survives — a round short its questions still reads.
        #expect(deck.allSatisfy { $0.question == nil })
        #expect(deck.map(\.story.id) == stories.map(\.id))
    }

    @Test("The fallback summary is trimmed to the card's word limit")
    func fallbackTrimsLongSummaries() async {
        let long = Array(repeating: "word", count: 80).joined(separator: " ")

        let deck = await offlineGenerator.generate(for: [story("a", summary: long)])

        let words = deck[0].story.summary.split(separator: " ").count
        #expect(words <= QuestionGenerator.summaryWordLimit)
    }

    @Test("A summary already short enough is left alone")
    func fallbackLeavesShortSummaries() async {
        let deck = await offlineGenerator.generate(for: [story("a", summary: "Short summary.")])

        #expect(deck[0].story.summary == "Short summary.")
    }

    @Test("Order is preserved even though the requests run concurrently")
    func preservesOrder() async {
        let stories = (1...5).map { story("s\($0)", summary: "Summary \($0).") }

        let deck = await offlineGenerator.generate(for: stories)

        #expect(deck.map(\.story.id) == stories.map(\.id))
    }

    @Test("No stories means no work and no crash")
    func handlesEmptyInput() async {
        let deck = await offlineGenerator.generate(for: [])

        #expect(deck.isEmpty)
    }
}
