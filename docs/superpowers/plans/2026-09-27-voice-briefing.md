# Voice Briefing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a floating mic button to NOVA. It greets the reader, listens to one spoken request, and speaks up to ten one-line news highlights in English or Hindi, at no cost.

**Architecture:** The pure logic has no SwiftUI or AVFoundation, and has tests:
- `VoiceLanguage`, `VoiceIntent`, `Highlights`, `Briefing`
- three `BriefingWriter` tiers behind a `FallbackBriefingWriter`: ZeroAPI, then Apple Foundation Models, then rules

Thin device wrappers sit on top: `SpeechListener`, `Speaker`, and `SoundPlayer`'s audio session.

An `@Observable` `VoiceAssistant` state machine drives the whole flow. It depends only on protocols, so it can be tested with fakes. A floater and a sheet panel are wired into `RootView`.

**Tech Stack:**
- Swift 5 mode with default MainActor isolation, SwiftUI
- Speech (`SFSpeechRecognizer`), AVFoundation (`AVAudioEngine`, `AVSpeechSynthesizer`, `AVAudioSession`)
- FoundationModels, Translation
- Swift Testing

**Spec:** `docs/superpowers/specs/2026-09-27-voice-briefing-design.md`

## Global Constraints

- Free: no paid APIs, no keys, nothing secret in the binary.
- One-shot in v1: greet → listen → answer → done. No follow-up turns.
- Languages: English (`en-IN`) and Hindi (`hi-IN`) for listening and speaking. The chip reads `EN` / `हिं` and is stored in `@AppStorage("voiceLanguage")`.
- Tier order: **ZeroAPI → Apple Foundation Models → on-device rules**. The rules tier never fails on a non-empty pool.
- ZeroAPI request:
  - `POST https://zeroapi.in/api/ai` with `Origin: https://zeroapi.in`
  - Model `llama-3.1-8b-instant`. Never use `openai/gpt-oss-*`.
  - 8 s timeout, no retry.
- At most 10 highlights. Each spoken line is at most 15 words in the prompt, and at most 25 after validation.
- Machine-written briefings (ZeroAPI or on-device) show `AI-written · unchecked`.
- Paper design: `Nova.paper` / `Nova.sheet` / `Nova.ink` / `Nova.hairline`. No glass, no gradients. **Marigold is never used here**: nothing in the briefing is earned.
- iOS-only APIs go behind helpers, never raw `#if` at call sites, because the target also builds for macOS and visionOS.
- Hide the floater during onboarding and while any Scroll-tab route (`.quizIntro`, `.quiz`, `.results`) is pushed.
- Comments explain *why*; match the density of the surrounding code.
- Every commit message ends with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

