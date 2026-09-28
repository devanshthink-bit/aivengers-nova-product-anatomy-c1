//
//  VoiceIntentTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Voice language")
struct VoiceLanguageTests {

    @Test("The greeting uses the reader's name when there is one")
    func greeting() {
        #expect(VoiceLanguage.english.greeting(name: "Prakash") == "Hi Prakash, what news summary do you want?")
        #expect(VoiceLanguage.english.greeting(name: "  ") == "Hi, what news summary do you want?")
        #expect(VoiceLanguage.hindi.greeting(name: "Prakash") == "नमस्ते Prakash, आप कौन सी खबरें सुनना चाहेंगे?")
    }

    @Test("Intros say the real count and the topic")
    func intros() {
        #expect(VoiceLanguage.english.intro(count: 10, category: .technology) == "Here are the top 10 technology stories.")
        #expect(VoiceLanguage.english.intro(count: 1, category: .technology) == "Here is the top technology story.")
        #expect(VoiceLanguage.english.intro(count: 3, category: .india) == "Here are the top 3 India stories.")
        #expect(VoiceLanguage.english.intro(count: 10, category: nil) == "Here are today's top 10 stories.")
        #expect(VoiceLanguage.hindi.intro(count: 10, category: .technology) == "टेक्नोलॉजी की 10 मुख्य खबरें।")
        #expect(VoiceLanguage.hindi.intro(count: 4, category: nil) == "आज की 4 मुख्य खबरें।")
    }

    @Test("Hindi is preferred only when the phone is set to Hindi")
    func preferred() {
        #expect(VoiceLanguage.preferred(from: ["hi-IN", "en-IN"]) == .hindi)
        #expect(VoiceLanguage.preferred(from: ["en-GB", "hi-IN"]) == .english)
        #expect(VoiceLanguage.preferred(from: []) == .english)
    }
}

@Suite("Voice intent")
struct VoiceIntentTests {

    @Test("English topic words pick the category", arguments: [
        ("Tell me the tech news", StoryCategory.technology),
        ("summarize business news", .business),
        ("what's happening in the world", .world),
        ("any science stories today", .science),
        ("news from India", .india),
        ("international news please", .world),
        ("India's tech sector", .technology),
        ("latest cricket news", .sports),
        ("any Bollywood news", .entertainment),
        ("India's cricket team", .sports)
    ])
    func englishCategories(transcript: String, expected: StoryCategory) {
        #expect(VoiceIntent.parse(transcript).category == expected)
    }

    @Test("Hindi topic words pick the category", arguments: [
        ("टेक की खबरें", StoryCategory.technology),
        ("भारत की खबरें सुनाओ", .india),
        ("बिज़नेस न्यूज़", .business),
        ("दुनिया में क्या हो रहा है", .world),
        ("विज्ञान की खबरें", .science),
        ("क्रिकेट की खबरें", .sports),
        ("फिल्मों की खबरें", .entertainment)
    ])
    func hindiCategories(transcript: String, expected: StoryCategory) {
        #expect(VoiceIntent.parse(transcript).category == expected)
    }

    @Test("No topic word means every category, ten stories")
    func noTopic() {
        #expect(VoiceIntent.parse("what's the news") == VoiceIntent(category: nil, count: 10))
        // "ai" is a keyword; "said" and "again" must not match it.
        #expect(VoiceIntent.parse("he said it again").category == nil)
    }

    @Test("Counts are read and clamped to 1…10", arguments: [
        ("top 5 business stories", 5),
        ("give me the top five", 5),
        ("पाँच मुख्य खबरें", 5),
        ("५ खबरें", 5),
        ("top 50 stories", 10),
        ("top 0 stories", 1)
    ])
    func counts(transcript: String, expected: Int) {
        #expect(VoiceIntent.parse(transcript).count == expected)
    }

    @Test("A number word only counts next to 'top' or a word for stories")
    func numberWordsNeedContext() {
        #expect(VoiceIntent.parse("एक बात बताओ, दुनिया में क्या हो रहा है") == VoiceIntent(category: .world, count: 10))
        #expect(VoiceIntent.parse("what's the one thing in tech").count == 10)
    }
}
