# Voice briefing — design

Date: 2026-09-27 · Branch: `feat/voice-readout` · Status: approved design, awaiting spec review

## Goal

A floating mic button that lets a reader ask for news out loud and hear it back. It greets the
reader ("Hi Prakash, what news summary do you want?"), listens to one request ("tech news",
"भारत की खबरें", "what's happening in business"), and speaks up to ten highlights, one short
line each (~90 seconds in total).

Constraints:

- **Free.** No paid APIs, no keys, nothing secret in the binary.
- **One-shot.** Greet → listen → answer → done. Tap again to ask again. No follow-ups in v1.
- **English and Hindi**, for both listening and speaking.

Success: a reader on the Home, Scroll or Profile tab taps the button, says a topic, and within a
few seconds hears ten relevant, current highlights in the language they chose, and can tap any of
them to open the story. With ZeroAPI down and no Apple Intelligence, it still works.

## Non-goals (v1)

- Follow-up turns ("tell me more about number three", "next", "skip").
- Free-form Q&A about the news.
- Wake word or always-listening mode.
- Cloud speech-to-text or cloud voices.

## Experience

**Floater.** A round mic button pinned bottom-trailing, clear of the tab bar. It is on paper
screens only: hidden while onboarding is showing (`hasSeenWelcome == false`) and whenever a route
is pushed on the Scroll tab (`.quizIntro`, `.quiz`, `.results`), where it would sit on the
slingshot. Built on `PressableStyle`, `Nova.ink` on `Nova.sheet` with a hairline. No glass, no
gradient (DESIGN.md).

**Panel.** Tapping opens a paper bottom sheet that moves through:

1. **Greeting**: speaks and shows "Hi <readerName>, what news summary do you want?" (or
   "नमस्ते <name>, आप कौन सी खबरें सुनना चाहेंगे?"). If there is no name, the greeting omits it.
2. **Listening**: live transcript. Ends after ~1.5 s of silence, on tap, or after 10 s.
3. **Thinking**: "Finding stories…".
4. **Speaking**: numbered rows (source, one line). The row being spoken is highlighted. Tapping a
   row stops speech and opens that story.
5. **Done**: the list stays on screen; "Ask again" restarts from Greeting.

A Stop control is visible in every state and returns to idle. Closing the sheet also stops.

**Language chip.** `EN / हिं` in the panel header. Defaults to Hindi when the device's preferred
language is Hindi, otherwise English. Stored in `@AppStorage("voiceLanguage")`. It sets the
recognition locale (`en-IN` / `hi-IN`), the voice, and the language the briefing is written in.

**Honesty label.** When the briefing came from ZeroAPI or the on-device model, the panel shows a
`novaMeta()` label: "AI-written · unchecked". Generated text is machine-written and must not read
as verified reporting (CLAUDE.md, Content).

**Accessibility.** The floater has an accessibility label ("Ask NOVA for a news briefing"). Every
panel state is readable by VoiceOver, and the highlight rows are buttons. Under Reduce Motion the
row highlight changes without animation. While VoiceOver is running the synthesizer still speaks.
The floater is reachable without gestures beyond a tap.

## Content

Highlights come from `NewsStore.allStories`: every item from all eleven feeds, newest first
(dozens to 100+). This is not the five-story deck. `Highlights.candidates` filters by the
requested category (or takes all categories when none was named), removes duplicate lowercased
titles, and takes the newest N:

- 40 for the AI tiers, which choose the ten most important.
- 10 for the rules tier, which cannot judge importance and so takes the newest.

## Architecture

```
tap ─► VoiceAssistant (state machine, @Observable)
          │ greet ──► Speaker (AVSpeechSynthesizer)
          │ listen ─► SpeechListener (SFSpeechRecognizer + AVAudioEngine)
          │ think ──► VoiceIntent.parse ─► Highlights.candidates(NewsStore.allStories)
          │              └─► FallbackBriefingWriter
          │                    1. ZeroAPIBriefingWriter
          │                    2. OnDeviceBriefingWriter   (Foundation Models)
          │                    3. RuleBriefingWriter       (never fails)
          │ speak ─► Speaker, one utterance per item, reports index
          └ audio session: .playAndRecord/.spokenAudio while open, back to .ambient after
```

### Pure units (no SwiftUI, no AVFoundation, unit-tested)

- **`VoiceLanguage`**: `.english`, `.hindi`, with `locale`, `voiceLanguageCode`, and the fixed
  phrases (greeting, "still loading", "didn't catch that", …).