All `xcodebuild` commands run from `NOVA/`. `DEST` means `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.

## Review Focus

1. **Stop or close mid-briefing.** No further line is spoken, the audio session goes back to `.ambient`, and the phase settles. Tested in Task 6, `stopMidBriefing`.
2. **A second request while the first is still running.** The first run's remaining lines are never spoken, and its cleanup must not hand the audio session back under the second run. Tested in Task 6, `restartMidRun`.
3. **Hindi sentences that contain number words.** "एक बात बताओ…" must not shrink the briefing to one story. Tested in Task 1, `numberWordsNeedContext`.
4. **AI output that references stories not in the pool,** repeats one, or returns more than asked. These items are dropped, and zero survivors moves on to the next tier. Tested in Task 2 (`validationDropsBadItems`) and Task 3 (`invalidBriefingFallsThrough`).
5. **A named category with no stories today.** The reader still hears the newest stories across all categories, not silence. Tested in Task 6, `emptyCategoryFallsBackToAll`.

---

## File map

| File | Responsibility |
|---|---|
| `NOVA/NOVA/Services/Voice/VoiceLanguage.swift` | Language enum, locales, fixed phrases, intros |
| `NOVA/NOVA/Services/Voice/VoiceIntent.swift` | Transcript → category and count |
| `NOVA/NOVA/Services/Voice/Highlights.swift` | Pool → newest, de-duplicated candidates |
| `NOVA/NOVA/Services/Voice/Briefing.swift` | `Briefing`, validation, JSON decoding, `BriefingPrompt`, `BriefingError` |
| `NOVA/NOVA/Services/Voice/BriefingWriter.swift` | Protocol, `withTimeout`, `FallbackBriefingWriter` |
| `NOVA/NOVA/Services/Voice/RuleBriefingWriter.swift` | Rules tier and `HeadlineTranslator` |
| `NOVA/NOVA/Services/Voice/ZeroAPIBriefingWriter.swift` | ZeroAPI tier |
| `NOVA/NOVA/Services/Voice/OnDeviceBriefingWriter.swift` | Foundation Models tier |
| `NOVA/NOVA/Services/Voice/SpeechListener.swift` | `VoiceListening`, mic and speech recognition |
| `NOVA/NOVA/Services/Voice/Speaker.swift` | `VoiceSpeaking`, speech synthesis |
| `NOVA/NOVA/Services/Voice/VoiceAssistant.swift` | State machine, `VoiceAudioSession` |
| `NOVA/NOVA/Services/SoundPlayer.swift` (modify) | `beginVoice()` / `endVoice()`, conforms to `VoiceAudioSession` |
| `NOVA/NOVA/Features/Voice/VoiceFloater.swift` | Mic button |
| `NOVA/NOVA/Features/Voice/VoiceBriefingPanel.swift` | Sheet UI |
| `NOVA/NOVA/App/RootView.swift` (modify) | Inject the assistant, overlay, sheet, DEBUG `-openVoice` |
| `NOVA/NOVA.xcodeproj/project.pbxproj` (modify) | Microphone and speech usage strings |
| `NOVA/NOVATests/VoiceIntentTests.swift` | Language and intent |
| `NOVA/NOVATests/BriefingTests.swift` | Highlights, Briefing, prompt |
| `NOVA/NOVATests/BriefingWriterTests.swift` | Fallback, rules, ZeroAPI offline, on-device |
| `NOVA/NOVATests/VoiceAssistantTests.swift` | State machine with fakes |
| `CLAUDE.md` (modify) | Voice architecture notes |

Source folders are filesystem-synchronised, so new `.swift` files need no pbxproj edit.

---

### Task 0: Baseline

- [ ] **Step 1: Confirm the branch and a green suite**

```bash
git -C .. branch --show-current   # expect feat/voice-readout
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20
```
Expected: `** TEST SUCCEEDED **`. If it fails before any change, stop and report. Don't build on a red baseline.

---

### Task 1: VoiceLanguage and VoiceIntent

**Files:**
- Create: `NOVA/NOVA/Services/Voice/VoiceLanguage.swift`
- Create: `NOVA/NOVA/Services/Voice/VoiceIntent.swift`
- Test: `NOVA/NOVATests/VoiceIntentTests.swift`

**Interfaces:**
- Consumes: `StoryCategory` (`Models/Story.swift`).
- Produces:
  - `enum VoiceLanguage: String, CaseIterable, Sendable { case english = "en", hindi = "hi" }`, with:
    - `localeIdentifier: String`, `locale: Locale`, `chipTitle: String`
    - `static func preferred(from: [String] = Locale.preferredLanguages) -> VoiceLanguage`
    - `greeting(name:) -> String`, `didNotCatch`, `storiesLoading`
    - `static let hindiRecognitionUnavailable`, `static let headlinesInEnglish`
    - `categoryName(_:)`, `intro(count:category:) -> String`
  - `struct VoiceIntent: Equatable, Sendable { var category: StoryCategory?; var count: Int }`, with `static let maximumCount = 10` and `static func parse(_ transcript: String) -> VoiceIntent`.

- [ ] **Step 1: Write the failing tests**

```swift
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
        ("India's tech sector", .technology)
    ])
    func englishCategories(transcript: String, expected: StoryCategory) {
        #expect(VoiceIntent.parse(transcript).category == expected)
    }

    @Test("Hindi topic words pick the category", arguments: [
        ("टेक की खबरें", StoryCategory.technology),
        ("भारत की खबरें सुनाओ", .india),
        ("बिज़नेस न्यूज़", .business),
        ("दुनिया में क्या हो रहा है", .world),
        ("विज्ञान की खबरें", .science)
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
```

- [ ] **Step 2: Run them and watch them fail**

Run: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:NOVATests/VoiceIntentTests -only-testing:NOVATests/VoiceLanguageTests 2>&1 | tail -20`
Expected: build failure, "cannot find 'VoiceIntent' in scope".

- [ ] **Step 3: Write `VoiceLanguage.swift`**

```swift
//
//  VoiceLanguage.swift
//  NOVA
//

import Foundation

/// The two languages the voice briefing listens and speaks in.
///
/// Indian English rather than en-US: the feeds are Indian and world news, and en-IN
/// recognises Indian names and places noticeably better.
enum VoiceLanguage: String, CaseIterable, Sendable {
    case english = "en"
    case hindi = "hi"

    var localeIdentifier: String {
        switch self {
        case .english: "en-IN"
        case .hindi: "hi-IN"
        }
    }

    var locale: Locale { Locale(identifier: localeIdentifier) }

    /// What the language chip shows.
    var chipTitle: String {
        switch self {
        case .english: "EN"
        case .hindi: "हिं"
        }
    }

    /// Hindi when the phone's first language is Hindi, English otherwise.
    static func preferred(from languages: [String] = Locale.preferredLanguages) -> VoiceLanguage {
        languages.first?.hasPrefix("hi") == true ? .hindi : .english
    }

    // MARK: - Phrases

    func greeting(name: String) -> String {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch self {
        case .english:
            return name.isEmpty
                ? "Hi, what news summary do you want?"
                : "Hi \(name), what news summary do you want?"
        case .hindi:
            return name.isEmpty
                ? "नमस्ते, आप कौन सी खबरें सुनना चाहेंगे?"
                : "नमस्ते \(name), आप कौन सी खबरें सुनना चाहेंगे?"
        }
    }

    var didNotCatch: String {
        switch self {
        case .english: "Sorry, I didn't catch that. Which news would you like?"
        case .hindi: "माफ़ कीजिए, मैं समझ नहीं पाया। आप कौन सी खबरें सुनना चाहेंगे?"
        }
    }

    var storiesLoading: String {
        switch self {
        case .english: "Stories are still loading. Try again in a moment."
        case .hindi: "खबरें अभी लोड हो रही हैं। थोड़ी देर में फिर कोशिश करें।"
        }
    }

    /// Said in Hindi when this phone can't recognise Hindi, just before listening in English.
    static let hindiRecognitionUnavailable = "इस फ़ोन पर हिंदी पहचान उपलब्ध नहीं है, इसलिए मैं अंग्रेज़ी में सुनूँगा।"

    /// Added to a Hindi intro when the headlines couldn't be translated and are read in English.
    static let headlinesInEnglish = "शीर्षक अंग्रेज़ी में हैं।"

    func categoryName(_ category: StoryCategory) -> String {
        switch self {
        case .english:
            // "India" is a name, so it keeps its capital; the rest read as ordinary words.
            return category == .india ? category.title : category.title.lowercased()
        case .hindi:
            switch category {
            case .india: return "भारत"
            case .technology: return "टेक्नोलॉजी"
            case .business: return "बिज़नेस"
            case .world: return "दुनिया"
            case .science: return "विज्ञान"
            }
        }
    }

    /// The sentence before the highlights. `count` is what will actually be read, which
    /// can be fewer than asked for on a thin day.
    func intro(count: Int, category: StoryCategory?) -> String {
        switch self {
        case .english:
            guard let category else {
                return count == 1 ? "Here is today's top story." : "Here are today's top \(count) stories."
            }
            let name = categoryName(category)
            return count == 1 ? "Here is the top \(name) story." : "Here are the top \(count) \(name) stories."
        case .hindi:
            guard let category else { return "आज की \(count) मुख्य खबरें।" }
            return "\(categoryName(category)) की \(count) मुख्य खबरें।"
        }
    }
}
```

- [ ] **Step 4: Write `VoiceIntent.swift`**

```swift
//
//  VoiceIntent.swift
//  NOVA
//

import Foundation

/// What the reader asked for, read from what they said.
///
/// Keyword tables rather than a model: this has to work when both AI tiers are down,
/// and every tier uses it as the category filter, so the stories on offer match
/// the topic the reader named whichever tier writes the lines.
struct VoiceIntent: Equatable, Sendable {
    static let maximumCount = 10

    /// nil means every category.
    var category: StoryCategory?
    var count: Int = VoiceIntent.maximumCount

    static func parse(_ transcript: String) -> VoiceIntent {
        let words = normalisedWords(in: transcript)
        // Whole words only: "ai" must not match inside "said".
        let padded = " " + words.joined(separator: " ") + " "
        let category = categoryOrder.first { category in
            keywords[category, default: []].contains { padded.contains(" \($0) ") }
        }
        return VoiceIntent(category: category, count: count(in: words) ?? maximumCount)
    }

    // MARK: - Topics

    /// Narrow topics first, so "India's tech sector" is technology and "world markets" is
    /// business. India and world are the broadest, so they only win when nothing else does.
    private static let categoryOrder: [StoryCategory] = [.technology, .science, .business, .india, .world]

    /// Hindi recognition often writes English loanwords in Devanagari ("टेक", "बिज़नेस"),
    /// so both scripts are listed.
    private static let keywords: [StoryCategory: [String]] = [
        .technology: ["tech", "technology", "technologies", "ai", "artificial intelligence", "gadget", "gadgets",
                      "software", "internet", "cyber", "टेक", "तकनीक", "तकनीकी", "प्रौद्योगिकी", "टेक्नोलॉजी"],
        .science: ["science", "scientific", "space", "research", "climate", "health", "medicine",
                   "विज्ञान", "साइंस", "अंतरिक्ष", "स्वास्थ्य"],
        .business: ["business", "market", "markets", "economy", "economic", "finance", "financial", "stock",
                    "stocks", "money", "company", "companies", "startup", "startups", "व्यापार", "बिज़नेस",
                    "बिजनेस", "बाज़ार", "बाजार", "अर्थव्यवस्था", "शेयर", "कारोबार"],
        .india: ["india", "indian", "national", "domestic", "delhi", "mumbai", "भारत", "देश", "इंडिया", "राष्ट्रीय"],
        .world: ["world", "international", "global", "foreign", "abroad", "दुनिया", "विदेश", "विदेशी",
                 "अंतरराष्ट्रीय", "विश्व"]
    ]

    // MARK: - Counts

    private static let numberWords: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5,
        "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "एक": 1, "दो": 2, "तीन": 3, "चार": 4, "पाँच": 5, "पांच": 5,
        "छह": 6, "छः": 6, "सात": 7, "आठ": 8, "नौ": 9, "दस": 10
    ]

    /// Words that make a number word a count. Without this, "एक बात बताओ" ("tell me one
    /// thing") would cut the briefing to a single story: "एक" is also Hindi's "a".
    private static let countContext: Set<String> = [
        "stories", "story", "headlines", "headline", "news", "updates", "biggest", "latest",
        "खबरें", "खबर", "समाचार", "हेडलाइन", "हेडलाइंस", "मुख्य", "बड़ी"
    ]

    private static func count(in words: [String]) -> Int? {
        for (index, word) in words.enumerated() {
            // Digits are unambiguous wherever they appear.
            if let digits = Int(word) { return clamp(digits) }
            guard let value = numberWords[word] else { continue }
            let previous = index > 0 ? words[index - 1] : ""
            let next = index + 1 < words.count ? words[index + 1] : ""
            if previous == "top" || next == "top" || countContext.contains(next) {
                return clamp(value)
            }
        }
        return nil
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, 1), maximumCount)
    }

    /// Lowercased words, with Devanagari digits (०…९) turned into ASCII: Hindi
    /// recognition can return either, and `Int` only reads ASCII.
    private static func normalisedWords(in transcript: String) -> [String] {
        var scalars = String.UnicodeScalarView()
        for scalar in transcript.lowercased().unicodeScalars {
            if (0x0966...0x096F).contains(scalar.value),
               let ascii = Unicode.Scalar(scalar.value - 0x0966 + 0x30) {
                scalars.append(ascii)
            } else {
                scalars.append(scalar)
            }
        }
        // `alphanumerics` includes combining marks, so Devanagari vowel signs stay
        // attached to their words.
        return String(scalars)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: the Step 2 command. Expected: `** TEST SUCCEEDED **`.
If `"टेक की खबरें"` fails, print `normalisedWords` for it before touching the tables. A split vowel sign means the character set is at fault, not the keyword.

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Services/Voice/VoiceLanguage.swift NOVA/NOVA/Services/Voice/VoiceIntent.swift NOVA/NOVATests/VoiceIntentTests.swift
git commit -m "Parse spoken news requests in English and Hindi

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
(Run `git` from the repo root, or prefix the paths with `../` when running from `NOVA/`.)

---

### Task 2: Highlights, Briefing and the prompt

**Files:**
- Create: `NOVA/NOVA/Services/Voice/Highlights.swift`
- Create: `NOVA/NOVA/Services/Voice/Briefing.swift`
- Test: `NOVA/NOVATests/BriefingTests.swift`

**Interfaces:**
- Consumes: `VoiceIntent`, `VoiceLanguage` (Task 1), `Story`, `StoryID`, and `String.truncatedToWords(_:)` (`Services/RSSParser.swift:242`).
- Produces:
  - `enum Highlights`, with `static let aiCandidateLimit = 40` and `static func candidates(for: VoiceIntent, from: [Story], limit: Int) -> [Story]`.
  - `struct Briefing: Equatable, Sendable`, with fields `intro`, `items: [Item]`, `tier: Tier`, `lineLanguage: VoiceLanguage`, and:
    - `Item { storyID: StoryID; line: String; id }`
    - `Tier { zeroAPI, onDevice, rules; isMachineWritten }`
    - `validated(against:limit:defaultIntro:) throws -> Briefing`
    - `static decoding(_:candidates:tier:language:) throws -> Briefing`
    - `static storyID(forNumber: Int, in: [Story]) -> StoryID`
  - `enum BriefingError: Error, Equatable { noStories, unavailable, noValidItems, notJSON, badResponse, timedOut }`.
  - `enum BriefingPrompt`, with `instructions(language:count:)` and `request(transcript:candidates:)`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  BriefingTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, _ category: StoryCategory = .technology,
                   title: String? = nil, hoursAgo: Double = 0) -> Story {
    Story(
        id: StoryID(id),
        title: title ?? "Headline \(id)",
        summary: "Summary \(id)",
        source: "Source \(id)",
        category: category,
        publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
        artwork: .none
    )
}

@Suite("Highlights")
struct HighlightsTests {

    @Test("Candidates are one category, newest first, capped")
    func filtersAndSorts() {
        let pool = [
            story("old", hoursAgo: 5), story("india", .india, hoursAgo: 0),
            story("new", hoursAgo: 1), story("mid", hoursAgo: 3)
        ]
        let picked = Highlights.candidates(for: VoiceIntent(category: .technology), from: pool, limit: 2)
        #expect(picked.map(\.id.rawValue) == ["new", "mid"])
    }

    @Test("No category takes everything")
    func allCategories() {
        let pool = [story("a", .india, hoursAgo: 1), story("b", .world, hoursAgo: 0)]
        #expect(Highlights.candidates(for: VoiceIntent(category: nil), from: pool, limit: 10).map(\.id.rawValue) == ["b", "a"])
    }

    @Test("The same headline from two feeds is read once")
    func dedupes() {
        let pool = [story("a", title: "Chip ships", hoursAgo: 0), story("b", title: "CHIP SHIPS", hoursAgo: 1)]
        #expect(Highlights.candidates(for: VoiceIntent(category: nil), from: pool, limit: 10).count == 1)
    }
}

@Suite("Briefing")
struct BriefingTests {

    private let candidates = [story("a"), story("b"), story("c")]

    private func briefing(_ items: [(String, String)], intro: String = "Intro") -> Briefing {
        Briefing(intro: intro,
                 items: items.map { Briefing.Item(storyID: StoryID($0.0), line: $0.1) },
                 tier: .zeroAPI, lineLanguage: .english)
    }

    @Test("Validation drops unknown, repeated and empty items, and caps the count")
    func validationDropsBadItems() throws {
        let raw = briefing([("a", "One"), ("zzz", "Made up"), ("a", "Again"), ("b", "   "), ("c", "Three"), ("b", "Two")])
        let valid = try raw.validated(against: candidates, limit: 2, defaultIntro: "Default")
        #expect(valid.items.map(\.storyID.rawValue) == ["a", "c"])
        #expect(valid.items.map(\.line) == ["One", "Three"])
        #expect(valid.intro == "Intro")
    }

    @Test("A briefing with nothing valid is a failure")
    func nothingValid() {
        #expect(throws: BriefingError.noValidItems) {
            try briefing([("zzz", "Made up")]).validated(against: candidates, limit: 10, defaultIntro: "D")
        }
    }

    @Test("An empty intro is replaced")
    func defaultIntro() throws {
        let valid = try briefing([("a", "One")], intro: " ").validated(against: candidates, limit: 10, defaultIntro: "Default")
        #expect(valid.intro == "Default")
    }

    @Test("JSON wrapped in prose decodes, and story numbers map to IDs")
    func decodesWrappedJSON() throws {
        let content = """
        Sure! ```json
        {"intro": "Here you go.", "items": [{"id": "2", "line": "Source b: thing"}, {"id": 1, "line": "Source a: other"}, {"id": 9, "line": "Nope"}]}
        ```
        """
        let decoded = try Briefing.decoding(content, candidates: candidates, tier: .zeroAPI, language: .english)
        #expect(decoded.intro == "Here you go.")
        #expect(decoded.items.map(\.storyID.rawValue) == ["b", "a", ""])
        let valid = try decoded.validated(against: candidates, limit: 10, defaultIntro: "D")
        #expect(valid.items.count == 2)
    }

    @Test("Text without JSON is rejected")
    func rejectsProse() {
        #expect(throws: BriefingError.notJSON) {
            try Briefing.decoding("I can't help with that.", candidates: candidates, tier: .zeroAPI, language: .english)
        }
    }

    @Test("The prompt numbers stories from one")
    func promptNumbers() {
        let prompt = BriefingPrompt.request(transcript: "tech news", candidates: candidates)
        #expect(prompt.contains("1 | Source a | Headline a"))
        #expect(prompt.contains("3 | Source c | Headline c"))
        #expect(prompt.contains("\"tech news\""))
        #expect(BriefingPrompt.instructions(language: .hindi, count: 10).contains("Devanagari"))
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `xcodebuild … test -only-testing:NOVATests/HighlightsTests -only-testing:NOVATests/BriefingTests`
Expected: build failure, "cannot find 'Highlights'".

- [ ] **Step 3: Write `Highlights.swift`**

```swift
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
```

- [ ] **Step 4: Write `Briefing.swift`**

```swift
//
//  Briefing.swift
//  NOVA
//

import Foundation

/// What gets read aloud: an intro, then one line per story.
struct Briefing: Equatable, Sendable {
    enum Tier: String, Equatable, Sendable {
        case zeroAPI, onDevice, rules

        /// A model wrote the lines and nobody has checked them. See CLAUDE.md, Content.
        var isMachineWritten: Bool { self != .rules }
    }

    struct Item: Equatable, Sendable, Identifiable {
        let storyID: StoryID
        let line: String
        var id: StoryID { storyID }
    }

    var intro: String
    var items: [Item]
    var tier: Tier
    /// The language the lines are in. Differs from the reader's choice only on the rules
    /// tier, when Hindi was asked for and no translation pack is installed.
    var lineLanguage: VoiceLanguage

    /// A backstop, not the target: the prompt asks for 15. A model that ignores that
    /// shouldn't be able to read a paragraph per story.
    static let lineWordLimit = 25

    /// Keeps only items that point at a real candidate, once each, up to `limit`.
    ///
    /// Models invent IDs and repeat themselves. A briefing that survives with nothing
    /// in it throws, so the fallback chain moves on instead of reading an intro to silence.
    func validated(against candidates: [Story], limit: Int, defaultIntro: String) throws -> Briefing {
        let known = Set(candidates.map(\.id))
        var seen: Set<StoryID> = []
        var kept: [Item] = []
        for item in items where kept.count < limit {
            let line = item.line
                .replacing(/\s+/, with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty, known.contains(item.storyID), seen.insert(item.storyID).inserted else { continue }
            kept.append(Item(storyID: item.storyID, line: line.truncatedToWords(Self.lineWordLimit)))
        }
        guard !kept.isEmpty else { throw BriefingError.noValidItems }

        let intro = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        return Briefing(intro: intro.isEmpty ? defaultIntro : intro, items: kept, tier: tier, lineLanguage: lineLanguage)
    }

    /// Stories are offered to models by number, not ID. Feed IDs are often full URLs,
    /// and ten of those would eat the reply's token budget, which Hindi needs more of.
    /// An out-of-range number maps to an empty ID, which validation then drops.
    static func storyID(forNumber number: Int, in candidates: [Story]) -> StoryID {
        candidates.indices.contains(number - 1) ? candidates[number - 1].id : StoryID("")
    }

    /// Decodes the JSON the AI tiers are asked for. Models wrap it in fences or prose
    /// often enough that trimming to the outermost braces beats asking again.
    static func decoding(_ content: String, candidates: [Story], tier: Tier, language: VoiceLanguage) throws -> Briefing {
        guard
            let start = content.firstIndex(of: "{"),
            let end = content.lastIndex(of: "}"),
            start < end
        else { throw BriefingError.notJSON }

        let wire: Wire
        do {
            wire = try JSONDecoder().decode(Wire.self, from: Data(content[start...end].utf8))
        } catch {
            throw BriefingError.notJSON
        }
        return Briefing(
            intro: wire.intro ?? "",
            items: wire.items.map { Item(storyID: storyID(forNumber: $0.number, in: candidates), line: $0.line) },
            tier: tier,
            lineLanguage: language
        )
    }

    private struct Wire: Decodable {
        let intro: String?
        let items: [WireItem]
    }

    private struct WireItem: Decodable {
        let number: Int
        let line: String

        enum CodingKeys: String, CodingKey { case id, line }

        /// The prompt asks for a number; models send `2` and `"2"` about equally often.
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let number = try? container.decode(Int.self, forKey: .id) {
                self.number = number
            } else {
                let text = try container.decode(String.self, forKey: .id)
                self.number = Int(text.trimmingCharacters(in: .whitespaces)) ?? 0
            }
            line = try container.decode(String.self, forKey: .line)
        }
    }
}

enum BriefingError: Error, Equatable {
    case noStories
    case unavailable
    case noValidItems
    case notJSON
    case badResponse
    case timedOut
}

/// The prompt both AI tiers send, so they're asked for the same thing.
enum BriefingPrompt {
    static func instructions(language: VoiceLanguage, count: Int) -> String {
        let written = language == .hindi ? "Hindi, in Devanagari script" : "English"
        return """
            You are NOVA, a news app, writing a short briefing that will be read aloud.

            Return STRICT JSON and nothing else. No markdown, no code fences, no preamble.

            Shape:
            {"intro": string, "items": [{"id": number, "line": string}]}

            Rules:
            - Choose up to \(count) of the most important stories for what the reader asked for, most important first.
            - "id" is the story's number from the list you are given. Never invent one.
            - "line" is one spoken sentence of at most 15 words: the source, a colon, then what happened.
            - "intro" is one short sentence introducing the briefing.
            - Write "intro" and every "line" in \(written).
            - Use only what the headline says. Never add detail.
            """
    }

    static func request(transcript: String, candidates: [Story]) -> String {
        let list = candidates.enumerated()
            .map { "\($0.offset + 1) | \($0.element.source) | \($0.element.title)" }
            .joined(separator: "\n")
        return """
            The reader said: "\(transcript)"

            Stories (number | source | headline):
            \(list)
            """
    }
}
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: the Step 2 command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Services/Voice/Highlights.swift NOVA/NOVA/Services/Voice/Briefing.swift NOVA/NOVATests/BriefingTests.swift
git commit -m "Add the briefing model, its validation and the shared prompt

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Fallback chain and rules tier

**Files:**
- Create: `NOVA/NOVA/Services/Voice/BriefingWriter.swift`
- Create: `NOVA/NOVA/Services/Voice/RuleBriefingWriter.swift`
- Test: `NOVA/NOVATests/BriefingWriterTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–2.
- Produces:
  - `protocol BriefingWriter: Sendable { func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing }`
  - `func withTimeout<T: Sendable>(_ limit: Duration, _ work: @escaping @Sendable () async throws -> T) async throws -> T`
  - `struct FallbackBriefingWriter: BriefingWriter`, with `init(writers: [any BriefingWriter], timeout: Duration = .seconds(8))` and `static let standard`. `standard` references the Task 4 types, so it is **added in Task 4**, not here.
  - `protocol HeadlineTranslating: Sendable { func translate(_ lines: [String], to: VoiceLanguage) async -> [String]? }`
  - `struct HeadlineTranslator: HeadlineTranslating`
  - `struct RuleBriefingWriter: BriefingWriter`, with `var translator: any HeadlineTranslating = HeadlineTranslator()` and `static let titleWordLimit = 12`.

- [ ] **Step 1: Write the failing tests**

```swift
//
//  BriefingWriterTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, title: String? = nil, hoursAgo: Double = 0) -> Story {
    Story(
        id: StoryID(id),
        title: title ?? "Headline \(id)",
        summary: "Summary \(id)",
        source: "Source \(id)",
        category: .technology,
        publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
        artwork: .none
    )
}

private let pool = [story("a"), story("b", hoursAgo: 1), story("c", hoursAgo: 2)]
private let intent = VoiceIntent(category: .technology, count: 10)

private struct StubWriter: BriefingWriter {
    enum Behaviour: Sendable {
        case fail
        case hang
        case answer(Briefing.Tier, ids: [String], after: Duration = .zero)
    }

    let behaviour: Behaviour

    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        switch behaviour {
        case .fail:
            throw BriefingError.unavailable
        case .hang:
            try await Task.sleep(for: .seconds(60))
            throw BriefingError.timedOut
        case .answer(let tier, let ids, let delay):
            if delay > .zero { try await Task.sleep(for: delay) }
            return Briefing(intro: "", items: ids.map { .init(storyID: StoryID($0), line: "Line \($0)") },
                            tier: tier, lineLanguage: language)
        }
    }
}

