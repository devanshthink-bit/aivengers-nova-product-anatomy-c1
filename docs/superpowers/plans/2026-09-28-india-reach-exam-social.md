# India reach, exam prep and sharing — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give NOVA's Indian readers Hindi news and UI, cricket and entertainment, an exam-prep revision tab, WhatsApp-friendly sharing, a daily reminder, calmer onboarding topic tiles and category tabs on Home — all free.

**Architecture:** Rules stay in plain, SwiftUI-free types that are unit-tested (`LiveNewsService.pick`, `QuestionArchive`, `RevisionPicker`, `ShareGrid`, `ReminderPlan`). Views only render them and send actions. New stores (`QuestionArchive`, `ReminderScheduler`) are `@Observable`, created in `RootView` and injected with `.environment()` like the existing ones. Language is a feed property plus a generator setting. The UI's own strings go through one String Catalog.

**Tech Stack:** Swift 6 / SwiftUI, Swift Testing, `XMLParser`, `UNUserNotificationCenter`, `ImageRenderer`, `ShareLink`, String Catalogs (`xcstringstool`). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-09-28-india-reach-exam-social-design.md`

## Global Constraints

- Everything is free: no SDKs, keys, accounts, paid APIs, push server or CloudKit. Only RSS, ZeroAPI (already used), local notifications, and on-device rendering and storage.
- The multiplatform target (iOS, macOS, visionOS, deployment 26.0) must keep building. iOS-only APIs are wrapped in `NovaTheme.swift` helpers, never raw `#if os(iOS)` at call sites.
- Default isolation is MainActor. Audio and notification delegate closures stay `@Sendable`/`nonisolated` where they cross threads.
- A feed only earns a category if everything in it belongs there.
- Generated text is labelled as machine-written wherever it is shown or shared.
- Progress is honest: revision never touches `PlayHistory` or the streak, and a round with no questions records nothing.
- Every interaction works without the gesture. Reduce Motion is honoured.
- Design rules: paper for reading, charcoal for play. Category tints are fills and squares only. Marigold only when earned. No glass, no gradients behind surfaces.
- Comments explain *why*. Match the surrounding density and don't strip existing ones.
- Build and test: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`, run from `NOVA/`. Abbreviated below as `$TEST`. A single suite: `$TEST -only-testing:NOVATests/<SuiteStruct>`.
- One commit per task, ending with `Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>`.

## Review Focus

1. **Content language switched mid-day.** Expect the deck, Home and the round to reload in the new language and reading progress to reset. The archive keeps what was already answered. Test: `DailySessionTests.reloadKeepsArchive` (Task 4).
2. **A re-asked question after relaunch** (the round isn't persisted, so the same questions come back). Expect the archive to keep one entry with the *first* attempt's result. Test: `QuestionArchiveTests.duplicateAnswerKeepsFirst` (Task 4).
3. **A corrupt or truncated archive file.** Expect an empty archive, the bad file kept as `.corrupt`, and no crash. Test: `QuestionArchiveTests.corruptFileIsSetAside` (Task 4).
4. **A reminder time already past today, or today already played.** Expect the first reminder tomorrow and today's reminder removed. Tests: `ReminderPlanTests.pastTimeStartsTomorrow` and `ReminderSchedulerTests.markTodayDoneRemovesToday` (Task 6).
5. **A Home category chip with no stories** (Science in Hindi, a feed down). Expect the chip to be absent, and the selection to fall back to All. Test: `NewsStoreTests.categoriesListOnlyPresent` (Task 7).

---

## File map

| File | Status | Responsibility |
|---|---|---|
| `NOVA/NOVA/Models/Story.swift` | modify | `StoryCategory` + `.sports`, `.entertainment` |
| `NOVA/NOVA/Models/ContentLanguage.swift` | create | news language enum |
| `NOVA/NOVA/Models/Question.swift` | modify | `explanation` |
| `NOVA/NOVA/DesignSystem/NovaTheme.swift` | modify | two tints, `openAppSettings` helper |
| `NOVA/NOVA/Services/RSSFeed.swift` | modify | `language`, new feeds, rejects list |
| `NOVA/NOVA/Services/NewsService.swift` | modify | `pick(from:topics:)`, `FeedLoader(language:)`, `LiveNewsService.topics` |
| `NOVA/NOVA/Services/QuestionGenerator.swift` | modify | language + exam rules + `context` |
| `NOVA/NOVA/Services/NewsStore.swift` | modify | language reload, `latest(limit:category:)`, `categories` |
| `NOVA/NOVA/GameLogic/QuestionArchive.swift` | create | persisted answers |
| `NOVA/NOVA/GameLogic/RevisionPicker.swift` | create | which questions to revise |
| `NOVA/NOVA/GameLogic/ShareGrid.swift` | create | emoji share text |
| `NOVA/NOVA/GameLogic/DailySession.swift` | modify | archive recording, `storyOutcomes` |
| `NOVA/NOVA/Services/ReminderScheduler.swift` | create | `ReminderPlan`, scheduler, centre protocol |
| `NOVA/NOVA/Features/Onboarding/Pages/LanguagePage.swift` | create | first onboarding page |
| `NOVA/NOVA/Features/Onboarding/Pages/TopicsPage.swift` | modify | inverted-white tiles, `Grid` |
| `NOVA/NOVA/Features/Onboarding/OnboardingPage.swift`, `OnboardingFlow.swift` | modify | six pages |
| `NOVA/NOVA/Features/Prep/PrepView.swift` | create | Prep tab |
| `NOVA/NOVA/Features/Prep/RevisionView.swift` | create | tap-to-answer revision |
| `NOVA/NOVA/Features/Share/ShareCards.swift` | create | scorecard + question card views, renderer |
| `NOVA/NOVA/Components/TopicChip.swift` | create | chip shared by Profile and Home |
| `NOVA/NOVA/Features/Home/HomeView.swift` | modify | pinned category tabs |
| `NOVA/NOVA/Features/Profile/ProfileView.swift` | modify | language, app language, reminder |
| `NOVA/NOVA/Features/Results/ResultsView.swift` | modify | share, explanation, reminder offer |
| `NOVA/NOVA/App/RootView.swift`, `AppRouter.swift` | modify | Prep tab, stores, language reload |
| `NOVA/NOVA/Resources/Localizable.xcstrings` | create | en + hi |
| `NOVA/NOVA.xcodeproj/project.pbxproj` | modify | `knownRegions += hi` |
| `NOVA/NOVATests/Fixtures/*.xml` | create | trimmed real samples |
| `NOVA/NOVATests/*Tests.swift` | create/modify | as listed per task |

---

### Task 1: Sports and entertainment, Indian English feeds, topic-aware pick

**Files:**
- Modify: `NOVA/NOVA/Models/Story.swift:35-60`
- Modify: `NOVA/NOVA/DesignSystem/NovaTheme.swift:110-123`
- Modify: `NOVA/NOVA/Services/RSSFeed.swift`
- Modify: `NOVA/NOVA/Services/NewsService.swift` (`pick`, `LiveNewsService`)
- Modify: `NOVA/NOVA/App/RootView.swift` (pass topics)
- Modify: `NOVA/NOVA/Features/Home/HomeView.swift` ("Reading nine feeds")
- Create: `NOVA/NOVATests/Fixtures/<publisher>.xml` (one per new publisher format)
- Test: `NOVA/NOVATests/NewsServiceTests.swift`, `NOVA/NOVATests/RSSParserTests.swift`

**Interfaces:**
- Produces: `StoryCategory.sports`, `.entertainment`. `LiveNewsService.pick(from: [Story], topics: TopicSelection = TopicSelection()) -> [Story]`. `LiveNewsService.topics: TopicSelection`.

- [ ] **Step 1: Write the failing pick tests** (append to `StorySelectionTests`)

```swift
    @Test("Chosen categories are picked before newer stories from the rest")
    func chosenCategoriesWin() {
        let pool = [
            story("w", .world, hoursAgo: 1), story("t", .technology, hoursAgo: 1),
            story("b", .business, hoursAgo: 1), story("i", .india, hoursAgo: 1),
            story("sc", .science, hoursAgo: 1), story("en", .entertainment, hoursAgo: 1),
            story("sp", .sports, hoursAgo: 20)
        ]
        let picked = LiveNewsService.pick(from: pool, topics: TopicSelection(categories: [.sports]))

        #expect(picked.count == 5)
        #expect(picked.contains { $0.category == .sports })
    }

    @Test("With no topics, seven categories still yield five distinct ones")
    func sevenCategoriesNoTopics() {
        let pool = StoryCategory.allCases.enumerated().map { index, category in
            story("s\(index)", category, hoursAgo: Double(index))
        }
        let picked = LiveNewsService.pick(from: pool)

        #expect(picked.count == 5)
        #expect(Set(picked.map(\.category)).count == 5)
    }
```

- [ ] **Step 2: Run to verify failure**

Run: `$TEST -only-testing:NOVATests/StorySelectionTests`
Expected: compile error, because `.sports` and `pick(from:topics:)` don't exist.

- [ ] **Step 3: Add the categories.** In `Story.swift`, add `case sports` and `case entertainment` to `StoryCategory`, with titles `"Sports"` / `"Entertainment"` and symbols `"cricket.ball"` / `"film"`. In `NovaTheme.swift` `tint`, add `case .sports: Color(hex: 0x138496)` (deep teal, clear of Jade and Sky) and `case .entertainment: Color(hex: 0xD6457A)` (rose, clear of Vermilion and Plum). Extend the doc comment: "Teal and Rose joined when sports and entertainment did (2026-09-28)."

- [ ] **Step 4: Rewrite `pick`** in `NewsService.swift`:

```swift
    /// Newest first, deduplicated, at most one per category — the reader's chosen
    /// categories filled first.
    ///
    /// Chosen-first became necessary at seven categories: with five slots, "newest per
    /// category" let whichever two published last drop out, and that was sometimes the
    /// category the reader asked for. The deck still never filters — unchosen categories
    /// fill the remaining slots, and a short day is topped up with the next newest.
    static func pick(from stories: [Story], topics: TopicSelection = TopicSelection()) -> [Story] {
        var seenTitles: Set<String> = []
        let unique = stories
            .sorted { $0.publishedAt > $1.publishedAt }
            .filter { seenTitles.insert($0.title.lowercased()).inserted }

        var chosen: [Story] = []
        var usedCategories: Set<StoryCategory> = []

        func take(where include: (Story) -> Bool) {
            for story in unique where chosen.count < storyCount
                && !usedCategories.contains(story.category) && include(story) {
                chosen.append(story)
                usedCategories.insert(story.category)
            }
        }

        take { topics.contains($0.category) }
        take { _ in true }

        for story in unique where chosen.count < storyCount && !chosen.contains(where: { $0.id == story.id }) {
            chosen.append(story)
        }
        return chosen
    }
```

Add `var topics = TopicSelection()` to `LiveNewsService`, and call `Self.pick(from: fetched, topics: topics)`. Update the `storyCount` comment: "Five slots across seven categories; see `pick`."

In `RootView` (both `LiveNewsService(prefetched:)` calls), pass `topics: TopicSelection(rawValue: pickedTopicsRaw)`.

- [ ] **Step 5: Add the English feeds** to `RSSFeed.all`, under their category comments, exactly:

```swift
        RSSFeed(source: "Indian Express", category: .india,
                url: URL(string: "https://indianexpress.com/section/india/feed/")!),
        // Sports
        RSSFeed(source: "The Hindu Cricket", category: .sports,
                url: URL(string: "https://www.thehindu.com/sport/cricket/feeder/default.rss")!),
        RSSFeed(source: "Indian Express Sports", category: .sports,
                url: URL(string: "https://indianexpress.com/section/sports/feed/")!),
        // Entertainment
        RSSFeed(source: "The Hindu Entertainment", category: .entertainment,
                url: URL(string: "https://www.thehindu.com/entertainment/feeder/default.rss")!),
        RSSFeed(source: "Bollywood Hungama", category: .entertainment,
                url: URL(string: "https://www.bollywoodhungama.com/rss/news.xml")!),
        // (business)
        RSSFeed(source: "Business Standard", category: .business,
                url: URL(string: "https://www.business-standard.com/rss/markets-106.rss")!),
        // (technology)
        RSSFeed(source: "Inc42", category: .technology,
                url: URL(string: "https://inc42.com/feed/")!),
        // (science)
        RSSFeed(source: "The Hindu Science", category: .science,
                url: URL(string: "https://www.thehindu.com/sci-tech/science/feeder/default.rss")!),
```

Append the spec's rejected list, with its reasons, to the comment block at the bottom. Also fix the "nine feeds" wording in the `FeedLoader` and `LiveNewsService` comments, and change HomeView's `Text("Reading nine feeds")` to `Text("Reading the feeds")`.

- [ ] **Step 6: Save parser fixtures.** For each new publisher format — Indian Express, The Hindu (sport), Bollywood Hungama, Business Standard, Inc42 — fetch the feed with a browser User-Agent. Keep the XML prolog, `<rss …>` with its namespaces, `<channel>`, and the first **two** `<item>`s verbatim. Save as `NOVA/NOVATests/Fixtures/<slug>.xml` (`indianexpress.xml`, `thehindu-sport.xml`, `bollywoodhungama.xml`, `businessstandard.xml`, `inc42.xml`). The folder is inside the synchronized `NOVATests` group, so the files are copied into the test bundle.

- [ ] **Step 7: Write the fixture test** (new suite at the bottom of `RSSParserTests.swift`)

```swift
/// Each publisher added on 2026-09-28, parsed from a trimmed copy of what its feed really
/// returned. One case per *format*, not per URL: The Hindu's cricket and science feeds
/// share one template.
@Suite("Indian publisher samples")
struct IndianPublisherSampleTests {
    private final class Token {}

    static let samples: [(file: String, category: StoryCategory)] = [
        ("indianexpress", .india), ("thehindu-sport", .sports), ("bollywoodhungama", .entertainment),
        ("businessstandard", .business), ("inc42", .technology)
    ]

    @Test("Every sample yields stories with a title, a date and a picture", arguments: samples)
    func parses(sample: (file: String, category: StoryCategory)) throws {
        let url = try #require(Bundle(for: Token.self).url(forResource: sample.file, withExtension: "xml"))
        let feed = RSSFeed(source: sample.file, category: sample.category, url: url)

        let stories = RSSParser(feed: feed).parse(try Data(contentsOf: url))

        #expect(stories.count == 2)
        #expect(stories.allSatisfy { !$0.title.isEmpty })
        #expect(stories.allSatisfy { $0.publishedAt > Date(timeIntervalSince1970: 1_700_000_000) })
        #expect(stories.allSatisfy { if case .remote = $0.artwork { true } else { false } })
    }
}
```

- [ ] **Step 8: Run the suites**

Run: `$TEST -only-testing:NOVATests/StorySelectionTests -only-testing:NOVATests/IndianPublisherSampleTests -only-testing:NOVATests/RSSParserTests`
Expected: PASS. If a sample fails on the date or the image, fix `RSSParser` (a new date format, or an image tag), then add a focused case to `RSSParserTests` for that shape. Don't drop the item.

- [ ] **Step 9: Full suite, then commit**

Run: `$TEST` → all pass.
```bash
git add -A && git commit -m "Add sports and entertainment, Indian English feeds, and pick chosen topics first

Co-Authored-By: Claude Opus 5.5 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Content language — Hindi feeds, Hindi generation, onboarding and Profile choice

**Files:**
- Create: `NOVA/NOVA/Models/ContentLanguage.swift`
- Create: `NOVA/NOVA/Features/Onboarding/Pages/LanguagePage.swift`
- Modify: `RSSFeed.swift`, `NewsService.swift` (`FeedLoader`), `QuestionGenerator.swift`, `NewsStore.swift`, `OnboardingPage.swift`, `OnboardingFlow.swift`, `ProfileView.swift`, `RootView.swift`, `StoryReaderView.swift` (failed state), `NovaTheme.swift`
- Test: `NOVA/NOVATests/ContentLanguageTests.swift` (new), `OnboardingTests.swift`, `NewsStoreTests.swift`

**Interfaces:**
- Consumes: `StoryCategory` (Task 1).
- Produces: `enum ContentLanguage: String { case english = "en", hindi = "hi" }` with `nativeName`, `voice: VoiceLanguage`, `static func preferred(from:)`, `static let storageKey = "contentLanguage"`. `RSSFeed.language`, `RSSFeed.feeds(for:) -> [RSSFeed]`. `FeedLoader(language:)`. `QuestionGenerator.language`, `QuestionGenerator.systemPrompt(for:) -> String` (internal static). `NewsStore.setLanguage(_:) async`. `OnboardingPage.language` as the first case. `Nova.openAppSettings(using: OpenURLAction)`.

- [ ] **Step 1: Failing tests** — create `ContentLanguageTests.swift`:

```swift
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
```

In `OnboardingTests.swift`, update `OnboardingPageTests` so `allCases.first == .language`, `OnboardingPage.language.next == .manifesto`, and `OnboardingPage.language.number == 1`. Walking from `.language` must visit all six pages.

- [ ] **Step 2: Run** `$TEST -only-testing:NOVATests/ContentLanguageTests -only-testing:NOVATests/OnboardingPageTests`. Expected: compile failure.

- [ ] **Step 3: Create `ContentLanguage.swift`**

```swift
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
```

- [ ] **Step 4: Add language to feeds.** Add `var language: ContentLanguage = .english` to `RSSFeed` (a stored `let` with a default in the memberwise init: declare `let language: ContentLanguage` and add an explicit `init(source:category:url:language: = .english)`). Add:

```swift
    static func feeds(for language: ContentLanguage) -> [RSSFeed] {
        all.filter { $0.language == language }
    }
```

Append the Hindi feeds to `all` under a `// Hindi — section feeds only, so each one's category is pure` comment. They are exactly these 17 (`source`, `category`, URL):

```
Live Hindustan  .india         https://api.livehindustan.com/feeds/rss/national/rssfeed.xml
Live Hindustan  .world         https://api.livehindustan.com/feeds/rss/international/rssfeed.xml
Live Hindustan  .sports        https://api.livehindustan.com/feeds/rss/cricket/rssfeed.xml
Live Hindustan  .business      https://api.livehindustan.com/feeds/rss/business/rssfeed.xml
Live Hindustan  .entertainment https://api.livehindustan.com/feeds/rss/entertainment/rssfeed.xml
Live Hindustan  .technology    https://api.livehindustan.com/feeds/rss/gadgets/rssfeed.xml
News18 Hindi    .india         https://hindi.news18.com/rss/khabar/nation/nation.xml
News18 Hindi    .world         https://hindi.news18.com/rss/khabar/world/world.xml
News18 Hindi    .sports        https://hindi.news18.com/rss/khabar/sports/sports.xml
News18 Hindi    .business      https://hindi.news18.com/rss/khabar/business/business.xml
News18 Hindi    .entertainment https://hindi.news18.com/rss/khabar/entertainment/entertainment.xml
News18 Hindi    .technology    https://hindi.news18.com/rss/khabar/tech/tech.xml
Dainik Bhaskar  .india         https://www.bhaskar.com/rss-v1--category-1061.xml
Dainik Bhaskar  .world         https://www.bhaskar.com/rss-v1--category-1125.xml
Dainik Bhaskar  .sports        https://www.bhaskar.com/rss-v1--category-1053.xml
Dainik Bhaskar  .business      https://www.bhaskar.com/rss-v1--category-1051.xml
Dainik Bhaskar  .entertainment https://www.bhaskar.com/rss-v1--category-3998.xml
```

Each has `language: .hindi`. Home groups sources by `source` name, so one publisher's six section feeds appear as one channel. Say so in a comment by `NewsStore.sources`, and keep that deduplication: `sources` returns the first feed per source name (`var seen = Set<String>(); filter { present.contains($0.source) && seen.insert($0.source).inserted }`).

Save fixtures `livehindustan.xml`, `news18hindi.xml` and `bhaskar.xml` (first two items, as in Task 1 Step 6), and add them to `IndianPublisherSampleTests.samples` as `.india`.

- [ ] **Step 5: FeedLoader and NewsStore follow the language.** In `FeedLoader`, replace `var feeds: [RSSFeed] = RSSFeed.all` with:

```swift
    var language: ContentLanguage = .english
    /// Overridable for tests; defaults to the reader's language only, so a Hindi reader
    /// doesn't pay for eleven English feeds they will never see (and vice versa).
    var feeds: [RSSFeed]? = nil

    private var activeFeeds: [RSSFeed] { feeds ?? RSSFeed.feeds(for: language) }
```

Loop over `activeFeeds`. In `NewsStore`, make `loader` and `generator` `var`s and add:

```swift
    /// Swaps the news language and reloads. Cached summaries are dropped with the stories
    /// they belonged to; a queued rewrite of an English story must not land on a Hindi day.
    func setLanguage(_ language: ContentLanguage) async {
        guard loader.language != language || allStories.isEmpty else { return }
        loader.language = language
        generator.language = language
        worker?.cancel()
        worker = nil
        pending = []
        generatedSummaries = [:]
        allStories = []
        loadState = .idle
        await load()
    }
```

Add a test to `NewsStoreTests`: `setLanguage` with the same language twice leaves `adopt`ed stories untouched (it guards on no change when stories are present).

- [ ] **Step 6: Generator language.** In `QuestionGenerator`, add `var language: ContentLanguage = .english`. Turn `systemPrompt` into `static func systemPrompt(for language: ContentLanguage) -> String`, which returns the existing text plus this line for `.hindi`:

```
        - Write "summary", "question" and every answer in Hindi, in Devanagari script. Keep \
        people's names, numbers, dates and abbreviations (BJP, ISRO, IPL) as the story gives them. \
        The JSON keys stay in English.
```

Use `Self.systemPrompt(for: language)` in `request(for:)`. In `LiveNewsService`, set `generator.language = loader.language` before generating. In `RootView`, construct `LiveNewsService(loader: FeedLoader(language: language), generator: QuestionGenerator(language: language), prefetched:…, topics:…)`, giving `QuestionGenerator` an explicit `init(language: ContentLanguage = .english)` if needed.

- [ ] **Step 7: The onboarding page.** Add `case language` *before* `manifesto` in `OnboardingPage`, and update its doc comment ("six pages… the language comes first: a Hindi reader shouldn't have to get through two English pages to find the switch"). Create `LanguagePage.swift`:

```swift
import SwiftUI

/// The first question, before anything is sold: which language the news should come in.
/// Two tiles in the topics page's language — inverted white when chosen — each name
/// written in its own script.
struct LanguagePage: View {
    @Binding var language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Headline(text: Text("News in\n").foregroundStyle(.secondary) + Text("your language").foregroundStyle(.primary))
                    .onboardingEntry(0)
                Subhead(text: "आप बाद में प्रोफ़ाइल में बदल सकते हैं · You can change this later in Profile.")
                    .onboardingEntry(1)
            }

            VStack(spacing: 12) {
                ForEach(Array(ContentLanguage.allCases.enumerated()), id: \.element) { index, option in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) { language = option }
                    } label: {
                        ChoiceTile(title: option.nativeName, symbol: nil, tint: nil, isOn: language == option, height: 76)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.nativeName)
                    .accessibilityAddTraits(language == option ? [.isSelected, .isButton] : .isButton)
                    .onboardingEntry(2 + index)
                }
            }
            Spacer(minLength: 0)
        }
    }
}
```

`ChoiceTile` is the shared inverted-white tile, defined in Task 7 Step 3. **In this task**, add it to `OnboardingStyle.swift` with the Task 7 code already written (Task 7 then only swaps `TopicTile` over to it). In `OnboardingFlow`, add `@AppStorage(ContentLanguage.storageKey) private var languageRaw = ContentLanguage.preferred().rawValue` and a `Binding<ContentLanguage>`. Add `case .language: LanguagePage(language: languageBinding)` to the page switch, start `page` at `.language`, and add the button title `case .language: "Continue"`. Update the `-onboardingPage N` comment: numbering is now 1 = language.

- [ ] **Step 8: Profile and root.** In `ProfileView`, add a "News language" `ProfileSection` above Topics, holding a segmented `Picker` over `ContentLanguage.allCases` (labels `nativeName`), bound to the same `@AppStorage` key. The footnote reads "Changes today's stories. Your answers so far are kept." Below it, add a row button "App language" that calls `Nova.openAppSettings(using: openURL)`, with the footnote "The app's own words follow your iPhone. Set Hindi in Settings → NOVA → Language."

Add the helper to `NovaTheme.swift`:

```swift
extension Nova {
    /// Opens NOVA's page in Settings (per-app language, notifications). Wrapped because
    /// `UIApplication.openSettingsURLString` doesn't exist on macOS.
    static func openAppSettings(using openURL: OpenURLAction) {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        #endif
    }
}
```

In `RootView`, add `@AppStorage(ContentLanguage.storageKey) private var languageRaw = ContentLanguage.preferred().rawValue` and change the launch `.task` to `.task(id: languageRaw)`. Inside it, `await store.setLanguage(language)` replaces `await store.load()`, and the rest is unchanged. Changing the language in Profile then reloads Home and the deck. Also set `voice.language = language.voice` in the same task, if `VoiceAssistant` exposes a settable language. If it doesn't, pass it through `VoiceBriefingPanel`'s initial chip selection, which is whatever the panel already reads its default from.

In `StoryReaderView.failedState`, when the language is `.hindi`, add a secondary button "Read in English instead" that sets `languageRaw = ContentLanguage.english.rawValue`.

- [ ] **Step 9: Run** `$TEST`. Expected: all pass. Then build for macOS to prove the wrapping holds: `xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=macOS' build`.

- [ ] **Step 10: Commit**: "Read the news in Hindi: Hindi feeds, Hindi questions, and a language choice".

---

### Task 3: Hindi UI through a String Catalog

**Files:**
- Create: `NOVA/NOVA/Resources/Localizable.xcstrings`
- Modify: `NOVA/NOVA.xcodeproj/project.pbxproj` (`knownRegions`)
- Modify: views whose user-facing strings travel as `String` (see Step 2)
- Create: `NOVA/NOVATests/LocalizationTests.swift`
- Scratch: `scripts` in the scratchpad (not committed)

**Interfaces:**
- Produces: Hindi (`hi`) localisation for every user-facing literal. Components that took `String` for display copy now take `LocalizedStringKey` (`Subhead(text:)`, `ProfileSection(title:footnote:)`) or produce `String(localized:)`.

- [ ] **Step 1: Failing test** — `LocalizationTests.swift`:

```swift
import Foundation
import Testing
@testable import NOVA

@Suite("Hindi localisation")
struct LocalizationTests {
    private var hindi: Bundle? {
        Bundle.main.path(forResource: "hi", ofType: "lproj").flatMap(Bundle.init(path:))
    }

    @Test("The app ships a Hindi localisation")
    func bundleExists() { #expect(hindi != nil) }

    @Test("Key screens' words are translated", arguments: [
        "Home", "Profile", "Prep", "Headlines", "Channels", "Start reading", "Continue", "Share"
    ])
    func translated(key: String) throws {
        let bundle = try #require(hindi)
        #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅")
        #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != key)
    }
}
```

("Prep" becomes valid after Task 4. Leave it in, since this test runs green again at the end of Task 4.) **For this task only**, run it without that argument.

- [ ] **Step 2: Make display strings extractable.** Grep for view APIs that take display text as `String`: `grep -rn "let title: String\|let text: String\|footnote: String\|headline: String\|detail: String\|action: String" NOVA/NOVA/Features NOVA/NOVA/Components`. For each:
  - If it's a component parameter that receives literals (`Subhead.text`, `ProfileSection.title/footnote`, `Status` in `TodayRoundCard`), change the type to `LocalizedStringKey` (or build it with `String(localized: "…")` at the construction site, when the value is computed).
  - For computed `String`s shown with `Text(_:)` (`ResultsView.headline`, `badge`, `buttonTitle` in `OnboardingFlow`, share text, `TodayRoundCard.status`), wrap each literal in `String(localized: "…")`. Interpolations keep their form: `String(localized: "\(left) stories to go.")`.
  - `StoryCategory.title` returns `String(localized: "India")` and so on. It feeds chips, badges, tiles and the Prep rows, and a plain `String` literal there would never reach the catalog.
  - Leave alone: publisher names, `"NOVA"`, the debug section, and accessibility identifiers.
  - `accessibilityLabel("…")` literals are already `LocalizedStringKey`. The ones built from `String` get `String(localized:)`.

- [ ] **Step 3: Extract.** Build with string extraction on, then sync into a new catalog:

```bash
cd NOVA
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/nova-dd SWIFT_EMIT_LOC_STRINGS=YES build
echo '{"sourceLanguage":"en","strings":{},"version":"1.0"}' > NOVA/Resources/Localizable.xcstrings
find /tmp/nova-dd -name "*.stringsdata" -path "*NOVA.build*" -not -path "*Tests*" > /tmp/nova-stringsdata.txt
xcrun xcstringstool sync NOVA/Resources/Localizable.xcstrings --stringsdata $(cat /tmp/nova-stringsdata.txt | tr '\n' ' ')
python3 -c "import json;print(len(json.load(open('NOVA/Resources/Localizable.xcstrings'))['strings']))"
```

Expected: a key count in the low hundreds. Use the scratchpad path for `-derivedDataPath` in practice.

- [ ] **Step 4: Translate.** Write a scratch Python script holding a dict `{english_key: hindi}`, covering every key the catalog lists. Translate for meaning, not word for word, in the app's voice: short and direct, using familiar "आप" forms. Keep format specifiers (`%lld`, `%@`) in the same order, and keep English brand words ("NOVA") as they are. The script writes `localizations.hi.stringUnit = {state: "translated", value}` for each key. It then asserts that every key has a `hi` value and that the specifier multiset of each value matches its key. Run it, then rerun the count check: missing = 0.

- [ ] **Step 5: Register Hindi.** In `project.pbxproj`, change `knownRegions = (en, Base,);` to include `hi,`.

- [ ] **Step 6: Run** `$TEST -only-testing:NOVATests/LocalizationTests` (without "Prep"). Expected: PASS. Then run the full `$TEST`.

- [ ] **Step 7: Look at it.** Boot the simulator in Hindi (`xcrun simctl spawn booted defaults write -g AppleLanguages -array hi en`, then relaunch), and screenshot Home, Profile, the onboarding language page and Results (`-openRoute results -previewDeck YES -simulateRound 3`). Check that Devanagari falls back cleanly in the serif and compressed faces. The system substitutes a Devanagari face per glyph, and for all-Hindi strings that is consistent. Change fonts only if a screenshot shows mixed or clipped glyphs; if one does, add `Nova.poster` and `Nova.reading` fallbacks to `.default` design when `Locale.current.language.languageCode == .hindi`. Reset afterwards with `defaults delete -g AppleLanguages`.

- [ ] **Step 8: Commit**: "Translate the app into Hindi with a String Catalog".

---

### Task 4: Exam prep — explanations, the answer archive, the Prep tab

**Files:**
- Modify: `Models/Question.swift`, `Services/QuestionGenerator.swift`, `GameLogic/DailySession.swift`, `App/RootView.swift`, `App/AppRouter.swift`, `Features/Results/ResultsView.swift`
- Create: `GameLogic/QuestionArchive.swift`, `GameLogic/RevisionPicker.swift`, `Features/Prep/PrepView.swift`, `Features/Prep/RevisionView.swift`
- Test: `NOVATests/QuestionArchiveTests.swift`, `NOVATests/RevisionPickerTests.swift`, `NOVATests/DailySessionTests.swift`, `NOVATests/QuestionGeneratorTests.swift`

**Interfaces:**
- Consumes: `ContentLanguage`, `QuestionGenerator.systemPrompt(for:)`.
- Produces:
  - `Question.explanation: String?`
  - `struct ArchivedAnswer: Codable, Identifiable, Hashable, Sendable` with `id: QuestionID`, `question: Question`, `storyTitle: String`, `source: String`, `category: StoryCategory`, `day: String`, `answeredAt: Date`, `firstAttemptCorrect: Bool`, `lastCorrect: Bool`, `revisionCount: Int`, `lastRevisedAt: Date?`
  - `@Observable final class QuestionArchive` with `init(fileURL: URL = QuestionArchive.defaultURL, calendar: Calendar = .current)`, `entries: [ArchivedAnswer]` (newest first), `record(_ question: Question, story: Story, correct: Bool, at: Date = .now)`, `recordRevision(_ id: QuestionID, correct: Bool, at: Date = .now)`, `accuracy: Double?`, `accuracyByCategory: [(category: StoryCategory, correct: Int, total: Int)]`, `week(endingOn: Date = .now) -> [(day: Date, entries: [ArchivedAnswer])]`, `revisionSheet(endingOn: Date = .now) -> String`
  - `enum RevisionPicker { static let size = 10; static func pick(from: [ArchivedAnswer], limit: Int = size) -> [ArchivedAnswer] }`
  - `DailySession.init(…, archive: QuestionArchive? = nil)`
  - `AppTab.prep`

- [ ] **Step 1: Failing archive tests** — `QuestionArchiveTests.swift`:

```swift
import Foundation
import Testing
@testable import NOVA

@Suite("Question archive")
struct QuestionArchiveTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString)")
            .appendingPathComponent("question-archive.json")
    }

    private func question(_ id: String, category: StoryCategory = .india) -> (Question, Story) {
        let story = Story(id: StoryID("s-\(id)"), title: "Title \(id)", summary: "", source: "Src",
                          category: category, publishedAt: Date(timeIntervalSince1970: 1_800_000_000), artwork: .none)
        let q = Question(id: QuestionID(id), storyID: story.id, prompt: "Prompt \(id)?",
                         answers: ["A", "B", "C", "D"], correctAnswerIndex: 1, explanation: "Why \(id).")
        return (q, story)
    }

    @Test("Answers survive a relaunch")
    func persists() {
        let url = tempURL()
        let (q, s) = question("q1")
        QuestionArchive(fileURL: url).record(q, story: s, correct: true)

        let reopened = QuestionArchive(fileURL: url)
        #expect(reopened.entries.count == 1)
        #expect(reopened.entries[0].question.explanation == "Why q1.")
        #expect(reopened.entries[0].firstAttemptCorrect)
    }

    @Test("A question asked again keeps its first result")
    func duplicateAnswerKeepsFirst() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")
        archive.record(q, story: s, correct: false)
        archive.record(q, story: s, correct: true)

        #expect(archive.entries.count == 1)
        #expect(archive.entries[0].firstAttemptCorrect == false)
    }

    @Test("Revision updates the latest result but never the first")
    func revisionUpdates() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")
        archive.record(q, story: s, correct: false)
        archive.recordRevision(q.id, correct: true, at: Date(timeIntervalSince1970: 1_800_100_000))

        #expect(archive.entries[0].firstAttemptCorrect == false)
        #expect(archive.entries[0].lastCorrect)
        #expect(archive.entries[0].revisionCount == 1)
        #expect(archive.entries[0].lastRevisedAt != nil)
    }

    @Test("A corrupt file is set aside, not overwritten, and the archive starts empty")
    func corruptFileIsSetAside() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)

        let archive = QuestionArchive(fileURL: url)

        #expect(archive.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
    }

    @Test("The archive keeps only the newest thousand")
    func capped() {
        let archive = QuestionArchive(fileURL: tempURL())
        for index in 0..<(QuestionArchive.capacity + 5) {
            let (q, s) = question("q\(index)")
            archive.record(q, story: s, correct: true, at: Date(timeIntervalSince1970: Double(1_800_000_000 + index)))
        }
        #expect(archive.entries.count == QuestionArchive.capacity)
        #expect(archive.entries.first?.id == QuestionID("q\(QuestionArchive.capacity + 4)"))
    }

    @Test("Accuracy is by first attempt, per category, and nil before any answer")
    func accuracy() {
        let archive = QuestionArchive(fileURL: tempURL())
        #expect(archive.accuracy == nil)
        let (a, sa) = question("a", category: .india)
        let (b, sb) = question("b", category: .india)
        let (c, sc) = question("c", category: .sports)
        archive.record(a, story: sa, correct: true)
        archive.record(b, story: sb, correct: false)
        archive.record(c, story: sc, correct: true)

        #expect(archive.accuracy == 2.0 / 3.0)
        let india = archive.accuracyByCategory.first { $0.category == .india }
        #expect(india?.correct == 1 && india?.total == 2)
    }

    @Test("The revision sheet lists each question with its answer and context")
    func sheet() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        archive.record(q, story: s, correct: true, at: now)

        let text = archive.revisionSheet(endingOn: now)
        #expect(text.contains("Prompt q1?"))
        #expect(text.contains("B"))
        #expect(text.contains("Why q1."))
    }
}
```

- [ ] **Step 2: Failing picker tests** — `RevisionPickerTests.swift`:

```swift
import Foundation
import Testing
@testable import NOVA

@Suite("Revision picker")
struct RevisionPickerTests {
    private func entry(_ id: String, lastCorrect: Bool, revised: Double?, answered: Double = 0) -> ArchivedAnswer {
        ArchivedAnswer(
            id: QuestionID(id),
            question: Question(id: QuestionID(id), storyID: StoryID(id), prompt: id, answers: ["a", "b"], correctAnswerIndex: 0),
            storyTitle: id, source: "S", category: .india, day: "2026-09-28",
            answeredAt: Date(timeIntervalSince1970: answered), firstAttemptCorrect: lastCorrect,
            lastCorrect: lastCorrect, revisionCount: revised == nil ? 0 : 1,
            lastRevisedAt: revised.map(Date.init(timeIntervalSince1970:))
        )
    }

    @Test("Wrong answers come first, then the least recently revised")
    func order() {
        let picked = RevisionPicker.pick(from: [
            entry("right-old", lastCorrect: true, revised: 10),
            entry("wrong", lastCorrect: false, revised: 500),
            entry("right-never", lastCorrect: true, revised: nil, answered: 5)
        ])
        #expect(picked.map(\.id.rawValue) == ["wrong", "right-never", "right-old"])
    }

    @Test("Never more than the limit, and an empty archive gives an empty round")
    func limits() {
        let many = (0..<25).map { entry("e\($0)", lastCorrect: true, revised: Double($0)) }
        #expect(RevisionPicker.pick(from: many).count == RevisionPicker.size)
        #expect(RevisionPicker.pick(from: []).isEmpty)
        #expect(RevisionPicker.pick(from: Array(many.prefix(3))).count == 3)
    }
}
```

- [ ] **Step 3: Failing session and generator tests.** In `DailySessionTests`, add:

```swift
    @Test("Answering records into the archive; a reload keeps what was recorded")
    func reloadKeepsArchive() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("a-\(UUID()).json")
        let archive = QuestionArchive(fileURL: url)
        let session = DailySession(archive: archive)
        let question = try! #require(session.engine.currentQuestion)
        session.submitAnswer(at: question.correctAnswerIndex)
        #expect(archive.entries.count == 1)

        await session.load(from: PreviewNewsService())
        #expect(archive.entries.count == 1)
    }
```

(If the file's other tests use a different `#require` style, match it.) In `QuestionGeneratorTests`, add: "The prompt asks for exam-style facts and a context line" → `QuestionGenerator.systemPrompt(for: .english).contains("\"context\"")`.

- [ ] **Step 4: Run** the four suites. Expected: compile failures.

- [ ] **Step 5: `Question.explanation`.** Add after `correctAnswerIndex`:

```swift
    /// One sentence of why the story matters, written with the question. Optional because
    /// the hand-written demo deck and older archived answers have none. Machine-written and
    /// unchecked like the question itself.
    var explanation: String? = nil
```

- [ ] **Step 6: Generator.** Change the shape line in the prompt to `{"summary": string, "question": string, "answers": [string], "correctIndex": int, "context": string}`, and add these rules:

```
        - Prefer a factual question of the kind a competitive exam asks: who, which body or \
        scheme, where, when, how much. Avoid opinion and prediction.
        - "context" is one sentence on why the story matters, using only facts in the story.
```

In `Generated`, add `let context: String?`, and set `explanation: context?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty` in `question(for:)`. Add a small `extension String { var nilIfEmpty: String? { isEmpty ? nil : self } }` as a `private` helper in the same file.

- [ ] **Step 7: Create `QuestionArchive.swift`.**

```swift
import Foundation
import Observation

/// One answered question, kept for revision.
struct ArchivedAnswer: Codable, Identifiable, Hashable, Sendable {
    let id: QuestionID
    let question: Question
    let storyTitle: String
    let source: String
    let category: StoryCategory
    /// The reader's calendar day, "2026-09-28" — the same key `PlayHistory` uses.
    let day: String
    let answeredAt: Date
    /// The daily round's result. Accuracy is measured on this, so revising can't
    /// retroactively improve a score the reader didn't earn on the day.
    let firstAttemptCorrect: Bool
    var lastCorrect: Bool
    var revisionCount: Int
    var lastRevisedAt: Date?
}

/// Every question the reader has answered, newest first, saved as JSON on the device.
///
/// No account and no sync on purpose: the branch that added it had to stay free, and a
/// file in Application Support is the one store that costs nothing and needs no consent.
@Observable
final class QuestionArchive {
    static let capacity = 1000

    static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("NOVA", isDirectory: true)
            .appendingPathComponent("question-archive.json")
    }

    private(set) var entries: [ArchivedAnswer] = []

    private let fileURL: URL
    private let calendar: Calendar

    init(fileURL: URL = QuestionArchive.defaultURL, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
        load()
    }

    // MARK: - Recording

    /// Keeps the first attempt only. The round isn't persisted, so after a relaunch the
    /// same questions come back — re-answering one must not overwrite how it went the
    /// first time.
    func record(_ question: Question, story: Story, correct: Bool, at date: Date = .now) {
        guard !entries.contains(where: { $0.id == question.id }) else { return }
        entries.insert(
            ArchivedAnswer(
                id: question.id, question: question, storyTitle: story.title, source: story.source,
                category: story.category, day: dayKey(for: date), answeredAt: date,
                firstAttemptCorrect: correct, lastCorrect: correct, revisionCount: 0, lastRevisedAt: nil
            ),
            at: 0
        )
        if entries.count > Self.capacity { entries.removeLast(entries.count - Self.capacity) }
        save()
    }

    func recordRevision(_ id: QuestionID, correct: Bool, at date: Date = .now) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].lastCorrect = correct
        entries[index].revisionCount += 1
        entries[index].lastRevisedAt = date
        save()
    }

    // MARK: - Reading

    /// Share of first attempts that were right; nil before anything is answered, so the
    /// Prep header shows a dash instead of a discouraging 0 %.
    var accuracy: Double? {
        guard !entries.isEmpty else { return nil }
        return Double(entries.filter(\.firstAttemptCorrect).count) / Double(entries.count)
    }

    var accuracyByCategory: [(category: StoryCategory, correct: Int, total: Int)] {
        StoryCategory.allCases.compactMap { category in
            let inCategory = entries.filter { $0.category == category }
            guard !inCategory.isEmpty else { return nil }
            return (category, inCategory.filter(\.firstAttemptCorrect).count, inCategory.count)
        }
    }

    /// The seven days ending today that have answers, newest first.
    func week(endingOn today: Date = .now) -> [(day: Date, entries: [ArchivedAnswer])] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: start) else { return nil }
            let key = dayKey(for: date)
            let answers = entries.filter { $0.day == key }
            return answers.isEmpty ? nil : (date, answers)
        }
    }

    /// The week as plain text, the way aspirants pass notes around: question, answer,
    /// context. Labelled as machine-written, because it will travel without the app.
    func revisionSheet(endingOn today: Date = .now) -> String {
        var lines = [String(localized: "NOVA · this week's questions")]
        for (date, answers) in week(endingOn: today) {
            lines.append("")
            lines.append(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            for answer in answers {
                lines.append("• \(answer.question.prompt)")
                lines.append("  → \(answer.question.correctAnswer)")
                if let why = answer.question.explanation { lines.append("  \(why)") }
            }
        }
        lines.append("")
        lines.append(String(localized: "Machine-written from news feeds and not checked."))
        return lines.joined(separator: "\n")
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            entries = try JSONDecoder().decode([ArchivedAnswer].self, from: data)
        } catch {
            // Set the bad file aside rather than overwrite it on the next save: losing a
            // reader's revision history silently is worse than losing it loudly.
            let aside = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            entries = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            // Best effort, like SoundPlayer: a failed save costs revision history, never the round.
        }
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
```

- [ ] **Step 8: Create `RevisionPicker.swift`.**

```swift
import Foundation

/// Which archived questions a revision round asks, in order.
///
/// Wrong answers first — that's what revision is for — then whatever has gone longest
/// without being looked at. Ties break by id so the same archive always gives the same
/// round, which keeps the tests (and the reader's sense of the order) stable.
enum RevisionPicker {
    static let size = 10

    static func pick(from entries: [ArchivedAnswer], limit: Int = size) -> [ArchivedAnswer] {
        Array(
            entries.sorted { a, b in
                if a.lastCorrect != b.lastCorrect { return !a.lastCorrect }
                let aSeen = a.lastRevisedAt ?? a.answeredAt
                let bSeen = b.lastRevisedAt ?? b.answeredAt
                if aSeen != bSeen { return aSeen < bSeen }
                return a.id.rawValue < b.id.rawValue
            }
            .prefix(limit)
        )
    }
}
```

- [ ] **Step 9: Record from the session.** In `DailySession`, add `private let archive: QuestionArchive?` and an `archive: QuestionArchive? = nil` init parameter. Replace `submitAnswer`:

```swift
    @discardableResult
    func submitAnswer(at answerIndex: Int) -> AnswerSubmission? {
        guard let submission = engine.submitAnswer(at: answerIndex) else { return nil }
        // Recorded here, not in the view, so "views never compute scores" still holds and
        // every way of answering (the shot, the VoiceOver path) is archived the same.
        if let question = question(withID: submission.questionID), let story = story(for: question) {
            archive?.record(question, story: story, correct: submission.isCorrect)
        }
        return submission
    }
```

In `RootView`, create the archive first:

```swift
    @State private var archive: QuestionArchive
    @State private var session: DailySession

    init() {
        let archive = QuestionArchive()
        _archive = State(initialValue: archive)
        _session = State(initialValue: DailySession(archive: archive))
    }
```

Keep the other `@State` stores as they are. Add `.environment(archive)` alongside the others.

- [ ] **Step 10: Run** the archive, picker, session and generator suites. Expected: PASS.

- [ ] **Step 11: The Prep tab.** In `AppRouter`, add `case prep` to `AppTab`, and `case "prep": return .prep` to `initialTab`. In `RootView`, add between Scroll and Profile:

```swift
                Tab("Prep", systemImage: "graduationcap", value: AppTab.prep) {
                    NavigationStack { PrepView() }
                }
```

Create `Features/Prep/PrepView.swift`. It sits on paper (`novaPaperSurface()`), titled "Prep" (`novaInlineTitle()`), in a `ScrollView` → `VStack(alignment: .leading, spacing: 30)`, padded like Profile. Its sections are:
1. **Header:** the display headline "Revise what you read." Beneath it, three `StatTile`-style tiles: "Questions kept" (`archive.entries.count`), "Accuracy" (`archive.accuracy` as a percentage, or "–"), and "Due" (the count of `!lastCorrect`). Profile's `StatTile` is `private`, so promote it into `Components/StatTile.swift` (moved, unchanged) and use it from both.
2. **By category:** one row per `archive.accuracyByCategory`. Each row has a 9pt tint square, the category title in ink, mono `correct/total`, and a thin ink bar of the share on a hairline track (ink, never the tint as text).
3. **Revise:** `Button("Revise \(min(RevisionPicker.size, archive.entries.count)) questions")` with `PaperButtonStyle()`. It sets `showsRevision = true`, is disabled when the archive is empty, and presents `.sheet(isPresented:) { RevisionView() }`.
4. **This week:** a section titled "This week". For each day in `archive.week()`, show a mono date label, then rows of prompt (headline), "→ correct answer" (reading serif) and the explanation (secondary), separated by hairlines. Put `ShareLink(item: archive.revisionSheet()) { Label("Share this week", systemImage: "square.and.arrow.up") }` at the end.
5. **Empty state** (the archive is empty): replaces 2–4 with one line of body text, "Every question you answer lands here, ready to revise.", and `Button("Go to today's stories") { router.tab = .scroll }`.
6. **Footnote**, always shown: "Questions are machine-written from news feeds and not checked. Verify before relying on them for an exam."

Create `Features/Prep/RevisionView.swift`: a `NavigationStack` on paper, with a "Done" toolbar button that dismisses. It holds `@State private var engine: RoundEngine?` and `@State private var picked: [ArchivedAnswer] = []`, built once on appear:

```swift
        picked = RevisionPicker.pick(from: archive.entries)
        let questions = picked.map(\.question)
        engine = RoundEngine(
            round: GameRound(id: RoundID("revision"), storyIDs: questions.map(\.storyID), questionIDs: questions.map(\.id)),
            questions: questions
        )
```

For the current question it shows a mono "3 / 10" and the prompt (display), then one full-width button per answer ("A  answer text", with the letter in a mono square, since colour is never the only cue), each 56pt tall on a sheet with a hairline. Tapping calls `engine?.submitAnswer(at:)` and `archive.recordRevision(id, correct:)`. While `pendingResult` is set, the chosen and correct buttons show `feedback-right`/`feedback-wrong` borders with a symbol and a label ("Right" / "The answer"). Below them appear the explanation, the source line (`picked[i].source` · `storyTitle`) and `Button("Next") { engine?.advance() }` (PaperButtonStyle). A finished engine shows "`correct` of `count` right" and "Done". There's no slingshot here: revision is study, on paper.

- [ ] **Step 12: Explanation on results.** In `ResultsView.reviewRow`, under the "Sunk" / "Answer:" line, add `if let why = question?.explanation { Text(why).font(.caption).opacity(0.7).fixedSize(horizontal: false, vertical: true) }`.

- [ ] **Step 13: Previews and suite.** Give `PrepView` a `#Preview` with an archive seeded from `MockNewsService.todayQuestions` (write to a temp URL), and `RevisionView` one too. Run `$TEST`, including `LocalizationTests`, where "Prep" must now be in the catalog. Rerun the Task 3 Step 3–4 extraction and translation for the new strings, so every new key has a `hi` value.

- [ ] **Step 14: Commit**: "Add exam prep: keep every answer, explain it, and revise in a Prep tab".

---

### Task 5: Sharing — text grid, scorecard image, question card

**Files:**
- Create: `GameLogic/ShareGrid.swift`, `Features/Share/ShareCards.swift`
- Modify: `GameLogic/DailySession.swift` (`storyOutcomes`), `Features/Results/ResultsView.swift`, `Features/Prep/RevisionView.swift`
- Test: `NOVATests/ShareGridTests.swift`

**Interfaces:**
- Consumes: `PlayHistory.streak()`, `DailySession.mosaic`, `Question`.
- Produces: `enum ShareGrid { static func text(outcomes: [Bool], date: Date, streak: Int, locale: Locale = .current) -> String }`. `DailySession.storyOutcomes: [Bool]` (answered questions, in story order). `ShareRenderer.image(of: some View, size: CGSize) -> Image?`. `struct ScorecardCard: View`, `struct QuestionShareCard: View`.

- [ ] **Step 1: Failing test** — `ShareGridTests.swift`:

```swift
import Foundation
import Testing
@testable import NOVA

@Suite("Share grid")
struct ShareGridTests {
    private let date = Date(timeIntervalSince1970: 1_790_553_600) // 28 Sep 2026
    private let locale = Locale(identifier: "en_GB")

    @Test("One square per question, filled for correct, with the score and streak")
    func grid() {
        let text = ShareGrid.text(outcomes: [true, true, false, true, true], date: date, streak: 6, locale: locale)
        let lines = text.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("NOVA · "))
        #expect(lines[1] == "🟨🟨⬜🟨🟨 4/5")
        #expect(lines[2].contains("6"))
    }

    @Test("No streak line on a first day; nothing invented")
    func noStreak() {
        let text = ShareGrid.text(outcomes: [false, true], date: date, streak: 0, locale: locale)
        #expect(text.components(separatedBy: "\n").count == 2)
        #expect(!text.contains("%"))
    }
}
```

- [ ] **Step 2: Run** `$TEST -only-testing:NOVATests/ShareGridTests`. Expected: compile failure.

- [ ] **Step 3: `ShareGrid.swift`**

```swift
import Foundation

/// The round as text a chat app can carry without an image: one square per question.
///
/// Marigold squares because marigold is what a sunk shot earns in the app; white for a
/// miss. It says only what happened — no rank, no percentile — because there is no
/// leaderboard to back one up.
enum ShareGrid {
    static func text(outcomes: [Bool], date: Date, streak: Int, locale: Locale = .current) -> String {
        let day = date.formatted(Date.FormatStyle(locale: locale).day().month(.abbreviated))
        let squares = outcomes.map { $0 ? "🟨" : "⬜" }.joined()
        var lines = ["NOVA · \(day)", "\(squares) \(outcomes.filter { $0 }.count)/\(outcomes.count)"]
        if streak > 0 {
            lines.append(String(localized: "🔥 \(streak)-day streak"))
        }
        return lines.joined(separator: "\n")
    }
}
```

In `DailySession`:

```swift
    /// Each answered question's result, in the order its story sits in the deck — the
    /// order the share grid draws them.
    var storyOutcomes: [Bool] {
        let byStory = Dictionary(engine.submissions.compactMap { submission in
            question(withID: submission.questionID).map { ($0.storyID, submission.isCorrect) }
        }, uniquingKeysWith: { first, _ in first })
        return stories.compactMap { byStory[$0.id] }
    }
```

- [ ] **Step 4: Run** the ShareGrid suite. Expected: PASS.

- [ ] **Step 5: `ShareCards.swift`**

```swift
import SwiftUI

/// Renders a view to a shareable image at a fixed size, independent of the screen it was
/// shared from. Nil when rendering fails; callers then share text alone.
enum ShareRenderer {
    static func image(of view: some View, size: CGSize, scale: CGFloat = 3) -> Image? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: scale)
    }

    /// 360 × 450 pt at 3× is 1080 × 1350 px — the 4:5 portrait chat apps show uncropped.
    static let cardSize = CGSize(width: 360, height: 450)
}

/// The round, as a picture: the mosaic, the score, the date and the streak.
/// Marigold only when the round earned the flood, same as the results screen.
struct ScorecardCard: View {
    let mosaic: DailyMosaic
    let tints: [Color]
    let correct: Int
    let total: Int
    let streak: Int
    let date: Date

    private var earned: Bool { correct > 0 }
    private var ink: Color { earned ? Nova.marigoldInk : .white }

    var body: some View {
        VStack(spacing: 22) {
            HStack {
                Text("NOVA").font(Nova.poster(.title2))
                AsteriskMark().fill(ink).frame(width: 12, height: 12)
                Spacer()
                Text(date, format: .dateTime.day().month(.abbreviated)).font(Nova.meta(.caption, weight: .semibold))
            }
            Spacer(minLength: 0)
            MosaicView(mosaic: mosaic, tints: tints, cell: 22, gap: 4)
            Text("\(correct) / \(total)").font(.system(size: 88, weight: .heavy).width(.compressed))
            if streak > 0 {
                Text("\(streak)-day streak").font(Nova.meta(.subheadline, weight: .bold)).textCase(.uppercase)
            }
            Spacer(minLength: 0)
            Text("Five stories. Five shots.").font(Nova.meta(.caption2)).textCase(.uppercase).opacity(0.7)
        }
        .foregroundStyle(ink)
        .padding(28)
        .background(earned ? Nova.marigold : Nova.charcoal)
        .environment(\.colorScheme, earned ? .light : .dark)
    }
}

/// One question as a dare: prompt, lettered options, source — and no answer.
struct QuestionShareCard: View {
    let question: Question
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("NOVA").font(Nova.poster(.title3))
                Spacer()
                Text("Can you answer this?").font(Nova.meta(.caption2, weight: .bold)).textCase(.uppercase)
            }
            Text(question.prompt).font(Nova.display(.title2)).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(question.answers.enumerated()), id: \.offset) { index, answer in
                HStack(alignment: .top, spacing: 12) {
                    Text(String(UnicodeScalar(65 + index).map(Character.init) ?? "?"))
                        .font(Nova.meta(.subheadline, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Nova.charcoalRaised, in: .rect(cornerRadius: 4))
                    Text(answer).font(.subheadline.weight(.semibold))
                }
            }
            Spacer(minLength: 0)
            Text(source).font(.footnote.weight(.semibold)).opacity(0.8)
            Text("Answer in NOVA · machine-written question").font(Nova.meta(.caption2)).opacity(0.6)
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(Nova.charcoal)
        .environment(\.colorScheme, .dark)
    }
}
```

Add a render smoke test to `ShareGridTests`:

```swift
    @MainActor
    @Test("The question card renders to an image")
    func renders() {
        let question = MockNewsService.todayQuestions[0]
        let image = ShareRenderer.image(of: QuestionShareCard(question: question, source: "Test"), size: ShareRenderer.cardSize)
        #expect(image != nil)
    }
```

- [ ] **Step 6: Wire into Results.** Replace `shareText` with `ShareGrid.text(outcomes: session.storyOutcomes, date: .now, streak: history.streak())`. Replace the `ShareLink(item: shareText)` with:

```swift
            if let card = ShareRenderer.image(
                of: ScorecardCard(mosaic: session.mosaic, tints: session.stories.map(\.category.tint),
                                  correct: engine.correctAnswers, total: engine.questionCount,
                                  streak: history.streak(), date: .now),
                size: ShareRenderer.cardSize
            ) {
                ShareLink(item: card, message: Text(shareText), preview: SharePreview("NOVA", image: card)) { Text("Share") }
                    .buttonStyle(ResultsOutlineStyle(ink: ink))
            } else {
                ShareLink(item: shareText) { Text("Share") }
                    .buttonStyle(ResultsOutlineStyle(ink: ink))
            }
```

The card is computed in a `private var scorecard: Image?`, so it isn't re-rendered on every body evaluation more than SwiftUI already does. Mark that with a comment. In `reviewRow`, add a trailing `ShareLink` with the icon `square.and.arrow.up` (a 44×44 frame, `accessibilityLabel("Share this question")`). It shares the `QuestionShareCard` image, with the message "Can you answer this? — NOVA". Add the same button to the revision answer screen in `RevisionView`.

- [ ] **Step 7: Run** `$TEST`. Extract and translate the new strings (Task 3 Steps 3–4). Check with a simulator screenshot of Results (`-openRoute results -previewDeck YES -simulateRound 4`).

- [ ] **Step 8: Commit**: "Share the round as a scorecard and a square grid, and questions as dares".

---

### Task 6: Daily reminder

**Files:**
- Create: `Services/ReminderScheduler.swift`
- Modify: `App/RootView.swift`, `Features/Profile/ProfileView.swift`, `Features/Results/ResultsView.swift`
- Test: `NOVATests/ReminderSchedulerTests.swift`

**Interfaces:**
- Consumes: `ContentLanguage`, `PlayHistory.hasPlayed(on:)`.
- Produces:
  - `enum ReminderPlan { static func schedule(now: Date, hour: Int, minute: Int, todayDone: Bool, days: Int = 7, calendar: Calendar = .current) -> [(id: String, fireDate: Date)] }`
  - `protocol NotificationCentre: Sendable { func requestAuthorization() async -> Bool; func pendingIdentifiers() async -> [String]; func add(id: String, fireDate: Date, title: String, body: String) async; func remove(ids: [String]) }`
  - `@Observable final class ReminderScheduler` with `init(centre: NotificationCentre = SystemNotificationCentre(), defaults: UserDefaults = .standard, calendar: Calendar = .current)`, `isEnabled: Bool`, `hour: Int`, `minute: Int`, `wasDenied: Bool`, `enable() async`, `disable() async`, `setTime(hour:minute:) async`, `refresh(todayDone: Bool, language: ContentLanguage) async`, `markTodayDone() async`

- [ ] **Step 1: Failing tests** — `ReminderSchedulerTests.swift`:

```swift
import Foundation
import Testing
@testable import NOVA

@Suite("Reminder plan")
struct ReminderPlanTests {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "Asia/Kolkata")!; return c
    }
    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 9, day: 28, hour: hour, minute: minute))!
    }

    @Test("Seven reminders, starting today when the time is still ahead")
    func startsToday() {
        let plan = ReminderPlan.schedule(now: at(7), hour: 8, minute: 0, todayDone: false, calendar: calendar)
        #expect(plan.count == 7)
        #expect(plan.first?.id == "reminder-2026-09-28")
    }

    @Test("A time already past today starts tomorrow")
    func pastTimeStartsTomorrow() {
        let plan = ReminderPlan.schedule(now: at(9), hour: 8, minute: 0, todayDone: false, calendar: calendar)
        #expect(plan.first?.id == "reminder-2026-09-29")
        #expect(plan.count == 7)
    }

    @Test("Today is skipped once the round is done")
    func skipsDoneToday() {
        let plan = ReminderPlan.schedule(now: at(7), hour: 8, minute: 0, todayDone: true, calendar: calendar)
        #expect(plan.first?.id == "reminder-2026-09-29")
    }
}

@Suite("Reminder scheduler")
@MainActor
struct ReminderSchedulerTests {
    final class FakeCentre: NotificationCentre, @unchecked Sendable {
        var granted = true
        var pending: [String: Date] = [:]
        func requestAuthorization() async -> Bool { granted }
        func pendingIdentifiers() async -> [String] { Array(pending.keys) }
        func add(id: String, fireDate: Date, title: String, body: String) async { pending[id] = fireDate }
        func remove(ids: [String]) { ids.forEach { pending[$0] = nil } }
    }

    private func defaults() -> UserDefaults {
        let name = "reminder-\(UUID())"; let d = UserDefaults(suiteName: name)!; d.removePersistentDomain(forName: name); return d
    }

    @Test("Enabling asks permission and schedules the week; denial turns it back off")
    func enable() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.enable()
        #expect(scheduler.isEnabled)
        #expect(centre.pending.count == 7)

        let denied = FakeCentre(); denied.granted = false
        let refused = ReminderScheduler(centre: denied, defaults: defaults())
        await refused.enable()
        #expect(refused.isEnabled == false)
        #expect(refused.wasDenied)
        #expect(denied.pending.isEmpty)
    }

    @Test("Finishing the round removes today's reminder only")
    func markTodayDoneRemovesToday() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.setTime(hour: 23, minute: 59)
        await scheduler.enable()
        let today = ReminderPlan.identifier(for: .now, calendar: .current)
        #expect(centre.pending[today] != nil)

        await scheduler.markTodayDone()
        #expect(centre.pending[today] == nil)
        #expect(centre.pending.count == 6)
    }

    @Test("Disabling clears everything it scheduled")
    func disable() async {
        let centre = FakeCentre()
        let scheduler = ReminderScheduler(centre: centre, defaults: defaults())
        await scheduler.enable()
        await scheduler.disable()
        #expect(centre.pending.isEmpty)
    }
}
```

(`markTodayDoneRemovesToday` sets 23:59 so that "today" is still ahead whenever the test runs. If it runs in the minute before midnight it is flaky. Accept that, and say so in a comment.)

- [ ] **Step 2: Run** `$TEST -only-testing:NOVATests/ReminderPlanTests -only-testing:NOVATests/ReminderSchedulerTests`. Expected: compile failure.

- [ ] **Step 3: `ReminderScheduler.swift`**

```swift
import Foundation
import Observation
import UserNotifications

/// Which days get a reminder. Pure, so the rules are tested without a notification centre.
///
/// One non-repeating reminder per day for a week, rather than one repeating trigger: a
/// repeating trigger can't skip a single day, and the reminder must not arrive on a day
/// the round is already done — a nudge for work already finished is noise.
enum ReminderPlan {
    static func identifier(for date: Date, calendar: Calendar) -> String {
        let p = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "reminder-%04d-%02d-%02d", p.year ?? 0, p.month ?? 0, p.day ?? 0)
    }

    static func schedule(
        now: Date, hour: Int, minute: Int, todayDone: Bool, days: Int = 7, calendar: Calendar = .current
    ) -> [(id: String, fireDate: Date)] {
        let today = calendar.startOfDay(for: now)
        var plan: [(id: String, fireDate: Date)] = []
        var offset = 0
        while plan.count < days, offset < days + 2 {
            defer { offset += 1 }
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                fire > now,
                !(offset == 0 && todayDone)
            else { continue }
            plan.append((identifier(for: day, calendar: calendar), fire))
        }
        return plan
    }
}

/// The slice of `UNUserNotificationCenter` the scheduler uses, so tests can fake it.
protocol NotificationCentre: Sendable {
    func requestAuthorization() async -> Bool
    func pendingIdentifiers() async -> [String]
    func add(id: String, fireDate: Date, title: String, body: String) async
    func remove(ids: [String])
}

struct SystemNotificationCentre: NotificationCentre {
    private var centre: UNUserNotificationCenter { .current() }

    func requestAuthorization() async -> Bool {
        (try? await centre.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func pendingIdentifiers() async -> [String] {
        await centre.pendingNotificationRequests().map(\.identifier)
    }

    func add(id: String, fireDate: Date, title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let request = UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        )
        try? await centre.add(request)
    }

    func remove(ids: [String]) {
        centre.removePendingNotificationRequests(withIdentifiers: ids)
    }
}

/// The daily reminder: off by default, one a day at the reader's time, never on a day
/// already played. Local notifications only — no server, no push certificate, nothing
/// that costs anything to run.
@Observable
final class ReminderScheduler {
    private enum Key {
        static let enabled = "reminderEnabled", hour = "reminderHour", minute = "reminderMinute"
    }

    private(set) var isEnabled: Bool
    private(set) var hour: Int
    private(set) var minute: Int
    /// Set when the reader said no in the system prompt, so Profile can explain why the
    /// switch won't stay on and point to Settings.
    private(set) var wasDenied = false

    private let centre: NotificationCentre
    private let defaults: UserDefaults
    private let calendar: Calendar
    private var language: ContentLanguage = .english
    private var todayDone = false

    init(centre: NotificationCentre = SystemNotificationCentre(), defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.centre = centre
        self.defaults = defaults
        self.calendar = calendar
        isEnabled = defaults.bool(forKey: Key.enabled)
        hour = defaults.object(forKey: Key.hour) as? Int ?? 8
        minute = defaults.object(forKey: Key.minute) as? Int ?? 0
    }

    func enable() async {
        guard await centre.requestAuthorization() else {
            wasDenied = true
            setEnabled(false)
            return
        }
        wasDenied = false
        setEnabled(true)
        await reschedule()
    }

    func disable() async {
        setEnabled(false)
        await clear()
    }

    func setTime(hour: Int, minute: Int) async {
        self.hour = hour
        self.minute = minute
        defaults.set(hour, forKey: Key.hour)
        defaults.set(minute, forKey: Key.minute)
        if isEnabled { await reschedule() }
    }

    /// On launch and whenever the language changes: tops the week back up.
    func refresh(todayDone: Bool, language: ContentLanguage) async {
        self.todayDone = todayDone
        self.language = language
        if isEnabled { await reschedule() }
    }

    func markTodayDone() async {
        todayDone = true
        centre.remove(ids: [ReminderPlan.identifier(for: .now, calendar: calendar)])
    }

    private func setEnabled(_ value: Bool) {
        isEnabled = value
        defaults.set(value, forKey: Key.enabled)
    }

    private func clear() async {
        let ours = await centre.pendingIdentifiers().filter { $0.hasPrefix("reminder-") }
        centre.remove(ids: ours)
    }

    private func reschedule() async {
        await clear()
        let (title, body) = Self.copy(for: language)
        for entry in ReminderPlan.schedule(now: .now, hour: hour, minute: minute, todayDone: todayDone, calendar: calendar) {
            await centre.add(id: entry.id, fireDate: entry.fireDate, title: title, body: body)
        }
    }

    /// In the news language rather than the UI language: a reader who chose Hindi news
    /// on an English phone asked to be spoken to in Hindi.
    static func copy(for language: ContentLanguage) -> (title: String, body: String) {
        switch language {
        case .english: ("Today's five stories are ready", "Read them, then take your five shots.")
        case .hindi: ("आज की पाँच खबरें तैयार हैं", "पढ़िए, फिर पाँच सवालों पर निशाना लगाइए।")
        }
    }
}
```

- [ ] **Step 4: Run** both reminder suites. Expected: PASS.

- [ ] **Step 5: Wire it.**
  - **RootView:** add `@State private var reminders = ReminderScheduler()` and `.environment(reminders)`. In the launch task, after loading, call `await reminders.refresh(todayDone: history.hasPlayed(on: .now), language: language)`.
  - **ResultsView:** where `history.record()` is called, add `Task { await reminders.markTodayDone() }`. Below the review, when `!reminders.isEnabled && !reminderOffered` (`@AppStorage("reminderOffered")`), show a charcoal row: "Remind me tomorrow at \(time)?" with a `ChevronButtonStyle(prominent: false)` button "Remind me" that calls `enable()`, plus "Not now". Either one sets `reminderOffered = true`. Format the time with `Date` from `hour`/`minute`, using `.dateTime.hour().minute()`.
  - **ProfileView:** a "Daily reminder" section with a `Toggle("Remind me to read", isOn:)`, where the binding's setter calls `enable()` or `disable()` in a `Task`. When it's enabled, show a `DatePicker("Time", selection:, displayedComponents: .hourAndMinute)` whose setter calls `setTime`. When `wasDenied`, show the footnote "Notifications are off for NOVA." and a button "Open Settings" (`Nova.openAppSettings`).
  - Every preview that renders a view reading `ReminderScheduler` gets `.environment(ReminderScheduler())`.

- [ ] **Step 6: Run** `$TEST`, plus the macOS build. Extract and translate the new strings.

- [ ] **Step 7: Commit**: "Add an optional daily reminder that skips days already played".

---

### Task 7: Onboarding topic tiles redesign and Home category tabs

**Files:**
- Modify: `Features/Onboarding/OnboardingStyle.swift` (`ChoiceTile`, `tileHeight`), `Features/Onboarding/Pages/TopicsPage.swift`, `Features/Home/HomeView.swift`, `Services/NewsStore.swift`, `Features/Profile/ProfileView.swift`
- Create: `Components/TopicChip.swift`
- Test: `NOVATests/NewsStoreTests.swift`

**Interfaces:**
- Consumes: `StoryCategory` (7 cases), `TopicSelection.leading`, `ChoiceTile` (added in Task 2).
- Produces: `NewsStore.latest(limit: Int = 40, category: StoryCategory? = nil) -> [Story]`, `NewsStore.categories(ordered topics: TopicSelection) -> [StoryCategory]`, `NewsStore.generateSummaries(forLatest:category:)`. `struct TopicChip: View { init(title: LocalizedStringKey, tint: Color?, isOn: Bool, isLocked: Bool = false, action: @escaping () -> Void) }`.

- [ ] **Step 1: Failing store tests** (append to the `NewsStore` suite in `NewsStoreTests.swift`, reusing its `story(...)` helper, or adding one like `StorySelectionTests` has):

```swift
    @Test("Filtering by category keeps newest-first and the limit")
    func latestByCategory() {
        let store = NewsStore()
        store.adopt([
            story("a", .sports, hoursAgo: 1), story("b", .india, hoursAgo: 2), story("c", .sports, hoursAgo: 3)
        ])
        #expect(store.latest(category: .sports).map(\.id.rawValue) == ["a", "c"])
        #expect(store.latest(limit: 1, category: .sports).count == 1)
        #expect(store.latest().count == 3)
    }

    @Test("Only categories that arrived are listed, chosen ones first")
    func categoriesListOnlyPresent() {
        let store = NewsStore()
        store.adopt([story("a", .world), story("b", .sports), story("c", .india)])
        let listed = store.categories(ordered: TopicSelection(categories: [.sports]))
        #expect(listed.first == .sports)
        #expect(Set(listed) == [.world, .sports, .india])
        #expect(!listed.contains(.science))
    }
```

- [ ] **Step 2: Run** `$TEST -only-testing:NOVATests/NewsStoreTests` (use whatever suite struct name the file defines). Expected: FAIL.

- [ ] **Step 3: The store.** In `NewsStore`:

```swift
    /// The merged river for Home, newest first — all of it, or one category's.
    func latest(limit: Int = 40, category: StoryCategory? = nil) -> [Story] {
        allStories
            .filter { category == nil || $0.category == category }
            .prefix(limit)
            .map { $0.applying(summary: generatedSummaries[$0.id]) }
    }

    /// The categories Home can offer a tab for: only those some feed actually returned
    /// (Science has no Hindi feed; any feed can be down), in the reader's topic order.
    func categories(ordered topics: TopicSelection) -> [StoryCategory] {
        let present = Set(allStories.map(\.category))
        let base = StoryCategory.allCases.filter(present.contains)
        return base.filter(topics.contains) + base.filter { !topics.contains($0) }
    }
```

Give `generateSummaries(forLatest:)` a `category: StoryCategory? = nil` parameter that filters before `prefix(limit)`, so switching tabs queues that category's first stories through the one worker.

- [ ] **Step 4: Run** the store tests. Expected: PASS.

- [ ] **Step 5: `TopicChip` to Components.** Move `TopicChip` out of `ProfileView.swift` into `Components/TopicChip.swift`. Generalise it to `title: LocalizedStringKey`, `tint: Color?` (nil draws no square, which the "All" chip uses), `isOn`, `isLocked = false` and `action`. Set `.frame(minHeight: 44)` for the hit area. Keep its body and accessibility code as they are. Profile calls it with `TopicChip(title: LocalizedStringKey(category.title), tint: category.tint, …)`. Move `FlowChips` alongside it too, if Home needs it (it doesn't, since Home uses a horizontal scroll). Leave `FlowChips` where it is otherwise.

- [ ] **Step 6: Home tabs.** In `HomeView`, add `@State private var category: StoryCategory?` and `@AppStorage("pickedTopics") private var pickedTopicsRaw = ""`. Restructure the body so the river is a pinned section:

```swift
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30, pinnedViews: [.sectionHeaders]) {
                masthead
                TodayRoundCard()
                channelRail
                Section {
                    latestStories
                } header: {
                    categoryTabs
                }
            }
            .padding(.bottom, 32)
        }
```

`categoryTabs`:

```swift
    /// Pinned over the river once it scrolls up, on opaque paper with a hairline — no
    /// material, per the Opaque Ground Rule. Chips follow the reader's topic order.
    private var categoryTabs: some View {
        let categories = store.categories(ordered: TopicSelection(rawValue: pickedTopicsRaw))
        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Headlines")
                .padding(.horizontal, Nova.screenPadding)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TopicChip(title: "All", tint: nil, isOn: category == nil) { select(nil) }
                    ForEach(categories, id: \.self) { item in
                        TopicChip(title: LocalizedStringKey(item.title), tint: item.tint, isOn: category == item) { select(item) }
                    }
                }
                .padding(.horizontal, Nova.screenPadding)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Categories")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nova.paper)
        .overlay(alignment: .bottom) { Rectangle().fill(Nova.hairline).frame(height: 1) }
        .onChange(of: categories) {
            // A category that stopped arriving (language switch, feed down) can't stay selected.
            if let category, !categories.contains(category) { self.category = nil }
        }
    }

    private func select(_ next: StoryCategory?) {
        withAnimation(.snappy(duration: 0.25)) { category = next }
        store.generateSummaries(forLatest: NewsStore.riverGenerationLimit, category: next)
    }
```

In `latestStories`, remove the old `sectionTitle("Headlines")` (it now lives in the header) and use `store.latest(limit: Self.riverLimit, category: category)`. When the list is empty, the store is loaded and a category is selected, show `Text("No \(category.title.lowercased()) in the feeds right now.")` in the reading serif, secondary, with 20pt vertical padding, in place of `riverPlaceholder`. Keep `masthead`, `TodayRoundCard` and `channelRail` as they are. Their horizontal constraints still apply inside `LazyVStack`, which is also what keeps the scroll smooth with 40 rows.

- [ ] **Step 7: Topic tiles.** In `OnboardingStyle.swift`, set `static let tileHeight: CGFloat = 88` (comment: "88, not 112: seven tiles in two columns must clear the button"). `ChoiceTile` is already added in Task 2; confirm it reads:

```swift
/// A choice on charcoal. Chosen inverts to white — the same move as the white chevron and
/// Profile's ink chips — so the selection reads without colour. The category's tint stays
/// only as the 8pt square (the Coloured Square Rule); it used to flood the whole tile, and
/// three chosen tiles turned the page into a patchwork with a second accent system.
struct ChoiceTile: View {
    let title: String
    let symbol: String?
    let tint: Color?
    let isOn: Bool
    var height: CGFloat = Onboarding.tileHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isOn ? AnyShapeStyle(Nova.charcoal) : AnyShapeStyle(.white.opacity(0.55)))
                Spacer(minLength: 8)
            }
            HStack(spacing: 8) {
                if let tint {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous).fill(tint).frame(width: 8, height: 8)
                }
                Text(title)
                    .novaMeta(.subheadline, weight: .bold)
                    .foregroundStyle(isOn ? AnyShapeStyle(Nova.charcoal) : AnyShapeStyle(.secondary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: symbol == nil ? .leading : .topLeading)
        .frame(height: height)
        .padding(.horizontal, 16)
        .padding(.vertical, symbol == nil ? 0 : 14)
        .background {
            RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                .fill(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(Onboarding.surface))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                .strokeBorder(Nova.charcoalLine, lineWidth: isOn ? 0 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Nova.charcoal))
                    .padding(12)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .shadow(color: isOn ? .black.opacity(0.35) : .clear, radius: 14, y: 8)
        .scaleEffect(isOn ? 1 : 0.98)
    }
}
```

In `TopicsPage`, delete `TopicTile` and replace the `LazyVGrid` with a `Grid`. Rows come from `StoryCategory.allCases.chunked(into: 2)` (`Array.chunked` exists in `NewsStore.swift`), and a lone last tile gets `.gridCellColumns(2)`:

```swift
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(StoryCategory.allCases.chunked(into: 2).enumerated()), id: \.offset) { row, pair in
                    GridRow {
                        ForEach(Array(pair.enumerated()), id: \.element) { column, category in
                            tile(for: category, index: row * 2 + column)
                                .gridCellColumns(pair.count == 1 ? 2 : 1)
                        }
                    }
                }
            }
```

`tile(for:index:)` is the existing `Button` and its accessibility modifiers, with the label `ChoiceTile(title: category.title, symbol: category.symbolName, tint: category.tint, isOn: selection.contains(category))`. Update the doc comment at the top of `TopicsPage`: the tint-flood sentence becomes the inverted-white rationale.

- [ ] **Step 8: Verify visually.** Build, then screenshot onboarding page 5 (`-onboardingPage 5`, since topics is now fifth) with two and three topics chosen, and with none. Screenshot Home (`-startTab home`) at the top, and scrolled so the tabs are pinned. It's hard to scroll from a shell, so check pinning in the Xcode preview, and add a `#Preview("Home, Sports")` that starts with `category = .sports` via an init parameter `initialCategory: StoryCategory? = nil` (DEBUG preview only). Check dark appearance: `xcrun simctl ui booted appearance dark`. Check a large Dynamic Type size: `xcrun simctl ui booted content_size extra-extra-large`. Fix what the screenshots show in one batch, and reshoot once at most.

- [ ] **Step 9: Run** `$TEST`. Extract and translate any new strings.

- [ ] **Step 10: Commit**: "Calm the topic tiles to inverted white and add category tabs to Home".

---

### Task 8: Documentation, full verification

**Files:**
- Modify: `CLAUDE.md`, `DESIGN.md`, `PRODUCT.md`

- [ ] **Step 1: CLAUDE.md.**
  - Correct the deployment target to 26.0 everywhere, and the feed count: "English and Hindi feeds, filtered by `ContentLanguage`".
  - Describe the four tabs (Home, Scroll, Prep, Profile) and `NewsStore` versus `DailySession`.
  - Add sections for the language (content language is in-app, UI language is iOS per-app via the String Catalog, and the extraction/sync commands from Task 3 Step 3), the `QuestionArchive` and Prep (first attempt is kept, revision never touches the streak, corrupt file set aside), sharing (`ShareGrid`, `ShareRenderer`) and reminders (seven non-repeating reminders, and why).
  - Onboarding has six pages, with `-onboardingPage 1` = language.
  - Add `-startTab prep`.
  - Record the "everything free" constraint under Content.

- [ ] **Step 2: DESIGN.md.**
  - Add `tint-sports` `#138496` and `tint-entertainment` `#D6457A` to the colours and the prose ("seven-hue category family").
  - The `topic-tile` component becomes the chosen-white spec (height 88pt, the 8pt square, the charcoal-line border when unchosen).
  - Add the Home category tabs (pinned, opaque paper, `TopicChip`), the Prep tab and revision on paper, and the share cards.
- [ ] **Step 3: PRODUCT.md.** Change the users line to include Hindi readers and exam aspirants. Change Capabilities to list Hindi, local reminders and on-device sharing. Change the Constraints line to "Everything free: no keys, accounts or paid services."
- [ ] **Step 4: Full verification.** Run `$TEST`, which must be all green. Build for macOS. Then take one batch of simulator screenshots, in English and in Hindi:
  - the onboarding language page and topics page;
  - Home with the tabs;
  - Prep, empty and seeded (`-simulateRound 3 -previewDeck YES`, then `-startTab prep`);
  - Results with the share button;
  - Profile with language and reminder.

  Save them in the scratchpad and look at every one.
- [ ] **Step 5: Commit**: "Document languages, Prep, sharing and reminders".
