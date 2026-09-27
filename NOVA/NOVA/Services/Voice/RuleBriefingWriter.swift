//
//  RuleBriefingWriter.swift
//  NOVA
//

import Foundation
#if canImport(Translation)
import Translation
#endif

/// The tier that can't fail: newest stories, read as "source: headline".
///
/// It can't judge importance, so it doesn't pretend to. Newest first is at least honest.
/// This is what stands between an outage and a silent button.
struct RuleBriefingWriter: BriefingWriter {
    /// Twelve words fit one breath and still carry the story.
    static let titleWordLimit = 12

    var translator: any HeadlineTranslating = HeadlineTranslator()

    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        let picked = Array(candidates.prefix(intent.count))
        guard !picked.isEmpty else { throw BriefingError.noStories }

        var lines = picked.map { "\($0.source): \($0.title.truncatedToWords(Self.titleWordLimit))" }
        var lineLanguage = language
        var intro = language.intro(count: picked.count, category: intent.category)

        if language == .hindi {
            if let translated = await translator.translate(lines, to: .hindi), translated.count == lines.count {
                lines = translated
            } else {
                // Better an English headline said plainly than none. The intro stays in Hindi
                // and warns the reader, and each line is spoken in the English voice so
                // it isn't mangled.
                lineLanguage = .english
                intro += " " + VoiceLanguage.headlinesInEnglish
            }
        }

        return Briefing(
            intro: intro,
            items: zip(picked, lines).map { Briefing.Item(storyID: $0.id, line: $1) },
            tier: .rules,
            lineLanguage: lineLanguage
        )
    }
}

protocol HeadlineTranslating: Sendable {
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]?
}

/// English → Hindi with Apple's on-device Translation framework. Free and offline.
///
/// Only when the language pack is **already installed**. A download prompt in the middle
/// of a spoken conversation would strand the reader, so a missing pack returns nil and
/// the rules tier reads English instead.
struct HeadlineTranslator: HeadlineTranslating {
    static let timeout: Duration = .seconds(4)

    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? {
        guard language == .hindi, !lines.isEmpty else { return nil }
        // The rules tier has no timeout of its own, so this one is what keeps it dependable.
        let result = try? await withTimeout(Self.timeout) { await Self.translateToHindi(lines) }
        return result ?? nil
    }

    private static func translateToHindi(_ lines: [String]) async -> [String]? {
        #if canImport(Translation)
        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: "hi")
        guard await LanguageAvailability().status(from: source, to: target) == .installed else { return nil }

        let session = TranslationSession(installedSource: source, target: target)
        let requests = lines.enumerated().map {
            TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
        }
        guard let responses = try? await session.translations(from: requests) else { return nil }

        // Matched by identifier rather than trusting the order to come back unchanged.
        var byIndex: [Int: String] = [:]
        for response in responses {
            if let id = response.clientIdentifier, let index = Int(id) { byIndex[index] = response.targetText }
        }
        let translated = lines.indices.compactMap { byIndex[$0] }
        return translated.count == lines.count ? translated : nil
        #else
        return nil
        #endif
    }
}