private struct FixedTranslator: HeadlineTranslating {
    let result: [String]?
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? { result }
}

@Suite("Fallback briefing writer")
struct FallbackBriefingWriterTests {

    private func run(_ writers: [StubWriter], timeout: Duration = .milliseconds(200)) async throws -> Briefing {
        try await FallbackBriefingWriter(writers: writers, timeout: timeout)
            .brief(request: "tech", intent: intent, language: .english, candidates: pool)
    }

    @Test("The first tier that answers wins")
    func firstWins() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["a"])),
                                      .init(behaviour: .answer(.rules, ids: ["b"]))])
        #expect(briefing.tier == .zeroAPI)
    }

    @Test("A failing tier falls through to the next")
    func failureFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .fail), .init(behaviour: .answer(.onDevice, ids: ["a"]))])
        #expect(briefing.tier == .onDevice)
    }

    @Test("A hanging tier is abandoned after the timeout")
    func hangFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .hang), .init(behaviour: .answer(.rules, ids: ["a"]))])
        #expect(briefing.tier == .rules)
    }

    @Test("A tier whose items are all invalid falls through")
    func invalidBriefingFallsThrough() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["made-up"])),
                                      .init(behaviour: .answer(.rules, ids: ["c"]))])
        #expect(briefing.tier == .rules)
        #expect(briefing.items.map(\.storyID.rawValue) == ["c"])
    }

    @Test("The last tier is never timed out, because it is the one that must answer")
    func lastTierNotTimed() async throws {
        let briefing = try await run([.init(behaviour: .fail),
                                      .init(behaviour: .answer(.rules, ids: ["a"], after: .milliseconds(400)))],
                                     timeout: .milliseconds(100))
        #expect(briefing.tier == .rules)
    }

    @Test("Every tier failing throws")
    func allFail() async {
        await #expect(throws: BriefingError.noValidItems) {
            try await run([.init(behaviour: .fail), .init(behaviour: .fail)])
        }
    }

    @Test("A missing intro is filled from the language")
    func fillsIntro() async throws {
        let briefing = try await run([.init(behaviour: .answer(.zeroAPI, ids: ["a", "b"]))])
        #expect(briefing.intro == "Here are the top 3 technology stories.")
    }
}

