//
//  TopicSelection.swift
//  NOVA
//

import Foundation

/// The categories the reader asked to see first.
///
/// Stored as a plain string so it can live in `@AppStorage`, which has no set type. The
/// encoding is deliberately forgiving: anything it doesn't recognise is dropped rather
/// than crashing a reader whose stored value predates a category being renamed.
struct TopicSelection: Equatable, Sendable {
    /// Below this the flow won't move on. Two is enough to be a preference without
    /// making the reader do inventory.
    static let minimum = 2

    private(set) var categories: Set<StoryCategory>

    init(categories: Set<StoryCategory> = []) {
        self.categories = categories
    }

    init(rawValue: String) {
        self.categories = Set(
            rawValue
                .split(separator: ",")
                .compactMap { StoryCategory(rawValue: String($0)) }
        )
    }

    /// Sorted so the same selection always encodes to the same string, which keeps
    /// `@AppStorage` from reporting a change when nothing changed.
    var rawValue: String {
        categories
            .map(\.rawValue)
            .sorted()
            .joined(separator: ",")
    }

    var count: Int { categories.count }

    var isComplete: Bool { count >= Self.minimum }

    /// How many more are needed before the flow will move on.
    var remaining: Int { max(Self.minimum - count, 0) }

    func contains(_ category: StoryCategory) -> Bool {
        categories.contains(category)
    }

    mutating func toggle(_ category: StoryCategory) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }
}

extension Array where Element == Story {
    /// The same stories with the chosen categories moved to the front.
    ///
    /// Chosen or not, every story stays in the deck: the round needs all five, and the
    /// welcome copy promises the reader still sees everything. Order within each group is
    /// preserved, so an empty or complete selection leaves the deck exactly as it was.
    func leading(with selection: TopicSelection) -> [Story] {
        guard !selection.categories.isEmpty else { return self }
        let chosen = filter { selection.contains($0.category) }
        let rest = filter { !selection.contains($0.category) }
        return chosen + rest
    }
}
