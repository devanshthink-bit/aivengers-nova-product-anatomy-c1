//
//  RSSFeed.swift
//  NOVA
//

import Foundation

/// One publisher feed and the category its items belong to.
///
/// The category is fixed per feed rather than read from the item, because the `<category>`
/// tags real feeds emit don't agree with each other: Guardian sends eight free-text
/// categories per item, News18 sends one, and BBC sends none. Pinning it to the feed is
/// the only way `StoryCategory` stays meaningful across nine publishers.
struct RSSFeed: Identifiable, Hashable, Sendable {
    let source: String
    let category: StoryCategory
    let url: URL

    var id: URL { url }
}

extension RSSFeed {
    /// The feeds NOVA reads. Every URL here was fetched and confirmed to return items
    /// before it was added — several widely-recommended feeds are quietly dead and are
    /// listed at the bottom so they don't get re-added.
    static let all: [RSSFeed] = [
        // India
        RSSFeed(
            source: "The Hindu",
            category: .india,
            url: URL(string: "https://www.thehindu.com/news/national/feeder/default.rss")!
        ),
        RSSFeed(
            source: "NDTV",
            category: .india,
            url: URL(string: "https://feeds.feedburner.com/ndtvnews-top-stories")!
        ),
        RSSFeed(
            source: "News18",
            category: .india,
            url: URL(string: "https://www.news18.com/rss/india.xml")!
        ),

        // World
        RSSFeed(
            source: "BBC News",
            category: .world,
            url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!
        ),
        RSSFeed(
            source: "The Guardian",
            category: .world,
            url: URL(string: "https://www.theguardian.com/world/rss")!
        ),
        RSSFeed(
            source: "Al Jazeera",
            category: .world,
            url: URL(string: "https://www.aljazeera.com/xml/rss/all.xml")!
        ),

        // Technology
        RSSFeed(
            source: "BBC Technology",
            category: .technology,
            url: URL(string: "https://feeds.bbci.co.uk/news/technology/rss.xml")!
        ),
        RSSFeed(
            source: "Ars Technica",
            category: .technology,
            url: URL(string: "https://feeds.arstechnica.com/arstechnica/index")!
        ),

        // Business
        RSSFeed(
            source: "BBC Business",
            category: .business,
            url: URL(string: "https://feeds.bbci.co.uk/news/business/rss.xml")!
        ),
        RSSFeed(
            source: "Mint",
            category: .business,
            url: URL(string: "https://www.livemint.com/rss/money")!
        ),

        // Science
        RSSFeed(
            source: "BBC Science",
            category: .science,
            url: URL(string: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")!
        )
    ]

    // Checked and rejected, so they don't come back:
    //   Reuters  — feeds.reuters.com stopped resolving; RSS was retired in 2020.
    //   AP       — no public feed at all; the RSSHub mirror answers 403.
    //   Scroll.in, The Wire — /feed and /rss both return an HTML page, not XML.
    //   Firstpost — /feed answers 404.
    //   Economic Times — works, but returns zero images, which leaves a bare card.
    //   CNBC top stories — works, but it is a general news feed, so pinning it to
    //     .business labelled a Ukraine war story "Business" on the very first run.
    //     A feed only earns a category if everything in it belongs there.
    //   Nature, ScienceDaily — good science, but neither returns a single image.
}