@Suite("Rule briefing writer")
struct RuleBriefingWriterTests {

    @Test("Lines are source and headline, newest first, up to the count")
    func englishLines() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: nil))
        let briefing = try await writer.brief(request: "", intent: VoiceIntent(category: .technology, count: 2),
                                              language: .english, candidates: pool)
        #expect(briefing.items.map(\.line) == ["Source a: Headline a", "Source b: Headline b"])
        #expect(briefing.intro == "Here are the top 2 technology stories.")
        #expect(briefing.tier == .rules)
        #expect(briefing.lineLanguage == .english)
    }

    @Test("Long headlines are cut to twelve words")
    func trimsTitles() async throws {
        let long = story("x", title: "one two three four five six seven eight nine ten eleven twelve thirteen fourteen")
        let briefing = try await RuleBriefingWriter(translator: FixedTranslator(result: nil))
            .brief(request: "", intent: intent, language: .english, candidates: [long])
        #expect(briefing.items.first?.line == "Source x: one two three four five six seven eight nine ten eleven twelve…")
    }

    @Test("Hindi uses the translation when there is one")
    func hindiTranslated() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: ["क", "ख", "ग"]))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.items.map(\.line) == ["क", "ख", "ग"])
        #expect(briefing.lineLanguage == .hindi)
    }

    @Test("Hindi without a translation reads English lines and says so")
    func hindiUntranslated() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: nil))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.lineLanguage == .english)
        #expect(briefing.intro.hasSuffix(VoiceLanguage.headlinesInEnglish))
    }

    @Test("A translation of the wrong length is ignored")
    func partialTranslation() async throws {
        let writer = RuleBriefingWriter(translator: FixedTranslator(result: ["क"]))
        let briefing = try await writer.brief(request: "", intent: intent, language: .hindi, candidates: pool)
        #expect(briefing.lineLanguage == .english)
    }

    @Test("An empty pool is the one thing it can't brief")
    func emptyPool() async {
        await #expect(throws: BriefingError.noStories) {
            try await RuleBriefingWriter(translator: FixedTranslator(result: nil))
                .brief(request: "", intent: intent, language: .english, candidates: [])
        }
    }
}
```

- [ ] **Step 2: Run them and watch them fail**

Run: `xcodebuild … test -only-testing:NOVATests/FallbackBriefingWriterTests -only-testing:NOVATests/RuleBriefingWriterTests`
Expected: build failure, "cannot find type 'BriefingWriter'".

- [ ] **Step 3: Write `BriefingWriter.swift`**

```swift
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
```

`fillsIntro` checks the default intro. The stub returns an empty intro, and the pool has three candidates, so `min(10, 3) == 3` gives "top 3". That is the count *offered*, which can exceed what the model returned. This is acceptable because it only applies when a model omitted its own intro.

- [ ] **Step 4: Write `RuleBriefingWriter.swift`**

```swift
//
//  RuleBriefingWriter.swift
//  NOVA
//

import Foundation
#if canImport(Translation)
import Translation
#endif

/// The tier that can't fail: newest stories, read as "source: headline".
///
/// It can't judge importance, so it doesn't pretend to. Newest first is at least honest.
/// This is what stands between an outage and a silent button.
struct RuleBriefingWriter: BriefingWriter {
    /// Twelve words fit one breath and still carry the story.
    static let titleWordLimit = 12

    var translator: any HeadlineTranslating = HeadlineTranslator()

    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        let picked = Array(candidates.prefix(intent.count))
        guard !picked.isEmpty else { throw BriefingError.noStories }

        var lines = picked.map { "\($0.source): \($0.title.truncatedToWords(Self.titleWordLimit))" }
        var lineLanguage = language
        var intro = language.intro(count: picked.count, category: intent.category)

        if language == .hindi {
            if let translated = await translator.translate(lines, to: .hindi), translated.count == lines.count {
                lines = translated
            } else {
                // Better an English headline said plainly than none. The intro stays in Hindi
                // and warns the reader, and each line is spoken in the English voice so
                // it isn't mangled.
                lineLanguage = .english
                intro += " " + VoiceLanguage.headlinesInEnglish
            }
        }

        return Briefing(
            intro: intro,
            items: zip(picked, lines).map { Briefing.Item(storyID: $0.id, line: $1) },
            tier: .rules,
            lineLanguage: lineLanguage
        )
    }
}

protocol HeadlineTranslating: Sendable {
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]?
}

/// English → Hindi with Apple's on-device Translation framework. Free and offline.
///
/// Only when the language pack is **already installed**. A download prompt in the middle
/// of a spoken conversation would strand the reader, so a missing pack returns nil and
/// the rules tier reads English instead.
struct HeadlineTranslator: HeadlineTranslating {
    static let timeout: Duration = .seconds(4)

    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? {
        guard language == .hindi, !lines.isEmpty else { return nil }
        // The rules tier has no timeout of its own, so this one is what keeps it dependable.
        let result = try? await withTimeout(Self.timeout) { await Self.translateToHindi(lines) }
        return result ?? nil
    }

    private static func translateToHindi(_ lines: [String]) async -> [String]? {
        #if canImport(Translation)
        let source = Locale.Language(identifier: "en")
        let target = Locale.Language(identifier: "hi")
        guard await LanguageAvailability().status(from: source, to: target) == .installed else { return nil }

        let session = TranslationSession(installedSource: source, target: target)
        let requests = lines.enumerated().map {
            TranslationSession.Request(sourceText: $0.element, clientIdentifier: String($0.offset))
        }
        guard let responses = try? await session.translations(from: requests) else { return nil }

        // Matched by identifier rather than trusting the order to come back unchanged.
        var byIndex: [Int: String] = [:]
        for response in responses {
            if let id = response.clientIdentifier, let index = Int(id) { byIndex[index] = response.targetText }
        }
        let translated = lines.indices.compactMap { byIndex[$0] }
        return translated.count == lines.count ? translated : nil
        #else
        return nil
        #endif
    }
}
```

If `TranslationSession(installedSource:target:)` doesn't exist in the installed SDK, the build fails on that line. In that case, replace the body inside `#if canImport(Translation)` with `return nil`. Add a comment saying the direct initialiser wasn't available, and report it. Don't pull in `.translationTask` view plumbing for this.

- [ ] **Step 5: Run the tests and watch them pass**

Run: the Step 2 command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Services/Voice/BriefingWriter.swift NOVA/NOVA/Services/Voice/RuleBriefingWriter.swift NOVA/NOVATests/BriefingWriterTests.swift
git commit -m "Add the briefing fallback chain and the rules tier

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: ZeroAPI and on-device tiers

**Files:**
- Create: `NOVA/NOVA/Services/Voice/ZeroAPIBriefingWriter.swift`
- Create: `NOVA/NOVA/Services/Voice/OnDeviceBriefingWriter.swift`
- Modify: `NOVA/NOVA/Services/Voice/BriefingWriter.swift` (add `standard`)
- Test: `NOVA/NOVATests/BriefingWriterTests.swift` (append)

**Interfaces:**
- Consumes: `QuestionGenerator.endpoint`, `QuestionGenerator.model` (`Services/QuestionGenerator.swift`), `BriefingPrompt`, `Briefing.decoding`, `Briefing.storyID(forNumber:in:)`.
- Produces:
  - `struct ZeroAPIBriefingWriter: BriefingWriter { var endpoint: URL; var session: URLSession }`
  - `struct OnDeviceBriefingWriter: BriefingWriter`
  - `extension FallbackBriefingWriter { static let standard }`

- [ ] **Step 1: Append the failing tests to `BriefingWriterTests.swift`**

```swift
@Suite("AI briefing tiers")
struct AIBriefingTierTests {

    /// A host that can't resolve: the closest stand-in for ZeroAPI being down, the same
    /// trick `QuestionGeneratorTests` uses.
    private var offlineZeroAPI: ZeroAPIBriefingWriter {
        var writer = ZeroAPIBriefingWriter()
        writer.endpoint = URL(string: "https://nova-tests.invalid/api/ai")!
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        writer.session = URLSession(configuration: configuration)
        return writer
    }

    @Test("ZeroAPI being down throws rather than inventing a briefing")
    func zeroAPIOfflineThrows() async {
        await #expect(throws: (any Error).self) {
            try await offlineZeroAPI.brief(request: "tech", intent: intent, language: .english, candidates: pool)
        }
    }

    @Test("With ZeroAPI down, the chain still briefs from the rules")
    func chainSurvivesOutage() async throws {
        let chain = FallbackBriefingWriter(writers: [offlineZeroAPI, RuleBriefingWriter(translator: FixedTranslator(result: nil))])
        let briefing = try await chain.brief(request: "tech", intent: intent, language: .english, candidates: pool)
        #expect(briefing.tier == .rules)
        #expect(briefing.items.count == 3)
    }

    @Test("The on-device tier refuses an empty pool whether or not the model exists")
    func onDeviceEmptyPool() async {
        await #expect(throws: (any Error).self) {
            try await OnDeviceBriefingWriter().brief(request: "tech", intent: intent, language: .english, candidates: [])
        }
    }
}
```

- [ ] **Step 2: Run and watch it fail**

Run: `xcodebuild … test -only-testing:NOVATests/AIBriefingTierTests`
Expected: build failure, "cannot find 'ZeroAPIBriefingWriter'".

- [ ] **Step 3: Write `ZeroAPIBriefingWriter.swift`**

