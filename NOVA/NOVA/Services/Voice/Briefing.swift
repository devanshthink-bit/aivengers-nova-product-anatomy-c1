//
//  Briefing.swift
//  NOVA
//

import Foundation

/// What gets read aloud: an intro, then one line per story.
struct Briefing: Equatable, Sendable {
    enum Tier: String, Equatable, Sendable {
        case zeroAPI, onDevice, rules

        /// A model wrote the lines and nobody has checked them. See CLAUDE.md, Content.
        var isMachineWritten: Bool { self != .rules }
    }

    struct Item: Equatable, Sendable, Identifiable {
        let storyID: StoryID
        let line: String
        var id: StoryID { storyID }
    }

    var intro: String
    var items: [Item]
    var tier: Tier
    /// The language the lines are in. Differs from the reader's choice only on the rules
    /// tier, when Hindi was asked for and no translation pack is installed.
    var lineLanguage: VoiceLanguage

    /// A backstop, not the target: the prompt asks for 15. A model that ignores that
    /// shouldn't be able to read a paragraph per story.
    static let lineWordLimit = 25

    /// Keeps only items that point at a real candidate, once each, up to `limit`.
    ///
    /// Models invent IDs and repeat themselves. A briefing that survives with nothing
    /// in it throws, so the fallback chain moves on instead of reading an intro to silence.
    func validated(against candidates: [Story], limit: Int, defaultIntro: String) throws -> Briefing {
        let known = Set(candidates.map(\.id))
        var seen: Set<StoryID> = []
        var kept: [Item] = []
        for item in items where kept.count < limit {
            let line = item.line
                .replacing(/\s+/, with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, known.contains(item.storyID), seen.insert(item.storyID).inserted else { continue }
            kept.append(Item(storyID: item.storyID, line: line.truncatedToWords(Self.lineWordLimit)))
        }
        guard !kept.isEmpty else { throw BriefingError.noValidItems }

        let intro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        return Briefing(intro: intro.isEmpty ? defaultIntro : intro, items: kept, tier: tier, lineLanguage: lineLanguage)
    }

    /// Stories are offered to models by number, not ID. Feed IDs are often full URLs,
    /// and ten of those would eat the reply's token budget, which Hindi needs more of.
    /// An out-of-range number maps to an empty ID, which validation then drops.
    static func storyID(forNumber number: Int, in candidates: [Story]) -> StoryID {
        candidates.indices.contains(number - 1) ? candidates[number - 1].id : StoryID("")
    }

    /// Decodes the JSON the AI tiers are asked for. Models wrap it in fences or prose
    /// often enough that trimming to the outermost braces beats asking again.
    static func decoding(_ content: String, candidates: [Story], tier: Tier, language: VoiceLanguage) throws -> Briefing {
        guard
            let start = content.firstIndex(of: "{"),
            let end = content.lastIndex(of: "}"),
            start < end
        else { throw BriefingError.notJSON }

        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: Data(content[start...end].utf8))
        } catch {
            throw BriefingError.notJSON
        }
        return Briefing(
            intro: wire.intro ?? "",
            items: wire.items.map { Item(storyID: storyID(forNumber: $0.number, in: candidates), line: $0.line) },
            tier: tier,
            lineLanguage: language
        )
    }

    private struct Wire: Decodable {
        let intro: String?
        let items: [WireItem]
    }

    private struct WireItem: Decodable {
        let number: Int
        let line: String

        enum CodingKeys: String, CodingKey { case id, line }

        /// The prompt asks for a number; models send `2` and `"2"` about equally often.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let number = try? container.decode(Int.self, forKey: .id) {
                self.number = number
            } else {
                let text = try container.decode(String.self, forKey: .id)
                self.number = Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
            }
            line = try container.decode(String.self, forKey: .line)
        }
    }
}

enum BriefingError: Error, Equatable {
    case noStories
    case unavailable
    case noValidItems
    case notJSON
    case badResponse
    case timedOut
}

/// The prompt both AI tiers send, so they're asked for the same thing.
enum BriefingPrompt {
    static func instructions(language: VoiceLanguage, count: Int) -> String {
        let written = language == .hindi ? "Hindi, in Devanagari script" : "English"
        return """
            You are NOVA, a news app, writing a short briefing that will be read aloud.

            Return STRICT JSON and nothing else. No markdown, no code fences, no preamble.

            Shape:
            {"intro": string, "items": [{"id": number, "line": string}]}

            Rules:
            - Choose up to \(count) of the most important stories for what the reader asked for, most important first.
            - "id" is the story's number from the list you are given. Never invent one.
            - "line" is one spoken sentence of at most 15 words: the source, a colon, then what happened.
            - "intro" is one short sentence introducing the briefing.
            - Write "intro" and every "line" in \(written).
            - Use only what the headline says. Never add detail.
            """
    }

    static func request(transcript: String, candidates: [Story]) -> String {
        let list = candidates.enumerated()
            .map { "\($0.offset + 1) | \($0.element.source) | \($0.element.title)" }
            .joined(separator: "\n")
        return """
            The reader said: "\(transcript)"

            Stories (number | source | headline):
            \(list)
            """
    }
}
