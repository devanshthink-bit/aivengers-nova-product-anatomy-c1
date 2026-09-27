//
//  BriefingWriter.swift
//  NOVA
//

import Foundation

/// Writes the lines a briefing reads. Three tiers conform, from best-sounding to
/// most dependable. See `FallbackBriefingWriter`.
protocol BriefingWriter: Sendable {
    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing
}

/// Runs `work`, giving up with `BriefingError.timedOut` after `limit`.
///
/// Structured, so the abandoned work is cancelled rather than left running, but a
/// task group still waits for it to *notice*. That holds for everything used here:
/// URLSession and the on-device model both stop promptly when cancelled.
func withTimeout<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await work() }
        group.addTask {
            try await Task.sleep(for: limit)
            throw BriefingError.timedOut
        }
        defer { group.cancelAll() }
        guard let first = try await group.next() else { throw BriefingError.timedOut }
        return first
    }
}

/// Tries each writer in order and returns the first briefing that survives validation.
///
/// The order is ZeroAPI, then Apple's on-device model, then rules. ZeroAPI is one
/// person's free project and rate-limits at ~30 requests a minute; the on-device model
/// only exists on Apple Intelligence phones. The rules tier is last because it can't
/// fail, so it is also the only tier with no timeout: cutting off the one tier that
/// must answer would leave the reader with nothing.
struct FallbackBriefingWriter: BriefingWriter {
    var writers: [any BriefingWriter]
    var timeout: Duration = .seconds(8)

    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        let defaultIntro = language.intro(count: min(intent.count, candidates.count), category: intent.category)

        for (index, writer) in writers.enumerated() {
            let isLast = index == writers.count - 1
            do {
                let briefing = isLast
                    ? try await writer.brief(request: request, intent: intent, language: language, candidates: candidates)
                    : try await withTimeout(timeout) {
                        try await writer.brief(request: request, intent: intent, language: language, candidates: candidates)
                    }
                return try briefing.validated(against: candidates, limit: intent.count, defaultIntro: defaultIntro)
            } catch {
                continue
            }
        }
        throw BriefingError.noValidItems
    }
}

extension FallbackBriefingWriter {
    /// What the app uses. Tests build their own chains.
    static let standard = FallbackBriefingWriter(writers: [
        ZeroAPIBriefingWriter(),
        OnDeviceBriefingWriter(),
        RuleBriefingWriter()
    ])
}
