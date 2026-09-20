//
//  NewsServiceTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Story selection")
struct StorySelectionTests {

    private func story(
        _ id: String,
        _ category: StoryCategory,
        title: String? = nil,
        hoursAgo: Double = 0
    ) -> Story {
        Story(
            id: StoryID(id),
            title: title ?? "Story \(id)",
            summary: "Summary \(id)",
            source: "Test",
            category: category,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
            artwork: .none
        )
    }

    @Test("The deck takes one story per category")
    func spreadsAcrossCategories() {
        let pool = [
            story("a", .india, hoursAgo: 1),
            story("b", .india, hoursAgo: 2),
            story("c", .world, hoursAgo: 3),
            story("d", .technology, hoursAgo: 4),
            story("e", .business, hoursAgo: 5),
            story("f", .science, hoursAgo: 6)
        ]

        let picked = LiveNewsService.pick(from: pool)

        #expect(picked.count == 5)
        #expect(Set(picked.map(\.category)).count == 5)
    }

    @Test("Newer stories win within a category")
    func prefersTheNewest() {
        let pool = [
            story("old", .india, hoursAgo: 10),
            story("new", .india, hoursAgo: 1)
        ]

        let picked = LiveNewsService.pick(from: pool)

        #expect(picked.first?.id == StoryID("new"))
    }

    @Test("The same story from two publishers only appears once")
    func dedupesByTitle() {
        // The same wire story runs under different guids at different publishers. Two
        // cards about one event would make the deck look broken.
        let pool = [
            story("bbc", .world, title: "Drone attack on Moscow", hoursAgo: 1),
            story("aje", .india, title: "drone attack on moscow", hoursAgo: 2)
        ]

        let picked = LiveNewsService.pick(from: pool)

        #expect(picked.count == 1)
    }

    @Test("Too few categories still fills the deck")
    func topsUpWhenCategoriesRunOut() {
        // Most feeds being down is routine. A four-card round would break the quiz, so
        // selection falls back to the next newest regardless of category.
        let pool = (1...8).map { story("s\($0)", .india, hoursAgo: Double($0)) }

        let picked = LiveNewsService.pick(from: pool)

        #expect(picked.count == 5)
        #expect(Set(picked.map(\.id)).count == 5)
    }

    @Test("An empty pool yields an empty deck rather than crashing")
    func handlesEmptyPool() {
        #expect(LiveNewsService.pick(from: []).isEmpty)
    }
}

// MARK: - Loading into the session

@Suite("Session loading")
struct SessionLoadingTests {

    /// Serves a fixed deck, so loading can be tested without a network.
    private struct StubService: NewsService {
        var deck: [(story: Story, question: Question?)]
        var error: Error?

        func todayDeck() async throws -> [(story: Story, question: Question?)] {
            if let error { throw error }
            return deck
        }
    }

    private func story(_ id: String, _ category: StoryCategory) -> Story {
        Story(
            id: StoryID(id),
            title: "Story \(id)",
            summary: "Summary \(id)",
            source: "Test",
            category: category,
            publishedAt: .now,
            artwork: .none
        )
    }

    private func question(for story: Story) -> Question {
        Question(
            id: QuestionID("q-\(story.id.rawValue)"),
            storyID: story.id,
            prompt: "Prompt?",
            answers: ["a", "b"],
            correctAnswerIndex: 0
        )
    }

    @Test("A successful load replaces the deck")
    func loadReplacesTheDeck() async {
        let live = [story("live-1", .world), story("live-2", .india)]
        let session = DailySession()
        let service = StubService(deck: live.map { ($0, question(for: $0)) })

        await session.load(from: service)

        #expect(session.loadState == .loaded)
        #expect(session.stories.map(\.id) == live.map(\.id))
        #expect(session.questions.count == 2)
    }

    @Test("Chosen topics still lead the deck after a live load")
    func topicsSurviveLoading() async {
        // Regression: applyTopics used to reorder MockNewsService.todayStories rather
        // than the loaded deck. RootView calls it on every launch, so a live deck would
        // have been silently replaced by the demo content.
        let live = [story("world", .world), story("india", .india)]
        let session = DailySession()
        let service = StubService(deck: live.map { ($0, question(for: $0)) })

        await session.load(from: service)
        session.applyTopics(TopicSelection(categories: [.india]))

        #expect(session.stories.first?.id == StoryID("india"))
        #expect(session.stories.count == 2)
        #expect(session.stories.allSatisfy { $0.source == "Test" })
    }

    @Test("Applying topics twice does not keep reshuffling the deck")
    func reorderingIsStable() async {
        let live = [story("world", .world), story("india", .india), story("tech", .technology)]
        let session = DailySession()
        let service = StubService(deck: live.map { ($0, question(for: $0)) })

        await session.load(from: service)
        session.applyTopics(TopicSelection(categories: [.india]))
        let once = session.stories.map(\.id)
        session.applyTopics(TopicSelection(categories: [.india]))

        #expect(session.stories.map(\.id) == once)
    }

    @Test("A failed load keeps the stories already on screen")
    func failureKeepsTheExistingDeck() async {
        let session = DailySession()
        let before = session.stories.map(\.id)

        await session.load(from: StubService(deck: [], error: NewsServiceError.noStories))

        #expect(session.loadState == .failed)
        #expect(session.stories.map(\.id) == before)
    }

    @Test("An empty deck counts as a failure, not a successful empty day")
    func emptyDeckFails() async {
        let session = DailySession()

        await session.load(from: StubService(deck: []))

        #expect(session.loadState == .failed)
    }

    @Test("A story with no question still reads, but is not asked about")
    func storiesWithoutQuestionsStayInTheDeck() async {
        let withQuestion = story("a", .world)
        let without = story("b", .india)
        let session = DailySession()
        let service = StubService(deck: [
            (withQuestion, question(for: withQuestion)),
            (without, nil)
        ])

        await session.load(from: service)

        #expect(session.stories.count == 2)
        #expect(session.questions.count == 1)
        #expect(session.engine.round.questionIDs.count == 1)
        #expect(session.engine.round.storyIDs == [withQuestion.id])
    }
}