- **`VoiceIntent`**: `parse(_ transcript: String, language:) -> VoiceIntent { category:
  StoryCategory?; count: Int }`. It uses keyword tables per category in both languages and
  scripts: "tech/technology/टेक/तकनीक/प्रौद्योगिकी", "india/भारत/देश", "business/market/व्यापार/बिज़नेस/बाज़ार",
  "world/international/दुनिया/विदेश", "science/विज्ञान". Numbers like "top 5" and "पाँच" set the
  count, clamped to 1…10. The default is 10. No match means all categories. Every tier uses this
  as its category filter; the AI tiers also get the raw transcript.
- **`Highlights`**: `candidates(for: VoiceIntent, from: [Story], limit: Int) -> [Story]`.
- **`Briefing`**: `{ intro: String; items: [Item]; tier: Tier }`, `Item { storyID: StoryID;
  line: String }`, `Tier { zeroAPI, onDevice, rules }`. `validated(against candidates:)` drops
  items whose ID is not in the pool, drops duplicates and empty lines, and caps the list at
  `intent.count`. A briefing with zero valid items counts as a failure, so the chain moves to the
  next tier.

### Writers

```swift
protocol BriefingWriter: Sendable {
    func brief(request: String, intent: VoiceIntent, language: VoiceLanguage,
               candidates: [Story]) async throws -> Briefing
}
```

1. **`ZeroAPIBriefingWriter`**
   - Request: `POST https://zeroapi.in/api/ai` with the same headers (`Content-Type`,
     `Origin: https://zeroapi.in`) and model (`llama-3.1-8b-instant`) as `QuestionGenerator`.
     Never use a `gpt-oss` model: they return empty `content`.
   - Prompt: the transcript, the language, and candidates as `id | source | title`. It asks for
     JSON `{"intro": "...", "items": [{"id": "...", "line": "..."}]}` with each line at most 15
     words, written in the requested language.
   - Reply: trimmed to the outermost `{…}` before decoding, as `Generated(decoding:)` does.
   - Settings: `max_tokens` 700, `timeoutInterval` 8 s, no retry (the next tier is the retry).
     `endpoint` and `session` are injectable.
   - The wire types are private to this file. `QuestionGenerator`'s are left alone.
2. **`OnDeviceBriefingWriter`**
   - Wrapped in `#if canImport(FoundationModels)`.
   - Throws `.unavailable` unless `SystemLanguageModel.default.availability == .available` and the
     model supports the language's locale.
   - Uses `LanguageModelSession` with a `@Generable` struct that mirrors the JSON shape, the same
     prompt, and an 8 s budget.
3. **`RuleBriefingWriter`**
   - Takes the newest 10 candidates. Each line is `"<source>: <title trimmed to 12 words>"`.
     The intro comes from `VoiceLanguage` ("Here are the top ten technology stories").
   - For Hindi, it translates titles with the Translation framework only when the en→hi pack is
     already installed (no download prompt mid-conversation). Otherwise the intro is in Hindi, it
     adds "शीर्षक अंग्रेज़ी में हैं" ("headlines are in English"), and the lines are spoken in
     English with the English voice.
   - It throws only on an empty pool.
4. **`FallbackBriefingWriter(writers:)`** tries each writer in order. It treats a thrown error, a
   timeout, or a validation failure as "next". It returns the first valid `Briefing`, with `tier`
   set to the writer that produced it.

### Device units

- **`SpeechListener`**
  - Requests speech and microphone permission.
  - Runs `SFSpeechRecognizer(locale:)` with `requiresOnDeviceRecognition = true` when
    `supportsOnDeviceRecognition`, and otherwise lets Apple's server recognise the speech. That is
    still free and needs no key, but it is not offline.
  - Publishes the partial transcript. Silence detection is a 1.5 s timer reset on each partial
    result.
  - If `hi-IN` is unavailable, it reports `.localeUnavailable`, and the assistant switches to
    English and says so.
- **`Speaker`**
  - Wraps `AVSpeechSynthesizer`. It speaks one utterance per line and reports the current index
    through the delegate.
  - It picks the best installed voice for `en-IN` / `hi-IN`, falling back to any voice for the
    language.
  - `stop()` is immediate.
- **Audio session**
  - While the panel is open: `.playAndRecord`, mode `.spokenAudio`, options
    `[.defaultToSpeaker, .duckOthers, .allowBluetoothHFP]`.
  - On close, it restores `SoundPlayer`'s `.ambient`, so the game keeps respecting the silent
    switch.
  - `SoundPlayer` gains `suspend()` / `resume()` for this. The iOS/visionOS-only calls stay
    inside those helpers and never appear at call sites.

