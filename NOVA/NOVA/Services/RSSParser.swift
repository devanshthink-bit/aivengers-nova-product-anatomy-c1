//
//  RSSParser.swift
//  NOVA
//

import Foundation

/// Turns one feed's XML into `Story` values.
///
/// No networking, so the awkward parts — CDATA, three different image tags, four date
/// formats — are testable against checked-in samples of the real feeds.
///
/// Everything here is defensive on purpose. A feed that changes shape should cost us the
/// items we can't read, never the whole deck, so an item missing a title or a link is
/// skipped and the rest still come through.
struct RSSParser {
    let feed: RSSFeed

    func parse(_ data: Data) -> [Story] {
        let delegate = Delegate(feed: feed)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        // Guardian and NDTV both use media: and dc: prefixes. Without this, element
        // names arrive prefixed and every image lookup silently misses.
        parser.shouldProcessNamespaces = false
        guard parser.parse() else { return delegate.stories }
        return delegate.stories
    }
}

// MARK: - Delegate

private final class Delegate: NSObject, XMLParserDelegate {
    private let feed: RSSFeed
    private(set) var stories: [Story] = []

    /// Atom calls it `entry`, RSS calls it `item`. Ars Technica emits both in one
    /// document, so tracking which one opened is what keeps them from interleaving.
    private var itemElement: String?
    private var text = ""
    private var item = PartialItem()

    init(feed: RSSFeed) {
        self.feed = feed
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?,
        attributes: [String: String]
    ) {
        let name = elementName.lowercased()

        if name == "item" || name == "entry" {
            itemElement = name
            item = PartialItem()
            text = ""
            return
        }

        guard itemElement != nil else { return }
        text = ""

        switch name {
        case "media:thumbnail", "media:content", "enclosure":
            // Guardian sends three media:content per item at 140/460/700px. Keeping the
            // widest is what stops a 140px thumbnail being stretched across a full card.
            if let url = attributes["url"].flatMap(URL.init(string:)) {
                let width = attributes["width"].flatMap(Int.init) ?? 0
                if width >= item.imageWidth {
                    item.imageURL = url
                    item.imageWidth = width
                }
            }
        case "link":
            // Atom puts the URL in an href attribute rather than in the element body.
            if let href = attributes["href"], !href.isEmpty {
                item.link = href
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    /// BBC, NDTV and News18 wrap title, description and link in CDATA; Guardian doesn't.
    /// Both callbacks have to feed the same buffer or half the feeds come back empty.
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        text += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName: String?
    ) {
        let name = elementName.lowercased()
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if name == itemElement {
            if let story = item.story(in: feed) {
                stories.append(story)
            }
            itemElement = nil
            text = ""
            return
        }

        guard itemElement != nil else { return }

        switch name {
        case "title": item.title = value
        case "description", "summary": item.summary = value
        case "content:encoded": if item.summary.isEmpty { item.summary = value }
        case "link": if item.link.isEmpty { item.link = value }
        case "guid", "id": item.guid = value
        case "pubdate", "published", "updated", "dc:date": item.date = value
        default: break
        }

        text = ""
    }
}

// MARK: - Assembling an item

private struct PartialItem {
    var title = ""
    var summary = ""
    var link = ""
    var guid = ""
    var date = ""
    var imageURL: URL?
    var imageWidth = -1

    func story(in feed: RSSFeed) -> Story? {
        let cleanTitle = title.strippingHTML
        guard !cleanTitle.isEmpty else { return nil }

        // The guid is stable across refetches where a generated id wouldn't be, so a
        // story the reader already opened stays read after the next refresh. Falling back
        // to the link keeps feeds without a guid usable.
        let identity = guid.isEmpty ? link : guid
        guard !identity.isEmpty else { return nil }

        return Story(
            id: StoryID(identity),
            title: cleanTitle,
            summary: summary.strippingHTML,
            source: feed.source,
            category: feed.category,
            publishedAt: Self.date(from: date) ?? .now,
            artwork: Artwork(url: imageURL)
        )
    }

    /// Real feeds disagree about dates: BBC sends `GMT`, The Hindu and NDTV `+0530`,
    /// Al Jazeera `+0000`, ESPN the non-standard `EST`, and Atom feeds ISO 8601.
    /// An unparseable date falls back to "now" at the call site rather than dropping an
    /// otherwise perfectly good story.
    static func date(from raw: String) -> Date? {
        guard !raw.isEmpty else { return nil }
        let normalised = normalisingMonth(raw)

        for formatter in formatters {
            if let date = formatter.date(from: normalised) { return date }
        }
        return iso8601.date(from: normalised) ?? iso8601WithoutFractional.date(from: normalised)
    }

    /// Fixes month spellings that aren't RFC 822.
    ///
    /// Mint writes "Sept" where the spec says "Sep". `MMM` doesn't match it, so every
    /// Mint story failed to parse, fell back to "now", and — because the river sorts
    /// newest first — took over the top of Home claiming to be one second old.
    private static func normalisingMonth(_ raw: String) -> String {
        var text = raw
        for (nonStandard, standard) in [
            ("Sept", "Sep"), ("June", "Jun"), ("July", "Jul")
        ] {
            text = text.replacingOccurrences(of: " \(nonStandard) ", with: " \(standard) ")
        }
        return text
    }

    private static let formatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm Z",
        "yyyy-MM-dd'T'HH:mm:ssZ"
    ].map { format in
        let formatter = DateFormatter()
        // Fixed POSIX locale: without it a device set to a non-Gregorian calendar or a
        // non-English locale fails to parse English month names and every date is "now".
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }

    private static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso8601WithoutFractional = ISO8601DateFormatter()
}

// MARK: - HTML

extension String {
    /// Guardian descriptions are `<p>`-wrapped markup and most feeds carry entities.
    ///
    /// Deliberately not `NSAttributedString(html:)`: that has to be called on the main
    /// actor and spins up a WebKit parse per item, which is far too heavy for the ~150
    /// items a deck build reads.
    var strippingHTML: String {
        let withoutTags = replacing(/<[^>]+>/, with: " ")

        let entities = [
            "&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
            "&apos;": "'", "&#39;": "'", "&nbsp;": " ", "&hellip;": "…",
            "&mdash;": "—", "&ndash;": "–", "&rsquo;": "’", "&lsquo;": "‘",
            "&ldquo;": "“", "&rdquo;": "”"
        ]
        let decoded = entities.reduce(withoutTags) { text, entity in
            text.replacingOccurrences(of: entity.key, with: entity.value)
        }

        return decoded
            .replacing(/\s+/, with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// First `limit` words, used when a card has to fall back to the feed's own summary.
    func truncatedToWords(_ limit: Int) -> String {
        let words = split(separator: " ")
        guard words.count > limit else { return self }
        return words.prefix(limit).joined(separator: " ") + "…"
    }
}
