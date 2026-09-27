//
//  Highlights.swift
//  NOVA
//

import Foundation

/// Which stories a briefing chooses from.
///
/// From the whole store rather than today's five-card deck: a briefing needs ten, and
/// the deck deliberately holds one per category.
enum Highlights {
    /// What the AI tiers choose from. Enough to pick ten important ones out of, small
    /// enough to keep the prompt cheap on a free endpoint.
    static let aiCandidateLimit = 40

    static func candidates(for intent: VoiceIntent, from pool: [Story], limit: Int) -> [Story] {
        var seen: Set<String> = []
        var picked: [Story] = []
        for story in pool.sorted(by: { $0.publishedAt > $1.publishedAt }) {
            guard picked.count < limit else { break }
            if let category = intent.category, story.category != category { continue }
            // BBC and The Guardian often carry the same wire story under the same headline.
            guard seen.insert(story.title.lowercased()).inserted else { continue }
            picked.append(story)
        }
        return picked
    }
}
