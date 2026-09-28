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
/// the only way `StoryCategory` stays meaningful across every publisher.
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
        RSSFeed(
            source: "Indian Express",
            category: .india,
            url: URL(string: "https://indianexpress.com/section/india/feed/")!
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
        RSSFeed(
            source: "Inc42",
            category: .technology,
            url: URL(string: "https://inc42.com/feed/")!
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
        RSSFeed(
            source: "Business Standard",
            category: .business,
            url: URL(string: "https://www.business-standard.com/rss/markets-106.rss")!
        ),

        // Science
        RSSFeed(
            source: "BBC Science",
            category: .science,
            url: URL(string: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")!
        ),
        RSSFeed(
            source: "The Hindu Science",
            category: .science,
            url: URL(string: "https://www.thehindu.com/sci-tech/science/feeder/default.rss")!
        ),

        // Sports — cricket first, because that is what an Indian reader opens a sports
        // page for; Indian Express covers the rest of the Indian sporting calendar.
        RSSFeed(
            source: "The Hindu Cricket",
            category: .sports,
            url: URL(string: "https://www.thehindu.com/sport/cricket/feeder/default.rss")!
        ),
        RSSFeed(
            source: "Indian Express Sports",
            category: .sports,
            url: URL(string: "https://indianexpress.com/section/sports/feed/")!
        ),

        // Entertainment
        RSSFeed(
            source: "The Hindu Entertainment",
            category: .entertainment,
            url: URL(string: "https://www.thehindu.com/entertainment/feeder/default.rss")!
        ),
        RSSFeed(
            source: "Bollywood Hungama",
            category: .entertainment,
            url: URL(string: "https://www.bollywoodhungama.com/rss/news.xml")!
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
    //
    // Checked on 2026-09-28, looking for Indian and Hindi sources:
    //   BBC Hindi — every section URL (india, international, science-technology) serves
    //     the same mixed feed, so no category can be pinned to it.
    //   NDTV India, ABP Live Hindi — one feed mixing politics, Bollywood and cricket.
    //   Aaj Tak, Amar Ujala, Moneycontrol, PIB — work, but return no images.
    //   Jagran, Navbharat Times, Down To Earth, The Hindu explainers — 404.
    //   ThePrint — /feed returns an HTML page.  DD News — timed out.
    //   YourStory — personal-finance advice mixed in with startup news.
    //   MediaNama — one image in ten items.  IE Explained — mixes every category.
    //   ESPNcricinfo — works, but mostly English county cricket.
    //   BBC Tamil, Bengali, Marathi, Telugu — all work; kept for a regional-language pass.
}
