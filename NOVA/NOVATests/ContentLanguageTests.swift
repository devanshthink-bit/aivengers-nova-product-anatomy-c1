//
//  ContentLanguageTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Content language")
struct ContentLanguageTests {
    @Test("Hindi phones default to Hindi news, everything else to English")
    func preferred() {
        #expect(ContentLanguage.preferred(from: ["hi-IN", "en-IN"]) == .hindi)
        #expect(ContentLanguage.preferred(from: ["en-IN", "hi-IN"]) == .english)
        #expect(ContentLanguage.preferred(from: []) == .english)
    }

    @Test("Each language reads only its own feeds, and neither is empty")
    func feedsAreSplitByLanguage() {
        for language in ContentLanguage.allCases {
            let feeds = RSSFeed.feeds(for: language)
            #expect(!feeds.isEmpty)
            #expect(feeds.allSatisfy { $0.language == language })
        }
    }

    @Test("Hindi covers every category except science, which no Hindi feed passed")
    func hindiCoverage() {
        let covered = Set(RSSFeed.feeds(for: .hindi).map(\.category))
        #expect(covered == Set(StoryCategory.allCases).subtracting([.science]))
    }

    @Test("No feed URL is listed twice")
    func urlsAreUnique() {
        #expect(Set(RSSFeed.all.map(\.url)).count == RSSFeed.all.count)
    }

    @Test("The loader reads only the reader's language")
    func loaderFollowsLanguage() {
        #expect(FeedLoader(language: .hindi).activeFeeds.allSatisfy { $0.language == .hindi })
        #expect(FeedLoader().activeFeeds.allSatisfy { $0.language == .english })
    }

    @Test("The Hindi prompt asks for Devanagari; the English one doesn't")
    func promptFollowsLanguage() {
        #expect(QuestionGenerator.systemPrompt(for: .hindi).contains("Devanagari"))
        #expect(!QuestionGenerator.systemPrompt(for: .english).contains("Devanagari"))
    }

    @Test("The voice briefing starts in the reader's news language")
    func voiceFollows() {
        #expect(ContentLanguage.hindi.voice == .hindi)
        #expect(ContentLanguage.english.voice == .english)
    }
}
