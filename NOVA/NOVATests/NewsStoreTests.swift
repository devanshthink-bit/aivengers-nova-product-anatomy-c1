//
//  NewsStoreTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("News store")
struct NewsStoreTests {

    /// Builds a store holding known stories without touching the network, by pointing the
    /// loader at feeds that cannot resolve and injecting the stories directly.
    private func store(with stories: [Story]) async -> NewsStore {
        let store = NewsStore(loader: FeedLoader(feeds: []))
        await store.adopt(stories)
        return store
    }

    private func story(
        _ id: String,
        source: String,
        category: StoryCategory = .world,
        hoursAgo: Double = 0,
        summary: String = "Feed summary."
    ) -> Story {
        Story(
            id: StoryID(id),
            title: "Title \(id)",
            summary: summary,
            source: source,
            category: category,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
            artwork: .none
        )
    }

    @Test("A source page shows only that source's stories, newest first")
    func groupsBySource() async {
        let store = await store(with: [
            story("a", source: "BBC News", hoursAgo: 3),
            story("b", source: "The Hindu", hoursAgo: 1),
            story("c", source: "BBC News", hoursAgo: 1)
        ])

        let bbc = store.stories(from: "BBC News")

        #expect(bbc.map(\.id) == [StoryID("c"), StoryID("a")])
    }

    @Test("A source page is capped at fifteen stories")
    func capsAtFifteen() async {
        let many = (1...40).map { story("s\($0)", source: "BBC News", hoursAgo: Double($0)) }
        let store = await store(with: many)

        #expect(store.stories(from: "BBC News").count == NewsStore.storiesPerSource)
    }

    @Test("A publisher with several section feeds is one channel on the rail")
    func sectionFeedsAreOneChannel() async {
        let store = await store(with: [
            story("a", source: "Live Hindustan", category: .india),
            story("b", source: "Live Hindustan", category: .sports)
        ])

        #expect(store.sources.map(\.source) == ["Live Hindustan"])
    }

    @Test("Switching to the language already loaded keeps the stories")
    func sameLanguageIsANoOp() async {
        let store = await store(with: [story("a", source: "BBC News")])

        await store.setLanguage(.english)

        #expect(store.allStories.map(\.id) == [StoryID("a")])
    }

    @Test("Switching language drops the other language's stories")
    func languageSwitchClears() async {
        let store = await store(with: [story("a", source: "BBC News")])

        await store.setLanguage(.hindi)

        // Loader points at no feeds, so the reload finds nothing — what matters is that no
        // English story survives into a Hindi day.
        #expect(store.allStories.isEmpty)
    }

    @Test("Filtering by category keeps newest-first and the limit")
    func latestByCategory() async {
        let store = await store(with: [
            story("a", source: "S", category: .sports, hoursAgo: 1),
            story("b", source: "S", category: .india, hoursAgo: 2),
            story("c", source: "S", category: .sports, hoursAgo: 3)
        ])

        #expect(store.latest(category: .sports).map(\.id.rawValue) == ["a", "c"])
        #expect(store.latest(limit: 1, category: .sports).count == 1)
        #expect(store.latest().count == 3)
    }

    @Test("Only categories that arrived are listed, chosen ones first")
    func categoriesListOnlyPresent() async {
        let store = await store(with: [
            story("a", source: "S", category: .world),
            story("b", source: "S", category: .sports),
            story("c", source: "S", category: .india)
        ])

        let listed = store.categories(ordered: TopicSelection(categories: [.sports]))

        #expect(listed.first == .sports)
        #expect(Set(listed) == [.world, .sports, .india])
        #expect(!listed.contains(.science))
    }

    @Test("A chosen tab that stopped arriving resolves to All, whenever it is read")
    func selectionFallsBackToAll() {
        #expect(NewsStore.resolvedCategory(.science, among: [.india, .sports]) == nil)
        #expect(NewsStore.resolvedCategory(.sports, among: [.india, .sports]) == .sports)
        #expect(NewsStore.resolvedCategory(nil, among: [.india]) == nil)
    }

    @Test("The rail lists only sources that actually returned stories")
    func railSkipsEmptySources() async {
        let store = await store(with: [
            story("a", source: "BBC News"),
            story("b", source: "NDTV")
        ])

        let names = store.sources.map(\.source)

        #expect(names.contains("BBC News"))
        #expect(names.contains("NDTV"))
        #expect(names.contains("The Guardian") == false)
    }

    @Test("The rail keeps the order RSSFeed.all declares, not arrival order")
    func railOrderIsStable() async {
        // Feeds finish in whatever order the network returns them, so ordering by
        // arrival would reshuffle the rail on every refresh.
        let store = await store(with: [
            story("a", source: "BBC News"),
            story("b", source: "The Hindu")
        ])

        let expected = RSSFeed.all
            .map(\.source)
            .filter { $0 == "BBC News" || $0 == "The Hindu" }

        #expect(store.sources.map(\.source) == expected)
    }

