//
//  LocalizationTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Hindi localisation")
struct LocalizationTests {
    private var hindi: Bundle? {
        Bundle.main.path(forResource: "hi", ofType: "lproj").flatMap(Bundle.init(path:))
    }

    @Test("The app ships a Hindi localisation")
    func bundleExists() {
        #expect(hindi != nil)
    }

    @Test("Key screens' words are translated", arguments: [
        "Home", "Profile", "Prep", "Headlines", "Channels", "Start reading", "Continue", "Share",
        "India", "Sports", "Revise what you read.", "Daily reminder"
    ])
    func translated(key: String) throws {
        let bundle = try #require(hindi)
        let value = bundle.localizedString(forKey: key, value: "∅", table: nil)

        #expect(value != "∅")
        #expect(value != key)
    }

    @Test("Category names reach the catalog rather than rendering verbatim")
    func categoryTitlesAreLocalizable() throws {
        let bundle = try #require(hindi)

        // The suite runs in English, so each title is its own catalog key.
        for category in StoryCategory.allCases {
            #expect(bundle.localizedString(forKey: category.title, value: "∅", table: nil) != "∅")
        }
    }

    @Test("Meta labels drop mono and tracking in Devanagari, keep them in English")
    func metaLabelsFollowScript() {
        #expect(Nova.metaStyle(forLocalization: "hi") == .init(monospaced: false, tracking: 0))
        #expect(Nova.metaStyle(forLocalization: "en") == .init(monospaced: true, tracking: 1.2))
        #expect(Nova.metaStyle(forLocalization: nil) == .init(monospaced: true, tracking: 1.2))
    }
}
