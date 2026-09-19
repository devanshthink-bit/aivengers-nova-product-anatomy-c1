//
//  Identifiers.swift
//  NOVA
//

import Foundation

/// Typed identifiers so a story id can never be passed where a question id is expected.
/// They encode as plain strings, which keeps the models Codable-friendly.
struct StoryID: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }
}

struct QuestionID: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }
}

struct RoundID: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) { self.rawValue = rawValue }
    init(_ rawValue: String) { self.rawValue = rawValue }
}