    @Test("The latest river merges every source, newest first")
    func riverIsMerged() async {
        let store = await store(with: [
            story("old", source: "BBC News", hoursAgo: 5),
            story("new", source: "NDTV", hoursAgo: 1),
            story("mid", source: "The Hindu", hoursAgo: 3)
        ])

        #expect(store.latest().map(\.id) == [StoryID("new"), StoryID("mid"), StoryID("old")])
    }

    @Test("The river honours its limit")
    func riverRespectsLimit() async {
        let many = (1...40).map { story("s\($0)", source: "BBC News", hoursAgo: Double($0)) }
        let store = await store(with: many)

        #expect(store.latest(limit: 10).count == 10)
    }

    @Test("Without a generated summary, the feed's own text is shown")
    func fallsBackToFeedText() async {
        let store = await store(with: [story("a", source: "BBC News", summary: "Feed wording.")])

        #expect(store.stories(from: "BBC News").first?.summary == "Feed wording.")
    }

    @Test("A story can be looked up by id for the detail view")
    func findsStoryByID() async {
        let store = await store(with: [story("a", source: "BBC News")])

        #expect(store.story(withID: StoryID("a"))?.title == "Title a")
        #expect(store.story(withID: StoryID("missing")) == nil)
    }

    @Test("An unknown source yields an empty page rather than a crash")
    func unknownSourceIsEmpty() async {
        let store = await store(with: [story("a", source: "BBC News")])

        #expect(store.stories(from: "Nonexistent Times").isEmpty)
    }
}

// MARK: - Chunking

@Suite("Batching")
struct ChunkingTests {

    @Test("Generation batches never exceed the size limit")
    func chunksToSize() {
        // 15 stories at 5 per batch is what keeps a source page under the endpoint's
        // ~30/min ceiling.
        let chunks = Array(1...15).chunked(into: 5)

        #expect(chunks.count == 3)
        #expect(chunks.allSatisfy { $0.count <= 5 })
        #expect(chunks.flatMap { $0 } == Array(1...15))
    }

    @Test("A partial final batch is kept")
    func keepsRemainder() {
        let chunks = Array(1...7).chunked(into: 5)

        #expect(chunks.map(\.count) == [5, 2])
    }

    @Test("An empty list produces no batches")
    func emptyProducesNothing() {
        #expect([Int]().chunked(into: 5).isEmpty)
    }
}

// MARK: - Worker cancellation

@Suite("News store worker")
struct NewsStoreWorkerTests {
    /// Counts calls and always reports a rate limit, so a healthy worker backs off for
    /// seconds between batches — and a worker that ignores cancellation spins instead.
    ///
    /// Each batch takes 200 ms in a cancellable sleep, the way a real request in a
    /// cancelled task fails early: that is what lets the test cancel *mid-batch*, which is
    /// the case that spun. Cancelling during the back-off sleep always exited cleanly.
    final class CountingGenerator: SummaryGenerating, @unchecked Sendable {
        var language: ContentLanguage = .english
        var calls = 0

        func generateReporting(for stories: [Story]) async -> QuestionGenerator.BatchResult {
            calls += 1
            try? await Task.sleep(for: .milliseconds(200))
            return QuestionGenerator.BatchResult(
                deck: stories.map { ($0, nil) },
                wasRateLimited: true,
                retryAfter: nil
            )
        }
    }

    @Test("Switching language stops the summary worker instead of leaving it spinning")
    func languageSwitchStopsWorker() async throws {
        let generator = CountingGenerator()
        let store = NewsStore(loader: FeedLoader(feeds: []), generator: generator)
        store.adopt((1...5).map { index in
            Story(id: StoryID("s\(index)"), title: "T\(index)", summary: "S", source: "BBC News",
                  category: .world, publishedAt: .now, artwork: .none)
        })

        store.generateSummaries()
        for _ in 0..<50 where generator.calls == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(generator.calls >= 1)

        await store.setLanguage(.hindi)
        try await Task.sleep(for: .milliseconds(100))
        let settled = generator.calls
        try await Task.sleep(for: .milliseconds(300))

        // A cancelled worker whose `Task.sleep` returns at once would have called the
        // generator hundreds of times in 300 ms.
        #expect(generator.calls == settled)
        #expect(store.isGenerating == false)
    }

    @Test("A cancelled load leaves the store idle rather than failed")
    func cancelledLoadIsNotAFailure() async {
        let store = NewsStore(loader: FeedLoader(feeds: []), generator: CountingGenerator())

        let task = Task { await store.load() }
        task.cancel()
        await task.value

        #expect(store.loadState != .failed)
    }
}
