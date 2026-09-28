//
//  ContentLanguage.swift
//  NOVA
//

import Foundation

/// The language the news itself arrives in: which feeds are read and what the generator
/// writes. Separate from the app's own UI language, which iOS owns (Settings → NOVA →
/// Language) — an in-app override would have to thread `\.locale` through every view and
/// still miss `String(localized:)` in non-view code.
enum ContentLanguage: String, CaseIterable, Codable, Sendable {
    case english = "en"
    case hindi = "hi"

    static let storageKey = "contentLanguage"

    /// Written in its own script, so a reader who can't read the other one still finds theirs.
    var nativeName: String {
        switch self {
        case .english: "English"
        case .hindi: "हिन्दी"
        }
    }

    var voice: VoiceLanguage {
        switch self {
        case .english: .english
        case .hindi: .hindi
        }
    }

    /// Hindi when the phone's first language is Hindi, English otherwise — the same rule
    /// `VoiceLanguage.preferred` uses, so the two never disagree on first launch.
    static func preferred(from languages: [String] = Locale.preferredLanguages) -> ContentLanguage {
        languages.first?.hasPrefix("hi") == true ? .hindi : .english
    }
}