```swift
//
//  ZeroAPIBriefingWriter.swift
//  NOVA
//

import Foundation

/// The best-sounding tier: the same free, keyless endpoint that writes the quiz questions.
///
/// It picks what matters and phrases it for speech, in Hindi when asked. No retry: the
/// next tier *is* the retry, and a second request against a rate limit only lengthens it.
struct ZeroAPIBriefingWriter: BriefingWriter {
    var endpoint: URL = QuestionGenerator.endpoint
    var session: URLSession = .shared

    func brief(request transcript: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        guard !candidates.isEmpty else { throw BriefingError.noStories }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("https://zeroapi.in", forHTTPHeaderField: "Origin")
        urlRequest.timeoutInterval = 8

        urlRequest.httpBody = try JSONEncoder().encode(
            BriefingChatRequest(
                // The question generator's tool id: the one this endpoint is known to accept.
                toolId: "mcqGenerator",
                model: QuestionGenerator.model,
                // Devanagari costs several tokens a word; 400 cut Hindi briefings off mid-list.
                maxTokens: 1000,
                temperature: 0.3,
                messages: [
                    .init(role: "system", content: BriefingPrompt.instructions(language: language, count: intent.count)),
                    .init(role: "user", content: BriefingPrompt.request(transcript: transcript, candidates: candidates))
                ]
            )
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw BriefingError.badResponse
        }
        let chat = try JSONDecoder().decode(BriefingChatResponse.self, from: data)
        guard let content = chat.choices.first?.message.content, !content.isEmpty else {
            throw BriefingError.badResponse
        }
        return try Briefing.decoding(content, candidates: candidates, tier: .zeroAPI, language: language)
    }
}

// MARK: - Wire types

// Separate from `QuestionGenerator`'s private copies so neither file's shape can
// quietly change the other's requests.
private struct BriefingChatRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let toolId: String
    let model: String
    let maxTokens: Int
    let temperature: Double
    let messages: [Message]

    enum CodingKeys: String, CodingKey {
        case toolId, model, temperature, messages
        case maxTokens = "max_tokens"
    }
}

private struct BriefingChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message
    }

    let choices: [Choice]
}
```

The "400 cut Hindi briefings off" comment is a prediction until someone has seen it happen. If a manual Hindi run in Task 8 doesn't confirm it, reword it to "Devanagari costs several tokens a word, so Hindi needs the larger budget".

- [ ] **Step 4: Write `OnDeviceBriefingWriter.swift`**

```swift
//
//  OnDeviceBriefingWriter.swift
//  NOVA
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The middle tier: Apple's on-device model, used when ZeroAPI is down or rate-limited.
///
/// Free, private and offline, but it only exists on Apple Intelligence phones with it
/// turned on, and its language support moves with the OS. Both are checked at runtime.
/// Anything else throws `.unavailable` and the chain moves on.
struct OnDeviceBriefingWriter: BriefingWriter {
    func brief(request transcript: String, intent: VoiceIntent, language: VoiceLanguage, candidates: [Story]) async throws -> Briefing {
        guard !candidates.isEmpty else { throw BriefingError.noStories }
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        guard case .available = model.availability, model.supportsLocale(language.locale) else {
            throw BriefingError.unavailable
        }

        let session = LanguageModelSession(
            model: model,
            instructions: BriefingPrompt.instructions(language: language, count: intent.count)
        )
        let response = try await session.respond(
            to: BriefingPrompt.request(transcript: transcript, candidates: candidates),
            generating: GeneratedBriefing.self
        )
        let generated = response.content
        return Briefing(
            intro: generated.intro,
            items: generated.items.map {
                Briefing.Item(storyID: Briefing.storyID(forNumber: $0.id, in: candidates), line: $0.line)
            },
            tier: .onDevice,
            lineLanguage: language
        )
        #else
        throw BriefingError.unavailable
        #endif
    }
}

#if canImport(FoundationModels)
/// Guided generation, so the model returns this shape directly and there is no JSON to
/// trim, unlike the ZeroAPI tier.
@Generable
struct GeneratedBriefing {
    @Guide(description: "One short sentence introducing the briefing")
    var intro: String

    @Guide(description: "The chosen stories, most important first", .maximumCount(10))
    var items: [GeneratedBriefingItem]
}

@Generable
struct GeneratedBriefingItem {
    @Guide(description: "The story's number from the list you were given")
    var id: Int

    @Guide(description: "One spoken sentence of at most 15 words: the source, a colon, then what happened")
    var line: String
}
#endif
```

The instructions also ask for JSON. Under guided generation that line is ignored in favour of the schema, which is harmless, so don't fork the prompt.

- [ ] **Step 5: Add `standard` to the end of `BriefingWriter.swift`**

```swift
extension FallbackBriefingWriter {
    /// What the app uses. Tests build their own chains.
    static let standard = FallbackBriefingWriter(writers: [
        ZeroAPIBriefingWriter(),
        OnDeviceBriefingWriter(),
        RuleBriefingWriter()
    ])
}
```

- [ ] **Step 6: Run all briefing suites and watch them pass**

Run: `xcodebuild … test -only-testing:NOVATests/AIBriefingTierTests -only-testing:NOVATests/FallbackBriefingWriterTests -only-testing:NOVATests/RuleBriefingWriterTests`
Expected: `** TEST SUCCEEDED **`.
Also build for Mac to prove the `canImport` guards hold: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=macOS' build`. Expected: `** BUILD SUCCEEDED **`. If the macOS destination isn't installed, note that and move on.

- [ ] **Step 7: Commit**

```bash
git add NOVA/NOVA/Services/Voice/ZeroAPIBriefingWriter.swift NOVA/NOVA/Services/Voice/OnDeviceBriefingWriter.swift NOVA/NOVA/Services/Voice/BriefingWriter.swift NOVA/NOVATests/BriefingWriterTests.swift
git commit -m "Add the ZeroAPI and on-device briefing tiers

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Device layer: listening, speaking, audio session, permissions

These wrap hardware and have no unit tests. Task 6 tests the logic above them through the protocols defined here. This task is verified by a clean build.

**Files:**
- Create: `NOVA/NOVA/Services/Voice/SpeechListener.swift`
- Create: `NOVA/NOVA/Services/Voice/Speaker.swift`
- Modify: `NOVA/NOVA/Services/SoundPlayer.swift`
- Modify: `NOVA/NOVA.xcodeproj/project.pbxproj` (both app configurations)

**Interfaces:**
- Consumes: `VoiceLanguage`.
- Produces:
  - `protocol VoiceListening: AnyObject`, with `onPartial: ((String) -> Void)?`, `requestPermission() async -> Bool`, `listen(language:) async throws -> String` and `stop()`
  - `enum ListenError: Error { case localeUnavailable }`
  - `final class SpeechListener: VoiceListening`
  - `protocol VoiceSpeaking: AnyObject`, with `say(_:language:) async` and `stop()`
  - `final class Speaker: NSObject, VoiceSpeaking`
  - `protocol VoiceAudioSession: AnyObject`, with `beginVoice()` and `endVoice()`
  - `SoundPlayer: VoiceAudioSession`

- [ ] **Step 1: Write `SpeechListener.swift`**

```swift
//
//  SpeechListener.swift
//  NOVA
//

import AVFoundation
import Speech

protocol VoiceListening: AnyObject {
    /// The transcript so far, as the reader speaks.
    var onPartial: ((String) -> Void)? { get set }
    func requestPermission() async -> Bool
    /// Listens until the reader pauses, then returns what they said. Returns "" if
    /// nothing was heard.
    func listen(language: VoiceLanguage) async throws -> String
    func stop()
}

enum ListenError: Error {
    /// This phone can't recognise that language right now.
    case localeUnavailable
}

/// The microphone and Apple's speech recogniser.
final class SpeechListener: VoiceListening {
    /// Long enough for a breath mid-sentence, short enough not to feel ignored.
    static let silenceTimeout: Duration = .milliseconds(1500)
    /// A cap for when nothing is ever said: the recogniser would otherwise wait for good.
    static let maximumDuration: Duration = .seconds(10)

    var onPartial: ((String) -> Void)?

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Never>?
    private var transcript = ""
    private var silenceTimer: Task<Void, Never>?
    private var capTimer: Task<Void, Never>?
    /// Bumped on every listen, so a late callback from a cancelled recognition can't
    /// write into the next one.
    private var generation = 0

    func requestPermission() async -> Bool {
        let speech = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }

    func listen(language: VoiceLanguage) async throws -> String {
        finish()
        guard let recognizer = SFSpeechRecognizer(locale: language.locale), recognizer.isAvailable else {
            throw ListenError.localeUnavailable
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // On-device where this phone can do it for this language: free, private, offline.
        // Otherwise Apple's server recognises it, which is still free and keyless, but the
        // audio leaves the phone. The usage string says so.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let input = engine.inputNode
        // `@Sendable` matters. The tap runs on the audio thread, and under this target's
        // default MainActor isolation an unannotated closure would be inferred main-actor
        // and trap the first time audio arrived.
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { @Sendable buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }

        self.request = request
        transcript = ""
        generation += 1
        let current = generation

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let isFinal = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor in
                    self?.handle(text: text, isFinal: isFinal, failed: failed, generation: current)
                }
            }
            capTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.maximumDuration)
                if !Task.isCancelled { self?.finish() }
            }
        }
    }

    func stop() {
        finish()
    }

    private func handle(text: String?, isFinal: Bool, failed: Bool, generation: Int) {
        guard generation == self.generation, continuation != nil else { return }
        if let text, !text.isEmpty {
            transcript = text
            onPartial?(text)
            silenceTimer?.cancel()
            silenceTimer = Task { [weak self] in
                try? await Task.sleep(for: Self.silenceTimeout)
                if !Task.isCancelled { self?.finish() }
            }
        }
        // "No speech detected" arrives as an error. It ends the turn with whatever was
        // heard, usually nothing, and the assistant decides what that means.
        if isFinal || failed { finish() }
    }

    private func finish() {
        silenceTimer?.cancel()
        capTimer?.cancel()
        if engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        continuation?.resume(returning: transcript)
        continuation = nil
    }
}
```

- [ ] **Step 2: Write `Speaker.swift`**

```swift
//
//  Speaker.swift
//  NOVA
//

import AVFoundation

protocol VoiceSpeaking: AnyObject {
    /// Speaks `text` and returns when it has finished or was stopped.
    func say(_ text: String, language: VoiceLanguage) async
    func stop()
}

