//
//  NewsService.swift
//  NOVA
//

import Foundation

/// Where a day's stories and questions come from.
///
/// The protocol exists so previews and tests keep using `MockNewsService` — hand-authored
/// content, no network, deterministic — while the app reads live feeds.
protocol NewsService: Sendable {
    /// Today's deck, already summarised, paired with a question each where one could be
    /// written. A story with a `nil` question still belongs in the deck: the reader can
    /// read it, it just won't be asked about.
    func todayDeck() async throws -> [(story: Story, question: Question?)]
}

// MARK: - Live

/// Reads the feeds in `RSSFeed.all`, picks the day's stories, and has
/// `QuestionGenerator` write the summary and question for each.
/// Fetches and parses the feeds. Split out from `LiveNewsService` because both the round
/// and the Home tab need the same stories, and fetching nine feeds twice on launch would
/// be eighteen requests for one screenful of news.
struct FeedLoader: Sendable {
    var feeds: [RSSFeed] = RSSFeed.all
    var session: URLSession = .shared

    /// Fetches every feed at once. A feed that fails contributes nothing and is not an
    /// error — with nine publishers, one being down is routine, and waiting on it or
    /// failing the whole load because of it would be the wrong trade.
    func fetchAll() async -> [Story] {
        await withTaskGroup(of: [Story].self) { group in
            for feed in feeds {
                group.addTask {
                    do {
                        var request = URLRequest(url: feed.url)
                        request.timeoutInterval = 12
                        // Some publishers (notably the CDN in front of Al Jazeera) answer
                        // 403 to a request with no User-Agent.
                        request.setValue("NOVA/1.0", forHTTPHeaderField: "User-Agent")

                        let (data, response) = try await session.data(for: request)
                        guard
                            let http = response as? HTTPURLResponse,
                            (200..<300).contains(http.statusCode)
                        else { return [] }

                        return RSSParser(feed: feed).parse(data)
                    } catch {
                        return []
                    }
                }
            }

            var all: [Story] = []
            for await stories in group { all.append(contentsOf: stories) }
            return all
        }
    }
}

struct LiveNewsService: NewsService {
    /// One per category, so the onboarding topic reorder has something to reorder and
    /// `StoryCategory` stays represented. Matches the five the round already expects.
    static let storyCount = 5

    var loader = FeedLoader()
    var generator = QuestionGenerator()

    /// Stories already fetched by `NewsStore`, so the round doesn't refetch the same nine
    /// feeds the Home tab just read. Nil means fetch them here.
    var prefetched: [Story]?

    func todayDeck() async throws -> [(story: Story, question: Question?)] {
        // Not `prefetched ?? await …`: `??` autocloses its right side, which can't be
        // async. The explicit branch is the only spelling that compiles.
        let fetched: [Story]
        if let prefetched {
            fetched = prefetched
        } else {
            fetched = await loader.fetchAll()
        }
        guard !fetched.isEmpty else { throw NewsServiceError.noStories }
        return await generator.generate(for: Self.pick(from: fetched))
    }

    /// Newest first, deduplicated, at most one per category.
    ///
    /// Deduplication is by title rather than by id: the same wire story runs under
    /// different guids at different publishers, and two cards about the same event would
    /// make the deck feel broken.
    static func pick(from stories: [Story]) -> [Story] {
        var seenTitles: Set<String> = []
        let unique = stories
            .sorted { $0.publishedAt > $1.publishedAt }
            .filter { story in
                let key = story.title.lowercased()
                return seenTitles.insert(key).inserted
            }

        var chosen: [Story] = []
        var usedCategories: Set<StoryCategory> = []

        for story in unique where !usedCategories.contains(story.category) {
            chosen.append(story)
            usedCategories.insert(story.category)
            if chosen.count == storyCount { return chosen }
        }

        // Fewer categories came back than the deck needs — top up with the next newest
        // rather than shipping a short round.
        for story in unique where !chosen.contains(where: { $0.id == story.id }) {
            chosen.append(story)
            if chosen.count == storyCount { break }
        }

        return chosen
    }
}

enum NewsServiceError: Error {
    /// Every feed failed or returned nothing — almost always no network.
    case noStories
}

// MARK: - Mock

/// Serves `MockNewsService`'s hand-authored content through the protocol.
///
/// A separate type because `MockNewsService` is a case-less enum used as a namespace —
/// it has no instances, so it can't conform to anything with instance requirements.
struct PreviewNewsService: NewsService {
    var stories: [Story] = MockNewsService.todayStories
    var questions: [Question] = MockNewsService.todayQuestions

    func todayDeck() async throws -> [(story: Story, question: Question?)] {
        stories.map { story in
            (story, questions.first { $0.storyID == story.id })
        }
    }
}
