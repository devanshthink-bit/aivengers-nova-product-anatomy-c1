//
//  ShareGrid.swift
//  NOVA
//

import Foundation

/// The round as text a chat app can carry without an image: one square per question.
///
/// Marigold squares because marigold is what a sunk shot earns in the app, white for a
/// miss. It says only what happened — no rank, no percentile — because there is no
/// leaderboard to back one up.
enum ShareGrid {
    static func text(outcomes: [Bool], date: Date, streak: Int, locale: Locale = .current) -> String {
        let day = date.formatted(Date.FormatStyle(locale: locale).day().month(.abbreviated))
        let squares = outcomes.map { $0 ? "🟨" : "⬜" }.joined()
        var lines = [
            "NOVA · \(day)",
            "\(squares) \(outcomes.filter { $0 }.count)/\(outcomes.count)"
        ]
        if streak > 0 {
            lines.append(String(localized: "🔥 \(streak)-day streak"))
        }
        return lines.joined(separator: "\n")
    }
}
