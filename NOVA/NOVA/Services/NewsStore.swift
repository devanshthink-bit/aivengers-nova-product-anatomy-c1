//
//  NewsStore.swift
//  NOVA
//

import Foundation
import Observation

/// Everything the Home tab browses: all stories from all feeds, grouped by source, plus
/// the cache of generated summaries.
///
/// Separate from `DailySession` on purpose. The session owns the *game* — today's five
/// and the round built from them — and browsing deliberately doesn't touch it: reading in
/// Home marks nothing read and unlocks no quiz. Keeping them apart is what stops the
/// round's rules leaking into a list the reader is only skimming.
@Observable
final class NewsStore {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    /// Stories per source page, and the most a source page shows.
    static let storiesPerSource = 15
    /// How many generation requests are allowed in flight at once.
    ///
    /// The endpoint allows roughly 30 requests a minute. Firing all 15 of a source's
    /// stories at once reliably trips that, so they go in chunks.
    static let generationBatchSize = 5

    /// Pause between batches, to stay under the endpoint's ~30 requests a minute.
    static let batchPause = Duration.seconds(2)
    /// Ceiling for the doubling back-off after a rate-limited batch.
    static let maximumBackoff = Duration.seconds(60)

    /// How many of the river's stories get rewritten.
    ///
    /// Twelve rather than the full forty: the first attempt generated the whole river on
    /// Home appearing *and* fifteen more when a source opened, which raced past the rate
    /// limit and left most stories showing the publisher's text verbatim. Only what the
    /// reader is likely to see before scrolling is worth spending the budget on.
    static let riverGenerationLimit = 12

    private(set) var allStories: [Story] = []
    private(set) var loadState: LoadState = .idle

    /// Generated summaries, keyed by story. Cached so reopening a source never pays for
    /// the same rewrite twice — the reader can move between tabs freely.
    private var generatedSummaries: [StoryID: String] = [:]
    /// Stories waiting to be rewritten, and the single worker draining them.
    ///
    /// One queue for the whole app, not one per screen. Home and a source page each used
    /// to start their own pass, so opening a source while the river was still generating
    /// put ~55 requests in flight against a ~30/minute endpoint and nearly all of them
    /// came back unusable.
    private var pending: [Story] = []
    private var worker: Task<Void, Never>?

    private let loader: FeedLoader
    private let generator: QuestionGenerator

    init(loader: FeedLoader = FeedLoader(), generator: QuestionGenerator = QuestionGenerator()) {
        self.loader = loader
        self.generator = generator
    }

    // MARK: - Loading

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading

        let fetched = await loader.fetchAll().sorted { $0.publishedAt > $1.publishedAt }
        guard !fetched.isEmpty else {
            loadState = .failed
            return
        }

        allStories = fetched
        loadState = .loaded
    }

    /// Seeds the store with known stories, skipping the network.
    ///
    /// The seam tests and previews use. The app always goes through `load()`; this exists
    /// so grouping, ordering and capping can be tested without nine live feeds deciding
    /// what the assertions see.
    func adopt(_ stories: [Story]) {
        allStories = stories.sorted { $0.publishedAt > $1.publishedAt }
        loadState = .loaded
    }

    // MARK: - Reading the deck

    /// The sources that actually returned something, in the order `RSSFeed.all` lists
    /// them. A feed that was down contributes no channel rather than an empty one.
    var sources: [RSSFeed] {
        let present = Set(allStories.map(\.source))
        return RSSFeed.all.filter { present.contains($0.source) }
    }

    /// One source's stories, newest first, capped at `storiesPerSource`.
    func stories(from source: String) -> [Story] {
        allStories
            .filter { $0.source == source }
            .prefix(Self.storiesPerSource)
            .map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    /// The merged river for Home, newest first across every source.
    func latest(limit: Int = 40) -> [Story] {
        allStories
            .prefix(limit)
            .map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    func story(withID id: StoryID) -> Story? {
        allStories.first { $0.id == id }.map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    // MARK: - Generation

    /// Rewrites a source's stories, in batches, skipping any already cached.
    ///
    /// Lists render the publisher's own text first and swap to the rewrite as each batch
    /// lands, so opening a source never waits on the network. A story whose generation
    /// fails simply keeps the feed's wording.
    /// A source page's stories go to the front of the queue — that's what the reader is
    /// looking at right now, so it should not wait behind the river.
    func generateSummaries(forSource source: String) {
        let stories = allStories
            .filter { $0.source == source }
            .prefix(Self.storiesPerSource)

        enqueue(Array(stories), front: true)
    }

    /// Same, for the stories at the top of Home's river.
    func generateSummaries(forLatest limit: Int = NewsStore.riverGenerationLimit) {
        enqueue(Array(allStories.prefix(limit)), front: false)
    }

    private func enqueue(_ stories: [Story], front: Bool) {
        let queuedIDs = Set(pending.map(\.id))
        let fresh = stories.filter {
            generatedSummaries[$0.id] == nil && !queuedIDs.contains($0.id)
        }
        guard !fresh.isEmpty else { return }

        if front {
            pending.insert(contentsOf: fresh, at: 0)
        } else {
            pending.append(contentsOf: fresh)
        }

        startWorkerIfNeeded()
    }

    private func startWorkerIfNeeded() {
        guard worker == nil else { return }

        worker = Task { [weak self] in
            defer { self?.worker = nil }

            var backoff = Self.batchPause

            while let batch = self?.nextBatch(), !batch.isEmpty {
                guard let self else { return }
                let result = await generator.generateReporting(for: batch)

                for entry in result.deck where entry.question != nil {
                    // Only cache a usable object. A failed generation hands back the
                    // feed's own text trimmed, and caching that would freeze the story
                    // on its fallback wording forever.
                    generatedSummaries[entry.story.id] = entry.story.summary
                }

                if result.wasRateLimited {
                    // Put the batch back and wait. Dropping it would leave those stories
                    // on feed text for the rest of the session even though the limit is
                    // temporary.
                    self.pending.insert(contentsOf: batch, at: 0)
                    // Prefer the server's own number. It reports windows of several
                    // minutes, which no guessed back-off would have reached.
                    if let retryAfter = result.retryAfter {
                        backoff = .seconds(retryAfter)
                    } else {
                        backoff = Swift.min(backoff * 2, Self.maximumBackoff)
                    }
                } else {
                    backoff = Self.batchPause
                }

                if self.pending.isEmpty { break }
                try? await Task.sleep(for: backoff)
            }
        }
    }

    /// Takes the next batch *and removes it from the queue*. Returning without removing
    /// would spin the worker on the same stories forever.
    private func nextBatch() -> [Story] {
        guard !pending.isEmpty else { return [] }
        let size = Swift.min(Self.generationBatchSize, pending.count)
        let batch = Array(pending.prefix(size))
        pending.removeFirst(size)
        return batch
    }
}

// MARK: - Helpers

extension Story {
    /// The same story with a generated summary swapped in, or unchanged if there isn't
    /// one yet.
    func applying(summary generated: String?) -> Story {
        guard let generated else { return self }
        return Story(
            id: id,
            title: title,
            summary: generated,
            source: source,
            category: category,
            publishedAt: publishedAt,
            artwork: artwork
        )
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
