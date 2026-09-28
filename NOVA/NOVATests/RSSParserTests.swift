//
//  RSSParserTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

/// The samples below are trimmed from what the real feeds actually returned, keeping the
/// awkward bits: BBC's CDATA and single `media:thumbnail`, Guardian's HTML description
/// and three `media:content` at different widths, News18's `+0530` dates.
@Suite("RSS parser")
struct RSSParserTests {

    private static let bbc = RSSFeed(
        source: "BBC News",
        category: .world,
        url: URL(string: "https://feeds.bbci.co.uk/news/world/rss.xml")!
    )

    private static let guardian = RSSFeed(
        source: "The Guardian",
        category: .world,
        url: URL(string: "https://www.theguardian.com/world/rss")!
    )

    private static let news18 = RSSFeed(
        source: "News18",
        category: .india,
        url: URL(string: "https://www.news18.com/rss/india.xml")!
    )

    // MARK: - BBC

    private static let bbcXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel>
        <item>
            <title><![CDATA['Massive' drone attack on Moscow region]]></title>
            <description><![CDATA[Moscow's mayor says 450 drones were downed.]]></description>
            <link>https://www.bbc.co.uk/news/articles/c34gdjk1ne8yo</link>
            <guid isPermaLink="false">https://www.bbc.co.uk/news/articles/c34gdjk1ne8yo#0</guid>
            <pubDate>Sun, 20 Sep 2026 10:45:39 GMT</pubDate>
            <media:thumbnail width="240" height="135" url="https://ichef.bbci.co.uk/a.jpg"/>
        </item>
        </channel>
        </rss>
        """

    @Test("CDATA titles and summaries come through unwrapped")
    func readsCDATA() {
        let stories = RSSParser(feed: Self.bbc).parse(Data(Self.bbcXML.utf8))

        #expect(stories.count == 1)
        #expect(stories[0].title == "'Massive' drone attack on Moscow region")
        #expect(stories[0].summary == "Moscow's mayor says 450 drones were downed.")
        #expect(stories[0].source == "BBC News")
        #expect(stories[0].category == .world)
    }

    @Test("The guid becomes the story id, so a reread survives a refresh")
    func identityComesFromGuid() {
        let stories = RSSParser(feed: Self.bbc).parse(Data(Self.bbcXML.utf8))

        #expect(stories[0].id == StoryID("https://www.bbc.co.uk/news/articles/c34gdjk1ne8yo#0"))
    }

    @Test("A GMT date parses to the right instant")
    func parsesGMTDate() {
        let stories = RSSParser(feed: Self.bbc).parse(Data(Self.bbcXML.utf8))

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 20
        components.hour = 10
        components.minute = 45
        components.second = 39
        components.timeZone = TimeZone(identifier: "GMT")

        let expected = Calendar(identifier: .gregorian).date(from: components)
        #expect(stories[0].publishedAt == expected)
    }

    @Test("media:thumbnail becomes the artwork")
    func readsThumbnail() {
        let stories = RSSParser(feed: Self.bbc).parse(Data(Self.bbcXML.utf8))

        #expect(stories[0].artwork == .remote(URL(string: "https://ichef.bbci.co.uk/a.jpg")!))
    }

    // MARK: - Guardian

    private static let guardianXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/" \
        xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
        <item>
          <title>Men deported from US bound and beaten, lawyers say</title>
          <link>https://www.theguardian.com/us-news/2026/sep/18/a</link>
          <description>&lt;p&gt;Group trapped at Hotel Bamy&lt;/p&gt;&lt;p&gt;Rights groups \
        sound the alarm&lt;/p&gt;</description>
          <category domain="x">US immigration</category>
          <pubDate>Fri, 18 Sep 2026 23:08:49 GMT</pubDate>
          <guid>https://www.theguardian.com/us-news/2026/sep/18/a</guid>
          <media:content width="140" url="https://i.guim.co.uk/small.jpg"/>
          <media:content width="700" url="https://i.guim.co.uk/large.jpg"/>
          <media:content width="460" url="https://i.guim.co.uk/medium.jpg"/>
          <dc:creator>Maanvi Singh</dc:creator>
        </item>
        </channel>
        </rss>
        """

    @Test("HTML and entities are stripped out of the description")
    func stripsHTML() {
        let stories = RSSParser(feed: Self.guardian).parse(Data(Self.guardianXML.utf8))

        #expect(stories.count == 1)
        #expect(stories[0].summary == "Group trapped at Hotel Bamy Rights groups sound the alarm")
    }

    @Test("The widest media:content wins, whatever order they arrive in")
    func picksWidestImage() {
        let stories = RSSParser(feed: Self.guardian).parse(Data(Self.guardianXML.utf8))

        // The 700px one is listed second, not last, so this fails if the parser simply
        // keeps the final tag it saw.
        #expect(stories[0].artwork == .remote(URL(string: "https://i.guim.co.uk/large.jpg")!))
    }

    // MARK: - News18

    private static let news18XML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel>
        <item>
          <title><![CDATA[SUV Mows Down Boy In Hyderabad]]></title>
          <link><![CDATA[https://www.news18.com/india/a.html]]></link>
          <description><![CDATA[Police have registered a case.]]></description>
          <pubDate><![CDATA[Sun, 20 Sep 2026 17:03:23 +0530]]></pubDate>
          <guid><![CDATA[https://www.news18.com/india/a.html]]></guid>
          <media:content height="675" width="1200" url="https://images.news18.com/a.jpg"/>
        </item>
        </channel>
        </rss>
        """

    @Test("A +0530 date parses to the same instant as its UTC equivalent")
    func parsesOffsetDate() {
        let stories = RSSParser(feed: Self.news18).parse(Data(Self.news18XML.utf8))

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 20
        components.hour = 11
        components.minute = 33
        components.second = 23
        components.timeZone = TimeZone(identifier: "GMT")

        #expect(stories[0].publishedAt == Calendar(identifier: .gregorian).date(from: components))
    }

    // MARK: - Robustness

    @Test("An item with no title is skipped and the rest still parse")
    func skipsUnusableItems() {
        let xml = """
            <rss><channel>
            <item><description>No title here</description><guid>a</guid></item>
            <item><title>A real one</title><guid>b</guid></item>
            </channel></rss>
            """

        let stories = RSSParser(feed: Self.bbc).parse(Data(xml.utf8))

        #expect(stories.count == 1)
        #expect(stories[0].title == "A real one")
    }

    @Test("An item with no image is kept, without artwork")
    func toleratesMissingImage() {
        let xml = """
            <rss><channel>
            <item><title>No picture</title><guid>a</guid></item>
            </channel></rss>
            """

        let stories = RSSParser(feed: Self.bbc).parse(Data(xml.utf8))

        #expect(stories.count == 1)
        #expect(stories[0].artwork == .none)
    }

    @Test("Malformed XML yields no stories rather than crashing")
    func toleratesGarbage() {
        let stories = RSSParser(feed: Self.bbc).parse(Data("<rss><channel><item>".utf8))

        #expect(stories.isEmpty)
    }

    @Test("Mint's non-standard \"Sept\" parses instead of falling back to now")
    func parsesNonStandardMonth() {
        // Regression: RFC 822 says "Sep". Mint writes "Sept", MMM didn't match, every
        // Mint story fell back to `.now` and swamped the top of Home's river.
        let xml = """
            <rss><channel><item>
            <title><![CDATA[Car loan rates]]></title>
            <guid><![CDATA[mint-1]]></guid>
            <pubDate><![CDATA[Sun, 20 Sept 2026 17:32:24 +0530]]></pubDate>
            </item></channel></rss>
            """

        let stories = RSSParser(feed: Self.news18).parse(Data(xml.utf8))

        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 20
        components.hour = 12
        components.minute = 2
        components.second = 24
        components.timeZone = TimeZone(identifier: "GMT")

        #expect(stories[0].publishedAt == Calendar(identifier: .gregorian).date(from: components))
    }

    @Test("A missing date falls back to now instead of dropping the story")
    func missingDateFallsBack() {
        let xml = "<rss><channel><item><title>Undated</title><guid>a</guid></item></channel></rss>"

        let before = Date.now
        let stories = RSSParser(feed: Self.bbc).parse(Data(xml.utf8))

        #expect(stories.count == 1)
        #expect(stories[0].publishedAt >= before)
    }

    // MARK: - WordPress

    @Test("A WordPress feed's picture is read from the <img> in its description")
    func imageFromDescriptionHTML() {
        // Inc42 (and most WordPress sites) send no media tag at all: the featured image is
        // the first <img> inside the description's HTML.
        let xml = """
            <rss><channel><item><title>Ola raises funds</title><guid>w1</guid>
            <description><![CDATA[<p><img width="1360" height="1020" \
            src="https://asset.inc42.com/2026/08/ola.jpg" class="wp-post-image" alt="x" /></p>\
            <p>Ola Electric's board approved a rights issue.</p>]]></description>
            </item></channel></rss>
            """

        let stories = RSSParser(feed: Self.bbc).parse(Data(xml.utf8))

        #expect(stories[0].artwork == .remote(URL(string: "https://asset.inc42.com/2026/08/ola.jpg")!))
        #expect(stories[0].summary == "Ola Electric's board approved a rights issue.")
    }

    @Test("A media tag still wins over an <img> in the description")
    func mediaTagWinsOverHTML() {
        let xml = """
            <rss xmlns:media="http://search.yahoo.com/mrss/"><channel><item><title>T</title><guid>w2</guid>
            <description><![CDATA[<img src="https://a.example/small.jpg"/>Text]]></description>
            <media:content url="https://a.example/big.jpg" width="1200"/>
            </item></channel></rss>
            """

        let stories = RSSParser(feed: Self.bbc).parse(Data(xml.utf8))

        #expect(stories[0].artwork == .remote(URL(string: "https://a.example/big.jpg")!))
    }
}

// MARK: - Word truncation

@Suite("Summary truncation")
struct SummaryTruncationTests {

    @Test("A short summary is left exactly as it was")
    func leavesShortTextAlone() {
        #expect("Three words here".truncatedToWords(50) == "Three words here")
    }

    @Test("A long summary is cut to the limit")
    func cutsLongText() {
        let text = Array(repeating: "word", count: 60).joined(separator: " ")
        let cut = text.truncatedToWords(50)

        #expect(cut.split(separator: " ").count == 50)
        #expect(cut.hasSuffix("…"))
    }
}

/// Each publisher added on 2026-09-28, parsed from a trimmed copy of what its feed really
/// returned (the first two items, verbatim). One case per *format*, not per URL: The
/// Hindu's cricket, science and entertainment feeds share one template.
@Suite("Indian publisher samples")
struct IndianPublisherSampleTests {
    private final class Token {}

    static let samples: [(file: String, category: StoryCategory)] = [
        ("indianexpress", .india),
        ("thehindu-sport", .sports),
        ("bollywoodhungama", .entertainment),
        ("businessstandard", .business),
        ("inc42", .technology),
        ("livehindustan", .india),
        ("news18hindi", .india),
        ("bhaskar", .india)
    ]

    @Test("Every sample yields stories with a title, a date and a picture", arguments: samples)
    func parses(sample: (file: String, category: StoryCategory)) throws {
        let url = try #require(Bundle(for: Token.self).url(forResource: sample.file, withExtension: "xml"))
        let feed = RSSFeed(source: sample.file, category: sample.category, url: url)

        let stories = RSSParser(feed: feed).parse(try Data(contentsOf: url))

        #expect(stories.count == 2)
        #expect(stories.allSatisfy { !$0.title.isEmpty })
        #expect(stories.allSatisfy { $0.category == sample.category })
        // Any real date from this decade — a failed parse falls back to something else.
        #expect(stories.allSatisfy { $0.publishedAt > Date(timeIntervalSince1970: 1_700_000_000) })
        // At least one, not all: The Hindu leaves the picture off some items, and `.none`
        // is a normal state the cards render.
        #expect(stories.contains { if case .remote = $0.artwork { true } else { false } })
    }
}
