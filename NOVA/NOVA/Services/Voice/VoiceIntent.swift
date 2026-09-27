//
//  VoiceIntent.swift
//  NOVA
//

import Foundation

/// What the reader asked for, read from what they said.
///
/// Keyword tables rather than a model: this has to work when both AI tiers are down,
/// and every tier uses it as the category filter, so the stories on offer match
/// the topic the reader named whichever tier writes the lines.
struct VoiceIntent: Equatable, Sendable {
    static let maximumCount = 10

    /// nil means every category.
    var category: StoryCategory?
    var count: Int = VoiceIntent.maximumCount

    static func parse(_ transcript: String) -> VoiceIntent {
        let words = normalisedWords(in: transcript)
        // Whole words only: "ai" must not match inside "said".
        let padded = " " + words.joined(separator: " ") + " "
        let category = categoryOrder.first { category in
            keywords[category, default: []].contains { padded.contains(" \($0) ") }
        }
        return VoiceIntent(category: category, count: count(in: words) ?? maximumCount)
    }

    // MARK: - Topics

    /// Narrow topics first, so "India's tech sector" is technology and "world markets" is
    /// business. India and world are the broadest, so they only win when nothing else does.
    private static let categoryOrder: [StoryCategory] = [.technology, .science, .business, .india, .world]

    /// Hindi recognition often writes English loanwords in Devanagari ("टेक", "बिज़नेस"),
    /// so both scripts are listed.
    private static let keywords: [StoryCategory: [String]] = [
        .technology: ["tech", "technology", "technologies", "ai", "artificial intelligence", "gadget", "gadgets",
                      "software", "internet", "cyber", "टेक", "तकनीक", "तकनीकी", "प्रौद्योगिकी", "टेक्नोलॉजी"],
        .science: ["science", "scientific", "space", "research", "climate", "health", "medicine",
                   "विज्ञान", "साइंस", "अंतरिक्ष", "स्वास्थ्य"],
        .business: ["business", "market", "markets", "economy", "economic", "finance", "financial", "stock",
                    "stocks", "money", "company", "companies", "startup", "startups", "व्यापार", "बिज़नेस",
                    "बिजनेस", "बाज़ार", "बाजार", "अर्थव्यवस्था", "शेयर", "कारोबार"],
        .india: ["india", "indian", "national", "domestic", "delhi", "mumbai", "भारत", "देश", "इंडिया", "राष्ट्रीय"],
        .world: ["world", "international", "global", "foreign", "abroad", "दुनिया", "विदेश", "विदेशी",
                 "अंतरराष्ट्रीय", "विश्व"]
    ]

    // MARK: - Counts

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "एक": 1, "दो": 2, "तीन": 3, "चार": 4, "पाँच": 5, "पांच": 5,
        "छह": 6, "छः": 6, "सात": 7, "आठ": 8, "नौ": 9, "दस": 10
    ]

    /// Words that make a number word a count. Without this, "एक बात बताओ" ("tell me one
    /// thing") would cut the briefing to a single story: "एक" is also Hindi's "a".
    private static let countContext: Set<String> = [
        "stories", "story", "headlines", "headline", "news", "updates", "biggest", "latest",
        "खबरें", "खबर", "समाचार", "हेडलाइन", "हेडलाइंस", "मुख्य", "बड़ी"
    ]

    private static func count(in words: [String]) -> Int? {
        for (index, word) in words.enumerated() {
            // Digits are unambiguous wherever they appear.
            if let digits = Int(word) { return clamp(digits) }
            guard let value = numberWords[word] else { continue }
            let previous = index > 0 ? words[index - 1] : ""
            let next = index + 1 < words.count ? words[index + 1] : ""
            if previous == "top" || next == "top" || countContext.contains(next) {
                return clamp(value)
            }
        }
        return nil
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, 1), maximumCount)
    }

    /// Lowercased words, with Devanagari digits (०…९) turned into ASCII: Hindi
    /// recognition can return either, and `Int` only reads ASCII.
    private static func normalisedWords(in transcript: String) -> [String] {
        var scalars = String.UnicodeScalarView()
        for scalar in transcript.lowercased().unicodeScalars {
            if (0x0966...0x096F).contains(scalar.value),
               let ascii = Unicode.Scalar(scalar.value - 0x0966 + 0x30) {
                scalars.append(ascii)
            } else {
                scalars.append(scalar)
            }
        }
        // `alphanumerics` includes combining marks, so Devanagari vowel signs stay
        // attached to their words.
        return String(scalars)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