/// Apple's built-in voices: free, offline, and already on the phone.
final class Speaker: NSObject, VoiceSpeaking, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    /// Which utterance the pending `say` is waiting on. A cancelled utterance's delegate
    /// callback arrives late, and without this check it would end the *next* line early.
    private var current: ObjectIdentifier?
    private var finished: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func say(_ text: String, language: VoiceLanguage) async {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice(for: language)
        // A beat between highlights, so ten lines don't run together into one.
        utterance.postUtteranceDelay = 0.25
        await withCheckedContinuation { continuation in
            finished = continuation
            current = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        current = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finished?.resume()
        finished = nil
    }

    private func ended(_ id: ObjectIdentifier) {
        guard id == current else { return }
        current = nil
        finished?.resume()
        finished = nil
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor in self.ended(id) }
    }

    /// The best installed voice for the exact locale, then any voice for the language.
    /// Enhanced and premium voices are much easier to listen to for ninety seconds, and
    /// readers who have downloaded one get it automatically.
    static func voice(for language: VoiceLanguage) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let exact = voices.filter { $0.language == language.localeIdentifier }
        let family = voices.filter { $0.language.hasPrefix(language.rawValue) }
        return (exact.isEmpty ? family : exact).max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: language.localeIdentifier)
    }
}
```

- [ ] **Step 3: Extend `SoundPlayer.swift`**

Change `play(_:)`'s guard to:

```swift
        guard isEnabled, !isVoiceActive, let player = players[effect] else { return }
```

Add below `var isEnabled = true`:

```swift
    /// True while the voice briefing owns the audio session. Effects stay quiet so a shot
    /// sound can't land in the middle of a spoken line.
    private(set) var isVoiceActive = false
```

Add before `// MARK: - Setup`:

```swift
    // MARK: - Voice

    /// Hands the session to the voice briefing: recording plus spoken playback, over the
    /// speaker rather than the earpiece, ducking anything else that's playing.
    func beginVoice() {
        isVoiceActive = true
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.defaultToSpeaker, .duckOthers, .allowBluetoothHFP]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Without the session the recogniser gets no audio. The listener then hears
            // nothing, and the assistant says so; nothing here needs to.
        }
        #endif
    }

    /// Takes the session back to `.ambient`, so the game keeps respecting the silent switch.
    func endVoice() {
        isVoiceActive = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
        configureSession()
    }
```

Don't add the `VoiceAudioSession` conformance yet. The protocol is declared in Task 6, and Task 6, Step 3 adds the conformance. If `.allowBluetoothHFP` doesn't exist in the SDK, use `.allowBluetooth`, which is the older name for the same option.

- [ ] **Step 4: Add the permission strings to both app configurations**

In `NOVA/NOVA.xcodeproj/project.pbxproj`, replace every occurrence (two: Debug and Release, currently lines 375 and 422) of

```
				INFOPLIST_KEY_CFBundleDisplayName = NOVA;
```

with

```
				INFOPLIST_KEY_CFBundleDisplayName = NOVA;
				INFOPLIST_KEY_NSMicrophoneUsageDescription = "NOVA listens only after you tap the mic, so you can ask for a news briefing.";
				INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "NOVA turns what you say into text to find the news you asked for. When this phone can't do that itself, Apple's speech service does.";
```

Without these the app is killed the moment it touches the microphone. It isn't a permission denial; it's a crash.

- [ ] **Step 5: Build**

Run: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error|BUILD" | head -20`
Expected: `** BUILD SUCCEEDED **`.
Then confirm the keys reached the built Info.plist:
```bash
plutil -p "$(xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2}')/Info.plist" | grep -E "Microphone|SpeechRecognition"
```
Expected: both keys print.

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Services/Voice/SpeechListener.swift NOVA/NOVA/Services/Voice/Speaker.swift NOVA/NOVA/Services/SoundPlayer.swift NOVA/NOVA.xcodeproj/project.pbxproj
git commit -m "Add speech listening, speaking and the voice audio session

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: VoiceAssistant state machine

**Files:**
- Create: `NOVA/NOVA/Services/Voice/VoiceAssistant.swift`
- Modify: `NOVA/NOVA/Services/SoundPlayer.swift` (add the `VoiceAudioSession` conformance)
- Test: `NOVA/NOVATests/VoiceAssistantTests.swift`

**Interfaces:**
- Consumes: `VoiceListening`, `VoiceSpeaking`, `ListenError` (Task 5), `BriefingWriter`, `FallbackBriefingWriter.standard`, `Highlights`, `VoiceIntent`, `VoiceLanguage`.
- Produces:
  - `protocol VoiceAudioSession: AnyObject { func beginVoice(); func endVoice() }`
  - `@Observable final class VoiceAssistant`, with:
    - `phase: Phase` (`idle`, `greeting`, `listening`, `thinking`, `speaking(Int)`, `done`, `failed(Failure)`) and `Failure` (`permissionDenied`, `nothingHeard`, `storiesLoading`, `briefingFailed`)
    - `transcript: String`, `briefing: Briefing?`, `language: VoiceLanguage`, `isActive: Bool`
    - `init(listener:speaker:writer:)`
    - `start(pool: [Story], readerName: String, language: VoiceLanguage, audio: (any VoiceAudioSession)?)`
    - `stop()`, and `waitUntilFinished() async`

- [ ] **Step 1: Write the failing tests**

```swift
//
//  VoiceAssistantTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

private func story(_ id: String, _ category: StoryCategory, hoursAgo: Double = 0) -> Story {
    Story(id: StoryID(id), title: "Headline \(id)", summary: "", source: "Src",
          category: category, publishedAt: Date(timeIntervalSince1970: 1_800_000_000 - hoursAgo * 3600),
          artwork: .none)
}

private let pool = [
    story("t1", .technology, hoursAgo: 0), story("t2", .technology, hoursAgo: 1),
    story("t3", .technology, hoursAgo: 2), story("i1", .india, hoursAgo: 3)
]

private final class FakeListener: VoiceListening {
    enum Reply { case heard(String), localeUnavailable }

    var replies: [Reply]
    let granted: Bool
    var onPartial: ((String) -> Void)?
    private(set) var languages: [VoiceLanguage] = []

    init(_ replies: [Reply], granted: Bool = true) {
        self.replies = replies
        self.granted = granted
    }

    func requestPermission() async -> Bool { granted }

    func listen(language: VoiceLanguage) async throws -> String {
        languages.append(language)
        guard !replies.isEmpty else { return "" }
        switch replies.removeFirst() {
        case .heard(let text):
            onPartial?(text)
            return text
        case .localeUnavailable:
            throw ListenError.localeUnavailable
        }
    }

    func stop() {}
}

private final class FakeSpeaker: VoiceSpeaking {
    private(set) var lines: [String] = []
    /// Called as each line starts, so a test can stop or restart mid-briefing.
    var onSay: ((String) -> Void)?

    func say(_ text: String, language: VoiceLanguage) async {
        lines.append(text)
        onSay?(text)
    }

    func stop() {}
}

private final class FakeAudio: VoiceAudioSession {
    private(set) var begins = 0
    private(set) var ends = 0
    func beginVoice() { begins += 1 }
    func endVoice() { ends += 1 }
}

private struct NoTranslation: HeadlineTranslating {
    func translate(_ lines: [String], to language: VoiceLanguage) async -> [String]? { nil }
}

@Suite("Voice assistant")
struct VoiceAssistantTests {

    private func assistant(_ listener: FakeListener, _ speaker: FakeSpeaker) -> VoiceAssistant {
        VoiceAssistant(listener: listener, speaker: speaker,
                       writer: RuleBriefingWriter(translator: NoTranslation()))
    }

    @Test("Greets, listens, and reads the briefing")
    func happyPath() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([.heard("tech news")]), speaker)
        voice.start(pool: pool, readerName: "Prakash", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(voice.phase == .done)
        #expect(voice.transcript == "tech news")
        #expect(voice.briefing?.items.map(\.storyID.rawValue) == ["t1", "t2", "t3"])
        #expect(speaker.lines == [
            "Hi Prakash, what news summary do you want?",
            "Here are the top 3 technology stories.",
            "1. Src: Headline t1", "2. Src: Headline t2", "3. Src: Headline t3"
        ])
        #expect(audio.begins == 1 && audio.ends == 1)
    }

    @Test("A denied permission says nothing and takes no audio")
    func permissionDenied() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([], granted: false), speaker)
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.permissionDenied))
        #expect(speaker.lines.isEmpty)
        #expect(audio.begins == 0)
    }

    @Test("An empty store says the stories are loading")
    func storiesLoading() async {
        let speaker = FakeSpeaker()
        let voice = assistant(FakeListener([]), speaker)
        voice.start(pool: [], readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.storiesLoading))
        #expect(speaker.lines == [VoiceLanguage.english.storiesLoading])
    }

    @Test("Hearing nothing asks once more, then gives up")
    func nothingHeard() async {
        let speaker = FakeSpeaker()
        let listener = FakeListener([.heard(""), .heard("  ")])
        let voice = assistant(listener, speaker)
        voice.start(pool: pool, readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.phase == .failed(.nothingHeard))
        #expect(listener.languages.count == 2)
        #expect(speaker.lines.filter { $0 == VoiceLanguage.english.didNotCatch }.count == 1)
    }

    @Test("No Hindi recognition switches to English and says so")
    func hindiFallsBackToEnglish() async {
        let speaker = FakeSpeaker()
        let listener = FakeListener([.localeUnavailable, .heard("tech news")])
        let voice = assistant(listener, speaker)
        voice.start(pool: pool, readerName: "", language: .hindi, audio: nil)
        await voice.waitUntilFinished()

        #expect(listener.languages == [.hindi, .english])
        #expect(speaker.lines.contains(VoiceLanguage.hindiRecognitionUnavailable))
        #expect(voice.language == .english)
        #expect(voice.phase == .done)
    }

    @Test("A topic with no stories today reads the newest of everything")
    func emptyCategoryFallsBackToAll() async {
        let voice = assistant(FakeListener([.heard("science news")]), FakeSpeaker())
        voice.start(pool: pool, readerName: "", language: .english, audio: nil)
        await voice.waitUntilFinished()

        #expect(voice.briefing?.items.count == 4)
        #expect(voice.phase == .done)
    }

    @Test("Stopping mid-briefing reads nothing more and hands back the audio")
    func stopMidBriefing() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let voice = assistant(FakeListener([.heard("tech news")]), speaker)
        speaker.onSay = { line in if line.hasPrefix("2.") { voice.stop() } }
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()

        #expect(speaker.lines.last?.hasPrefix("2.") == true)
        #expect(!speaker.lines.contains { $0.hasPrefix("3.") })
        #expect(voice.phase == .done)
        #expect(audio.ends == 1)
    }

    @Test("Starting again mid-run abandons the first run cleanly")
    func restartMidRun() async {
        let speaker = FakeSpeaker()
        let audio = FakeAudio()
        let listener = FakeListener([.heard("tech news"), .heard("india news")])
        let voice = assistant(listener, speaker)
        var restarted = false
        speaker.onSay = { line in
            if line.hasPrefix("1."), !restarted {
                restarted = true
                voice.start(pool: pool, readerName: "", language: .english, audio: audio)
            }
        }
        voice.start(pool: pool, readerName: "", language: .english, audio: audio)
        await voice.waitUntilFinished()
        // Let the abandoned first run reach its cancellation checks.
        await Task.yield()

        #expect(!speaker.lines.contains("2. Src: Headline t2"))
        #expect(voice.briefing?.items.first?.storyID.rawValue == "i1")
        #expect(voice.phase == .done)
        #expect(audio.begins == 2 && audio.ends == 2)
    }
}
```