### State and wiring

- **`VoiceAssistant`**: an `@Observable` class, main-actor by default. States are `idle`,
  `greeting`, `listening(transcript)`, `thinking`, `speaking(index)`, `done`, and
  `failed(VoiceFailure)`.
  - It owns `SpeechListener`, `Speaker` and the writer chain.
  - It reads the story pool from `NewsStore` and the name from `@AppStorage("readerName")`, and
    exposes the current `Briefing`.
  - It is created in `RootView` as `@State` and injected with `.environment()`, like
    `DailySession` and `NewsStore`.
- **Views**: `Features/Voice/VoiceFloater.swift` and `Features/Voice/VoiceBriefingPanel.swift`.
  The floater is added in `RootView` as `.overlay(alignment: .bottomTrailing)` on the existing
  `ZStack`, in the same place as `DebugRestartButton`.
- **Opening a story from a row**: stops speech, closes the panel, sets `router.tab = .home`, and
  appends `HomeRoute.story(id)` to `router.homePath`. The existing `StoryDetailView(storyID:)`
  already handles any `StoryID` in `NewsStore`.
- **Info.plist**: add `INFOPLIST_KEY_NSMicrophoneUsageDescription` ("NOVA listens when you tap
  the mic so you can ask for a news briefing.") and
  `INFOPLIST_KEY_NSSpeechRecognitionUsageDescription` to both app build configurations in
  `project.pbxproj`. New Swift files need no pbxproj edit (synchronized groups).
- **macOS**: Speech and AVSpeechSynthesizer exist there, but AVAudioSession does not. Session code
  sits behind the `SoundPlayer` helpers, so the target keeps building for `macosx`.

## Failure handling

| Situation | Behaviour |
|---|---|
| Microphone or speech permission denied | Panel explains; button opens Settings. Nothing is spoken. |
| Nothing heard / empty transcript | "I didn't catch that" once, listens again; second miss → done. |
| `hi-IN` recognition unavailable | Switch the chip to EN, say so in Hindi, continue in English. |
| `NewsStore` still empty | "Stories are still loading, try again in a moment." |
| Category has fewer than N stories | Speak what there is; intro says the real count. |
| ZeroAPI 429 / down / bad JSON | Next tier, silently. |
| Foundation Models unavailable | Next tier, silently. |
| Call or other audio interruption | Stop, restore the session, return to idle. |

## Testing

Swift Testing, new suites in `NOVATests/`:

- **`VoiceIntentTests`**: English and Hindi keywords per category, Devanagari and romanised forms,
  numbers, clamping, no-match → all categories.
- **`HighlightsTests`**: category filter, dedupe, newest first, limit. Uses the `story(...)`
  factory pattern from `NewsServiceTests`.
- **`BriefingTests`**: validation drops unknown or duplicate IDs and empty lines, caps at count;
  zero valid items → failure; JSON decoding with surrounding prose.
- **`FallbackBriefingWriterTests`**: stub writers that throw, hang past the timeout, or return an
  invalid briefing; asserts order and `tier`.
- **`RuleBriefingWriterTests`**: line format, 12-word trim, English fallback lines for Hindi
  without translation.
- **`ZeroAPIBriefingWriterTests`**: `https://nova-tests.invalid` endpoint with a 2 s ephemeral
  session throws, so the chain falls through (same trick as `QuestionGeneratorTests`).

Manual, on the iPhone 17 Pro simulator (it uses the Mac microphone):

- Tap the floater, say "tech news", and hear the greeting and ten lines.
- Tap a row to open the story.
- Switch to हिं and repeat.
- Deny permission and check the Settings path.
- Check the floater is hidden on quiz, intro and results screens and during onboarding.

On a device: the Hindi voice, and the Foundation Models tier on an Apple Intelligence iPhone.

## Risks

- **ZeroAPI** is one person's free project and can disappear or start rate-limiting (~30/min).
  The two lower tiers exist for exactly this.
- **Foundation Models' Hindi support** depends on the OS release. It is checked at runtime, so
  this is not a build-time assumption.
- **Server-side speech recognition** runs when on-device isn't supported for a locale. It is free
  but sends audio to Apple. The permission string says the app listens only when you tap.
- **Hindi on the rules tier** is only as good as the installed translation pack. Without one,
  headlines are read in English.
