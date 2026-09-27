//
//  OnDeviceBriefingWriter.swift
//  NOVA
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The middle tier: Apple's on-device model, used when ZeroAPI is down or rate-limited.
///
/// Free, private and offline, but it only exists on Apple Intelligence phones with it
/// turned on, and its language support moves with the OS. Both are checked at runtime.
/// Anything else throws `.unavailable` and the chain moves on.
struct OnDeviceBriefingWriter: BriefingWriter {
    func brief(request transcript: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        guard !candidates.isEmpty else { throw BriefingError.noStories }
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(language.locale) else {
            throw BriefingError.unavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: BriefingPrompt.instructions(language: language, count: intent.count)
        )
        let response = try await session.respond(
            to: BriefingPrompt.request(transcript: transcript, candidates: candidates),
            generating: GeneratedBriefing.self
        )
        let generated = response.content
        return Briefing(
            intro: generated.intro,
            items: generated.items.map {
                Briefing.Item(storyID: Briefing.storyID(forNumber: $0.id, in: candidates), line: $0.line)
            },
            tier: .onDevice,
            lineLanguage: language
        )
        #else
        throw BriefingError.unavailable
        #endif
    }
}

#if canImport(FoundationModels)
/// Guided generation, so the model returns this shape directly and there is no JSON to
/// trim, unlike the ZeroAPI tier.
@Generable
struct GeneratedBriefing {
    @Guide(description: "One short sentence introducing the briefing")
    var intro: String

    @Guide(description: "The chosen stories, most important first", .maximumCount(10))
    var items: [GeneratedBriefingItem]
}

@Generable
struct GeneratedBriefingItem {
    @Guide(description: "The story's number from the list you were given")
    var id: Int

    @Guide(description: "One spoken sentence of at most 15 words: the source, a colon, then what happened")
    var line: String
}
#endif