The `restartMidRun` expectation is `ends == 2`: `stop()` inside the second `start` releases the first run's audio, and the second run releases its own. The first run's cleanup must **not** add a third release.

- [ ] **Step 2: Run and watch them fail**

Run: `xcodebuild … test -only-testing:NOVATests/VoiceAssistantTests`
Expected: build failure, "cannot find 'VoiceAssistant'".

- [ ] **Step 3: Write `VoiceAssistant.swift`, and add `extension SoundPlayer: VoiceAudioSession {}` to the end of `SoundPlayer.swift`**

```swift
//
//  VoiceAssistant.swift
//  NOVA
//

import Foundation
import Observation

/// Whoever owns the audio session. `SoundPlayer` in the app; a counter in tests.
protocol VoiceAudioSession: AnyObject {
    func beginVoice()
    func endVoice()
}

/// One spoken briefing: greet, listen once, answer, done.
///
/// Holds the flow and nothing device-specific. The microphone, the voice and the
/// writers come in through protocols, which is what lets the whole flow be tested
/// without a phone.
@Observable
final class VoiceAssistant {
    enum Phase: Equatable {
        case idle
        case greeting
        case listening
        case thinking
        /// Reading the item at this index.
        case speaking(Int)
        case done
        case failed(Failure)
    }

    enum Failure: Equatable {
        case permissionDenied
        case nothingHeard
        case storiesLoading
        case briefingFailed
    }

    private(set) var phase: Phase = .idle
    private(set) var transcript = ""
    private(set) var briefing: Briefing?
    /// The language in use, which can drop from Hindi to English mid-run.
    private(set) var language: VoiceLanguage = .english

    var isActive: Bool {
        switch phase {
        case .idle, .done, .failed: false
        default: true
        }
    }

    private let listener: any VoiceListening
    private let speaker: any VoiceSpeaking
    private let writer: any BriefingWriter

    private var run: Task<Void, Never>?
    /// Identifies the current run. An abandoned run finishes later than the one that
    /// replaced it, and must not release the audio the new run is holding.
    private var runID = 0
    private var audio: (any VoiceAudioSession)?
    private var holdsAudio = false

    init(
        listener: any VoiceListening = SpeechListener(),
        speaker: any VoiceSpeaking = Speaker(),
        writer: any BriefingWriter = FallbackBriefingWriter.standard
    ) {
        self.listener = listener
        self.speaker = speaker
        self.writer = writer
        listener.onPartial = { [weak self] text in self?.transcript = text }
    }

    func start(pool: [Story], readerName: String, language: VoiceLanguage, audio: (any VoiceAudioSession)?) {
        stop()
        runID += 1
        let id = runID
        self.audio = audio
        self.language = language
        transcript = ""
        briefing = nil
        run = Task { await perform(pool: pool, readerName: readerName, runID: id) }
    }

    func stop() {
        run?.cancel()
        run = nil
        listener.stop()
        speaker.stop()
        releaseAudio()
        if isActive { phase = briefing == nil ? .idle : .done }
    }

    /// Resolves when the latest run ends. Only tests wait on it.
    ///
    /// Loops because a run can be replaced while it's being awaited. Restarting mid-run
    /// swaps `run`, and waiting on the old one alone would return too early.
    func waitUntilFinished() async {
        while let current = run {
            await current.value
            if run == current { return }
        }
    }

    // MARK: - The run

    private func perform(pool: [Story], readerName: String, runID id: Int) async {
        defer { if id == runID { releaseAudio() } }

        guard await listener.requestPermission() else {
            if !Task.isCancelled { phase = .failed(.permissionDenied) }
            return
        }
        guard !Task.isCancelled else { return }
        takeAudio()

        guard !pool.isEmpty else {
            phase = .failed(.storiesLoading)
            await speaker.say(language.storiesLoading, language: language)
            return
        }

        phase = .greeting
        await speaker.say(language.greeting(name: readerName), language: language)
        guard !Task.isCancelled else { return }

        guard let heard = await listenForRequest() else {
            if !Task.isCancelled { phase = .failed(.nothingHeard) }
            return
        }

        phase = .thinking
        var intent = VoiceIntent.parse(heard)
        var candidates = Highlights.candidates(for: intent, from: pool, limit: Highlights.aiCandidateLimit)
        if candidates.isEmpty {
            // Nothing in that topic today. The newest of everything beats silence, and the
            // intro names no topic, so it doesn't claim these are what was asked for.
            intent.category = nil
            candidates = Highlights.candidates(for: intent, from: pool, limit: Highlights.aiCandidateLimit)
        }

        let result = try? await writer.brief(request: heard, intent: intent, language: language, candidates: candidates)
        guard !Task.isCancelled else { return }
        guard let result else {
            phase = .failed(.briefingFailed)
            return
        }
        briefing = result

        await speaker.say(result.intro, language: language)
        for (index, item) in result.items.enumerated() {
            guard !Task.isCancelled else { return }
            phase = .speaking(index)
            await speaker.say("\(index + 1). \(item.line)", language: result.lineLanguage)
        }
        guard !Task.isCancelled else { return }
        phase = .done
    }

    /// Listens up to twice. Returns nil when nothing usable was heard.
    private func listenForRequest() async -> String? {
        var misses = 0
        while misses < 2 {
            guard !Task.isCancelled else { return nil }
            phase = .listening
            transcript = ""
            do {
                let heard = try await listener.listen(language: language)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !heard.isEmpty { return heard }
            } catch ListenError.localeUnavailable where language == .hindi {
                // This phone can't recognise Hindi. Say so in Hindi, then carry on in
                // English: a briefing in the other language beats none.
                await speaker.say(VoiceLanguage.hindiRecognitionUnavailable, language: .hindi)
                language = .english
                continue
            } catch {
                // Anything else counts as not hearing the reader.
            }
            misses += 1
            if misses < 2, !Task.isCancelled {
                await speaker.say(language.didNotCatch, language: language)
            }
        }
        return nil
    }

    // MARK: - Audio

    private func takeAudio() {
        guard !holdsAudio else { return }
        audio?.beginVoice()
        holdsAudio = true
    }

    private func releaseAudio() {
        guard holdsAudio else { return }
        audio?.endVoice()
        holdsAudio = false
    }
}
```

About `restartMidRun`: the second `start` runs *inside* the first run's `say("1. …")`.
1. `stop()` cancels run 1 and releases its audio (ends = 1).
2. Run 2 begins (begins = 2) and eventually ends (ends = 2).
3. Run 1 resumes after `say` returns, sees `Task.isCancelled`, and returns. Its `defer` skips the release because `id != runID`.

`waitUntilFinished` follows `run` to run 2, so the test's assertions see the final state.

- [ ] **Step 4: Run and watch them pass**

Run: the Step 2 command. Expected: `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add NOVA/NOVA/Services/Voice/VoiceAssistant.swift NOVA/NOVA/Services/SoundPlayer.swift NOVA/NOVATests/VoiceAssistantTests.swift
git commit -m "Add the voice assistant state machine

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Floater, panel, and RootView wiring

**Files:**
- Create: `NOVA/NOVA/Features/Voice/VoiceFloater.swift`
- Create: `NOVA/NOVA/Features/Voice/VoiceBriefingPanel.swift`
- Modify: `NOVA/NOVA/App/RootView.swift`

**Interfaces:**
- Consumes:
  - `VoiceAssistant` (Task 6), `NewsStore.allStories`, `SoundPlayer`
  - `AppRouter.tab` / `pushHome(_:)` / `path`, `HomeRoute.story(_:)`
  - `PressableStyle`, `PaperButtonStyle` (`Components/NovaButtons.swift`)
  - `Nova.*` tokens, `novaMeta()` (`DesignSystem/NovaTheme.swift`)
- Produces: `VoiceFloater(action:)` and `VoiceBriefingPanel()`.

- [ ] **Step 1: Write `VoiceFloater.swift`**

```swift
//
//  VoiceFloater.swift
//  NOVA
//

import SwiftUI

/// The mic that opens the voice briefing.
///
/// Ink on sheet with a hairline, like the other paper controls. No glass, because the
/// tab bar is the one piece of glass the design system allows (DESIGN.md).
struct VoiceFloater: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Nova.ink)
                .frame(width: 58, height: 58)
                .background(Nova.sheet, in: Circle())
                .overlay(Circle().strokeBorder(Nova.hairline))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Ask NOVA for a news briefing")
    }
}

#Preview {
    VoiceFloater {}
        .padding(40)
        .background(Nova.paper)
}
```

- [ ] **Step 2: Write `VoiceBriefingPanel.swift`**

```swift
//
//  VoiceBriefingPanel.swift
//  NOVA
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// The sheet the floater opens: what NOVA is doing, what it heard, and what it read.
///
/// Reading surface, so paper. The row being read is the only one at full strength, and
/// the rest step back. That uses opacity, not marigold, because nothing here is earned.
struct VoiceBriefingPanel: View {
    @Environment(VoiceAssistant.self) private var voice
    @Environment(NewsStore.self) private var store
    @Environment(SoundPlayer.self) private var sound
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @AppStorage("readerName") private var readerName = ""
    @AppStorage("voiceLanguage") private var languageRaw = VoiceLanguage.preferred().rawValue

