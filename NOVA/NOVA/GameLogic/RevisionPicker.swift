//
//  RevisionPicker.swift
//  NOVA
//

import Foundation

/// Which archived questions a revision round asks, in order.
///
/// Wrong answers first — that's what revision is for — then whatever has gone longest
/// without being looked at. Ties break by id so the same archive always gives the same
/// round, which keeps both the tests and the reader's sense of the order stable.
enum RevisionPicker {
    static let size = 10

    static func pick(from entries: [ArchivedAnswer], limit: Int = size) -> [ArchivedAnswer] {
        let ordered = entries.sorted { a, b in
            if a.lastCorrect != b.lastCorrect { return !a.lastCorrect }
            let aSeen = a.lastRevisedAt ?? a.answeredAt
            let bSeen = b.lastRevisedAt ?? b.answeredAt
            if aSeen != bSeen { return aSeen < bSeen }
            return a.id.rawValue < b.id.rawValue
        }
        return Array(ordered.prefix(limit))
    }
}
