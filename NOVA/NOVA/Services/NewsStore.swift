//
//  NewsStore.swift
//  NOVA
//

import Foundation
import Observation

/// What the store needs from a generator: a batch of rewrites, and whether it was
/// rate-limited. A protocol so tests can count calls and hold a batch mid-flight.
protocol SummaryGenerating: Sendable {
    var language: ContentLanguage { get set }
    func generateReporting(for stories: [Story]) async -> QuestionGenerator.BatchResult
}

extension QuestionGenerator: SummaryGenerating {}

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
    /// Which worker `worker` is. A cancelled worker's `defer` must not clear the handle of
    /// the one that replaced it, or a third would start beside the second.
    private var workerID = UUID()

    private var loader: FeedLoader
    private var generator: any SummaryGenerating

    /// Whether a rewrite worker is running.
    var isGenerating: Bool { worker != nil }

    init(loader: FeedLoader = FeedLoader(), generator: any SummaryGenerating = QuestionGenerator()) {
        self.loader = loader
        self.generator = generator
    }

    // MARK: - Loading

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading

        let fetched = await loader.fetchAll().sorted { $0.publishedAt > $1.publishedAt }
        // A load cancelled by a language switch fetched nothing because it was cancelled,
        // not because the feeds are down; reporting `.failed` would flash the error screen
        // under the load that replaced it.
        guard !Task.isCancelled else {
            loadState = .idle
            return
        }
        guard !fetched.isEmpty else {
            loadState = .failed
            return
        }

        allStories = fetched
        loadState = .loaded
    }

    /// Swaps the news language and reloads.
    ///
    /// Cached summaries and queued rewrites go with the stories they belonged to: a rewrite
    /// of an English story must not land after the reader has moved to a Hindi day. The
    /// same language twice is a no-op, since `RootView` calls this on every launch.
    func setLanguage(_ language: ContentLanguage) async {
        guard loader.language != language || allStories.isEmpty else { return }
        loader.language = language
        generator.language = language
        worker?.cancel()
        worker = nil
        pending = []
        generatedSummaries = [:]
        allStories = []
        loadState = .idle
        await load()
    }

    /// Seeds the store with known stories, skipping the network.
    ///
    /// The seam tests and previews use. The app always goes through `load()`; this exists
    /// so grouping, ordering and capping can be tested without live feeds deciding
    /// what the assertions see.
    func adopt(_ stories: [Story]) {
        allStories = stories.sorted { $0.publishedAt > $1.publishedAt }
        loadState = .loaded
    }

    // MARK: - Reading the deck

    /// The sources that actually returned something, in the order `RSSFeed.all` lists
    /// them. A feed that was down contributes no channel rather than an empty one.
    ///
    /// One entry per source name: Live Hindustan, News18 Hindi and Dainik Bhaskar each
    /// arrive as several section feeds, and a reader thinks of a publisher as one channel.
    var sources: [RSSFeed] {
        let present = Set(allStories.map(\.source))
        var seen: Set<String> = []
        return RSSFeed.all.filter { present.contains($0.source) && seen.insert($0.source).inserted }
    }

    /// One source's stories, newest first, capped at `storiesPerSource`.
    func stories(from source: String) -> [Story] {
        allStories
            .filter { $0.source == source }
            .prefix(Self.storiesPerSource)
            .map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    /// The merged river for Home, newest first across every source.
    ///
    /// Optionally one category's, for Home's category tabs.
    func latest(limit: Int = 40, category: StoryCategory? = nil) -> [Story] {
        allStories
            .filter { category == nil || $0.category == category }
            .prefix(limit)
            .map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    /// The tab actually in force: the chosen one if it is still offered, All otherwise.
    ///
    /// Computed wherever it is read, rather than reset by an `onChange`: the reset used to
    /// live in the pinned tab header, which isn't alive while Home is off-screen, so a
    /// language switch from Profile could leave Home on an empty "Science" river.
    static func resolvedCategory(_ selection: StoryCategory?, among available: [StoryCategory]) -> StoryCategory? {
        selection.flatMap { available.contains($0) ? $0 : nil }
    }

    /// The categories Home can offer a tab for: only those some feed actually returned —
    /// Science has no Hindi feed, and any feed can be down — in the reader's topic order.
    func categories(ordered topics: TopicSelection) -> [StoryCategory] {
        let present = Set(allStories.map(\.category))
        let base = StoryCategory.allCases.filter(present.contains)
        return base.filter(topics.contains) + base.filter { !topics.contains($0) }
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

    /// Same, for the stories at the top of Home's river — or of one category tab, which
    /// jumps the queue because it is what the reader just asked to see.
    func generateSummaries(
        forLatest limit: Int = NewsStore.riverGenerationLimit,
        category: StoryCategory? = nil
    ) {
        let stories = allStories.filter { category == nil || $0.category == category }
        enqueue(Array(stories.prefix(limit)), front: category != nil)
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

        let id = UUID()
        workerID = id
        worker = Task { [weak self] in
            defer {
                if self?.workerID == id { self?.worker = nil }
            }

            var backoff = Self.batchPause

            // Cancellation is checked by hand. A cancelled task's requests fail at once and
            // read as a rate limit, which put the batch back; `Task.sleep` then returned
            // immediately, so a worker cancelled mid-batch by a language switch spun
            // forever — thousands of calls a second, some reaching ZeroAPI for real.
            while !Task.isCancelled, let batch = self?.nextBatch(), !batch.isEmpty {
                guard let self else { return }
                let result = await generator.generateReporting(for: batch)
                guard !Task.isCancelled else { return }

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