    private var chosenLanguage: VoiceLanguage { VoiceLanguage(rawValue: languageRaw) ?? .english }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            status
            if let briefing = voice.briefing {
                list(briefing)
            } else {
                Spacer(minLength: 0)
            }
            controls
        }
        .padding(Nova.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .foregroundStyle(Nova.ink)
        .presentationBackground(Nova.paper)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onAppear(perform: begin)
        // Closing the sheet is a stop. Nothing should keep talking once it's gone.
        .onDisappear { voice.stop() }
    }

    private func begin() {
        voice.start(pool: store.allStories, readerName: readerName, language: chosenLanguage, audio: sound)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Ask NOVA")
                .font(Nova.display(.title2))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            languageChip
        }
    }

    private var languageChip: some View {
        HStack(spacing: 0) {
            ForEach(VoiceLanguage.allCases, id: \.self) { language in
                let selected = voice.language == language
                Button {
                    languageRaw = language.rawValue
                    // A new language is a new question: start over in it.
                    begin()
                } label: {
                    Text(language.chipTitle)
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 32)
                        .foregroundStyle(selected ? Nova.paper : Nova.ink)
                        .background(selected ? Nova.ink : .clear, in: Capsule())
                }
                .buttonStyle(PressableStyle())
                .accessibilityLabel(language == .english ? "English" : "Hindi")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(3)
        .overlay(Capsule().strokeBorder(Nova.hairline))
    }

    // MARK: - Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(statusTitle)
                .novaMeta()
                .foregroundStyle(.secondary)

            switch voice.phase {
            case .greeting:
                Text(voice.language.greeting(name: readerName))
                    .font(Nova.reading(.title3))
            case .listening, .thinking:
                Text(voice.transcript.isEmpty ? "…" : "“\(voice.transcript)”")
                    .font(Nova.reading(.title3))
            case .failed(.permissionDenied):
                Text("NOVA needs the microphone and speech recognition to hear your question.")
                    .font(Nova.reading(.body))
                if let url = VoiceSettings.url {
                    Button("Open Settings") { openURL(url) }
                        .buttonStyle(PaperButtonStyle())
                }
            case .failed(.storiesLoading):
                Text("Stories are still loading. Try again in a moment.")
                    .font(Nova.reading(.body))
            case .failed(.nothingHeard):
                Text("I didn't catch that. Tap Ask again and say a topic, like “tech news”.")
                    .font(Nova.reading(.body))
            case .failed(.briefingFailed):
                Text("I couldn't put a briefing together. Try again in a moment.")
                    .font(Nova.reading(.body))
            case .idle, .speaking, .done:
                EmptyView()
            }

            if voice.briefing?.tier.isMachineWritten == true {
                // Machine-written and unchecked, so it must not read as verified reporting.
                Text("AI-written · unchecked")
                    .novaMeta()
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statusTitle: String {
        switch voice.phase {
        case .idle: "Ready"
        case .greeting: "Speaking"
        case .listening: "Listening"
        case .thinking: "Finding stories"
        case .speaking: "Briefing"
        case .done: "Done"
        case .failed: "Couldn't brief you"
        }
    }

    // MARK: - List

    private func list(_ briefing: Briefing) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(briefing.items.enumerated()), id: \.element.id) { index, item in
                    Button { open(item.storyID) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text("\(index + 1)")
                                .font(Nova.meta(.subheadline, weight: .medium))
                                .frame(width: 22, alignment: .trailing)
                            Text(item.line)
                                .font(Nova.reading(.body))
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 12)
                        .opacity(isDimmed(index) ? 0.45 : 1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityHint("Opens the story")

                    Rectangle().fill(Nova.hairline).frame(height: 1)
                }
            }
            .animation(reduceMotion ? nil : Nova.Motion.settle, value: voice.phase)
        }
    }

    /// While a line is being read, every other line steps back.
    private func isDimmed(_ index: Int) -> Bool {
        if case .speaking(let current) = voice.phase { return current != index }
        return false
    }

    private func open(_ id: StoryID) {
        voice.stop()
        dismiss()
        router.tab = .home
        router.pushHome(.story(id))
    }

    // MARK: - Controls

    private var controls: some View {
        Group {
            if voice.isActive {
                Button("Stop") { voice.stop() }
            } else {
                Button("Ask again", action: begin)
            }
        }
        .buttonStyle(PaperButtonStyle())
    }
}

/// The app's page in Settings, where a denied permission is turned back on.
/// Settings deep links only exist on iOS and visionOS; elsewhere there is no button.
enum VoiceSettings {
    static var url: URL? {
        #if os(iOS) || os(visionOS)
        URL(string: UIApplication.openSettingsURLString)
        #else
        nil
        #endif
    }
}
```

If `Nova.meta` takes no `weight:` argument, drop it. Check its signature at `DesignSystem/NovaTheme.swift` next to `novaMeta()`. Also check that `Nova.Motion.settle` exists under that name.

- [ ] **Step 3: Wire up `RootView.swift`**

Add state next to the others:

```swift
    @State private var voice = VoiceAssistant()
    @State private var showsVoicePanel = false
```

Add this computed property below `body`:

```swift
    /// The mic stays off the charcoal round: the slingshot is aimed near the bottom edge,
    /// where the button would sit. It also waits for onboarding to finish.
    private var showsVoiceFloater: Bool {
        hasSeenWelcome && !(router.tab == .scroll && !router.path.isEmpty)
    }
```

Right after the `ZStack { … }` closing brace and **before** `.environment(session)`, add:

```swift
        // Written before the `.environment` calls so the sheet sits inside them. A sheet
        // presents its own hierarchy, and it only inherits what was injected above the
        // point it's attached. Attached after the injections, the panel would crash
        // looking for `VoiceAssistant`.
        .overlay(alignment: .bottomTrailing) {
            if showsVoiceFloater {
                VoiceFloater { showsVoicePanel = true }
                    .padding(.trailing, Nova.screenPadding)
                    // Clears the floating tab bar.
                    .padding(.bottom, 72)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsVoicePanel) {
            VoiceBriefingPanel()
        }
```

Add `.environment(voice)` after `.environment(history)`.

Add the DEBUG launch argument inside the existing `.task`, after `simulateRoundIfAsked()`:

```swift
            #if DEBUG
            // `-openVoice YES` opens the briefing on launch. Synthetic taps aren't available
            // from a shell, so this is the only way to screenshot the panel. Read-only, like
            // the other arguments.
            if UserDefaults.standard.bool(forKey: "openVoice") { showsVoicePanel = true }
            #endif
```

- [ ] **Step 4: Build and run the whole suite**

Run: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -20`
Expected: `** TEST SUCCEEDED **`, with every earlier suite still green.

- [ ] **Step 5: Screenshot the floater and the panel**

```bash
APP=$(xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -showBuildSettings 2>/dev/null | awk -F' = ' '/ CODESIGNING_FOLDER_PATH /{print $2}')
xcrun simctl install booted "$APP"
xcrun simctl launch --terminate-running-process booted com.iosnewsapp.NOVA -startTab home
sleep 4; xcrun simctl io booted screenshot /tmp/voice-floater.png
xcrun simctl launch --terminate-running-process booted com.iosnewsapp.NOVA -openVoice YES
sleep 4; xcrun simctl io booted screenshot /tmp/voice-panel.png
```
(Use the session scratchpad for the PNGs instead of `/tmp` when one exists.)

Check that:
- The floater clears the tab bar and doesn't cover the deck's controls. Adjust the `72` if not.
- The panel is on paper and shows "Speaking" with the greeting, or a permission prompt on first launch.

If onboarding covers the screen, the simulator never finished it. Finish it once by hand. Don't add a `-hasSeenWelcome` argument (see CLAUDE.md).

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Features/Voice NOVA/NOVA/App/RootView.swift
git commit -m "Add the voice briefing floater and panel

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: Manual verification and CLAUDE.md

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/specs/2026-09-27-voice-briefing-design.md` (one line)

- [ ] **Step 1: Manual run on the simulator**

The simulator uses the Mac's microphone. Run `open -a Simulator`, launch the app, and check each of these:
1. On Home, tap the mic and allow both permissions. You should hear the greeting.
2. Say "tech news". You should hear an intro and up to ten lines, with the current row at full strength.
3. Tap a row. The sheet closes, Home opens the story, and the speech stops.
4. Tap the mic, then Stop mid-briefing. The speech stops at once.
5. Switch to हिं and say "टेक की खबरें". You should get a Hindi briefing, or the English-fallback line if Hindi recognition isn't available.
6. Open the Scroll tab and start the quiz. The mic is gone on the intro, quiz and results screens.
7. Deny permission. To reset it, run `xcrun simctl privacy booted reset microphone com.iosnewsapp.NOVA` and relaunch. The panel should show the Settings button.

Write down which tier answered each run (from the "AI-written · unchecked" label: present means ZeroAPI or on-device). Tell the reader if Hindi recognition or the Hindi voice was missing on the simulator.

- [ ] **Step 2: Add a Voice section to `CLAUDE.md`**, after the **Sound** paragraph:

```markdown
**Voice (`Services/Voice/`, `Features/Voice/`)** — the mic floater: greet, listen once, speak up to
ten one-line highlights from `NewsStore.allStories`, in English or Hindi. Free by construction:
Apple Speech in, `AVSpeechSynthesizer` out, and the lines come from `FallbackBriefingWriter` —
ZeroAPI, then Foundation Models, then `RuleBriefingWriter`, which can't fail on a non-empty pool
and so is the only tier with no timeout. Keep that last tier working; it is what the button says
when both AI tiers are down.
- `VoiceAssistant` depends only on protocols (`VoiceListening`, `VoiceSpeaking`,
  `VoiceAudioSession`, `BriefingWriter`) so the whole flow is tested with fakes.
- Stories go to models by number, not ID — feed IDs are URLs and ate the token budget.
- Audio-thread and delegate closures in `SpeechListener` / `Speaker` are `@Sendable` or
  `nonisolated` on purpose: under default MainActor isolation an unannotated tap closure is
  inferred main-actor and traps when audio arrives.
- `SoundPlayer.beginVoice()` / `endVoice()` swap `.ambient` for `.playAndRecord` and back; an
  abandoned run must not call `endVoice()` under the run that replaced it (`runID`).
- The floater hides during onboarding and on quiz routes. The panel's sheet is attached *inside*
  `RootView`'s `.environment` calls. `-openVoice YES` (DEBUG) opens it on launch for screenshots.
```

The bullet claiming "feed IDs are URLs and ate the token budget" is a design decision, not something observed. Word it as "would eat" unless the manual run showed otherwise.

- [ ] **Step 3: Fix the spec's `SoundPlayer` method names**

In the spec's Audio session paragraph, change `` `suspend()` / `resume()` `` to `` `beginVoice()` / `endVoice()` ``.

- [ ] **Step 4: Full suite one last time and commit**

```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | tail -5
git add CLAUDE.md docs/superpowers/specs/2026-09-27-voice-briefing-design.md
git commit -m "Document the voice briefing

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```
Expected: `** TEST SUCCEEDED **`.
