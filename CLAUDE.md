# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

NOVA is a SwiftUI news-reading game: you swipe through a deck of story cards, then answer a
question about each story by slingshotting a paper ball into one of several moving hoops.
The Xcode project lives in `NOVA/` (repo root holds only the README and this file).

Multiplatform target: `SUPPORTED_PLATFORMS = iphoneos iphonesimulator macosx xros xrsimulator`,
deployment target 27.0, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` and
`SWIFT_APPROACHABLE_CONCURRENCY = YES`. Because macOS is a real destination, iOS-only APIs
must be wrapped — see the `novaInlineTitle()` / `novaHiddenNavigationBar()` helpers in
`NOVA/NOVA/DesignSystem/NovaTheme.swift` rather than adding raw `#if os(iOS)` at call sites.

## Commands

All commands run from `NOVA/` (the directory containing `NOVA.xcodeproj`).

**Toolchain:** the project is saved in Xcode project format `objectVersion = 77` with a
deployment target of 26.0, and builds and tests on Xcode 26.6. (An earlier note here claimed
`objectVersion = 110`, tools 27.0 and a hard Xcode 27 requirement; the project has been re-saved
since and that is no longer true.) Source files live in filesystem-synchronized groups, so a new
`.swift` file is picked up automatically — there is no `project.pbxproj` to edit when adding one.

```bash
# Build for simulator
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Run the whole test suite
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

# Run one suite or one test (Swift Testing: identifier names, not the @Test display strings)
xcodebuild ... test -only-testing:NOVATests/RoundEngineTests
xcodebuild ... test -only-testing:NOVATests/RoundEngineTests/correctAnswerIncrementsScore

# List available simulator destinations if the one above is missing
xcodebuild -project NOVA.xcodeproj -scheme NOVA -showdestinations
```

Tests use **Swift Testing** (`import Testing`, `@Suite`, `@Test`, `#expect`), not XCTest.

## Architecture

The layering exists so the rules and the physics stay testable without SwiftUI. Two files hold
almost all of the logic; the views are mostly rendering and gesture handling.

**State (`GameLogic/`)**
- `DailySession` — the single `@Observable` source of truth, injected via `.environment()` in
  `App/RootView.swift`. Owns today's stories, read-progress (`readStoryIDs`), and the round
  engine. Views read from it and send actions to it; they never compute scores.
  `load(from:)` fetches the live deck and rebuilds the engine. `applyTopics` reorders
  `loadedStories` (the deck as it arrived), never `MockNewsService.todayStories` — it used to do
  the latter, which was invisible while the mock *was* the deck but silently replaced every live
  story with demo content once one existed, because `RootView` applies topics on every launch.
- `RoundEngine` — a plain `struct` with no SwiftUI import: answer validation, scoring,
  accuracy, progression. Answering sets `pendingResult`; `advance()` must be called to clear
  it before the next answer is accepted. This two-step exists so the view can show feedback.
- A day is meant to hold several `GameRound`s; only one ships today, and `DailySession.engine`
  is the seam where the rest get added.

**Navigation (`App/AppRouter.swift`)**
- `StoryReaderView` is the *root*, not a route. Today's story index is a sheet over it.
- Only `.quizIntro`, `.quiz`, `.results` are routes. Use `replace(with:)` when moving forward
  through finished steps so they can't be swiped back into.

**Onboarding (`Features/Onboarding/`)**
- Five pages — manifesto, ritual, name, topics, ready — overlaid by `RootView` while
  `@AppStorage("hasSeenWelcome")` is false. Not a route, and nothing may swipe back in.
- **To restart it, use the Restart button** pinned top-left (DEBUG only; the full-width
  button owns the bottom edge). Do *not* add a
  `-hasSeenWelcome NO` launch argument: launch arguments live in `NSArgumentDomain`, which
  outranks the app's own defaults for the whole process, so the flow's write of `true` is
  real but every read after it still returns `false` and the hand-off looks broken.
- Other DEBUG launch arguments, both read-only so they don't hit that trap:
  `-onboardingPage N` opens straight onto page N; `-onboardingAutoPlay YES` walks the whole
  journey by itself, which is the only way to record the transitions (synthetic taps aren't
  available from a shell, and `simctl` has no `tap`).
- Answers are real: the name greets the reader on the last page, and chosen categories
  **reorder** the deck via `[Story].leading(with:)` — they never filter it, because the
  round needs all five stories. `RootView` applies them on every launch, not just the one
  that finished onboarding.
- Visual language lives in `OnboardingStyle.swift`: flat grey ground, 36 pt bold type in
  two colours, surfaces a shade *darker* than the ground so chosen tiles are the only thing
  on the page, and one full-width `.primary` button (not literal black — it has to invert
  on a dark ground). Disabled, the button's label says what is missing.
- The ripple is `RippleWave` (maths, tested) + `Ripple.metal` (a `layerEffect`) + a
  `TimelineView` driver in `OnboardingFlow`. Pages swap at 45 % of the ring so the water
  reveals the next one. Tune the feel in the "Ripple tuning" preview, then move the numbers
  into `RippleWave.Tuning`.
- **The rippled layer ignores the safe area**, so the page inside it is inset by hand from a
  `GeometryReader`. Don't measure that inset into `@State`: it feeds the page's own layout
  back into the measurement that produced it, and the resulting loop renders the entire
  window blank — the tallest page hit this and nothing at all drew, with no crash.
- `simctl io screenshot` redacts every `TextField` (a yellow bar), focused or not, so the
  name page can't be verified by screenshot. Use an Xcode preview or a device.
- To force onboarding back on the simulator, **uninstall and reinstall**. `simctl spawn …
  defaults write hasSeenWelcome -bool NO` and editing the container plist by hand both look
  like they work and don't: cfprefsd keeps the cached value and rewrites the file when the
  app launches.
- The Metal Toolchain is a separate download on Xcode 26+: if a build fails with
  `cannot execute tool 'metal'`, run `xcodebuild -downloadComponent MetalToolchain`.

**Physics (`Features/Game/ShotCourt.swift`)**
- `ShotCourt` is pure CoreGraphics math (layout, pull-back → velocity, trajectory simulation,
  rim/score/miss detection) with no SwiftUI, covered by `ShotCourtTests`. Tune feel here.
- Drag maps to *velocity*, not to a landing point — an earlier landing-point mapping needed
  pulls longer than the screen for far hoops. Don't reintroduce a live landing preview; the
  player is deliberately shown only the start of the arc.
- Hoops patrol sideways. Shots are judged against `withHoopOffsets(...)` (where the baskets
  actually are at release), not against the resting layout.
- `ShotCourtView` reports which basket the ball entered and takes the judged `AnswerSubmission`
  back as input — it never decides correctness.

**Models (`Models/`)** — typed ID wrappers (`StoryID`, `QuestionID`, `RoundID`) that encode as
plain strings. `Question.answers` is intentionally variable-length; the basket-per-answer
layout is a view concern, not a model constraint.

**Design system (`DesignSystem/NovaTheme.swift`)** — deliberately small: an accent colour,
corner radii, and two font ramps (`Nova.display` = SF for headlines, `Nova.reading` = serif for
body). Native materials and controls do the rest; don't add a parallel colour or glass system.
`novaCard()` is opaque on purpose so body text never sits on translucency over the backdrop.

**Content (`Services/`)** — `NewsService` is the protocol the deck comes from.
`LiveNewsService` is what ships; `PreviewNewsService` serves `MockNewsService`'s hand-authored
content to previews and tests. `MockNewsService` itself is a case-less enum used as a namespace,
which is why the preview conformance is a separate type rather than an extension on it.

- **Feeds (`RSSFeed.swift`)** — nine publisher feeds, no API keys. A feed's category is pinned
  per feed, not read from the item, because publishers' own `<category>` tags don't agree.
  **A feed only earns a category if everything in it belongs there**: CNBC's top-stories feed
  was pinned to `.business` and promptly labelled a Ukraine war story "Business". The comment
  block at the bottom of that file lists feeds already checked and rejected (Reuters and AP have
  no working free feed; Scroll.in, The Wire and Firstpost return HTML or 404) — read it before
  adding a source, so the dead ones don't get re-added.
- **Parsing (`RSSParser.swift`)** — pure, no networking, tested against samples of the real
  feeds. Real feeds vary more than the spec suggests: CDATA on some publishers and not others
  (both `foundCharacters` and `foundCDATA` must feed one buffer), images in three different tags
  with Guardian sending three widths per item, `<p>`-wrapped HTML in descriptions, and four date
  formats. Anything unparseable costs that item, never the whole deck.
- **Questions (`QuestionGenerator.swift`)** — a feed gives a headline and a sentence, never
  enough to ask a question with a provable answer, so the card summary and the quiz question are
  generated from it via ZeroAPI's undocumented `/api/ai`, which proxies Groq and needs no key
  (nothing secret ships in the binary). Use a non-reasoning model: the `openai/gpt-oss-*` models
  that endpoint defaults to spend the whole `max_tokens` budget on a `reasoning` field and return
  empty `content`, which reads like a parse failure and isn't.
- ZeroAPI is one person's free project and can change or vanish without notice, so a failed
  generation falls back to the feed's own summary trimmed to 50 words and no question. Keep that
  path working — it is the only thing between an outage and a dead deck.
- **Generated question text is machine-written and unchecked.** Like `MockNewsService.isDemoContent`,
  it must not be presented to real readers as verified reporting.

**Sound (`Services/SoundPlayer.swift`)** — preloaded `AVAudioPlayer`s on an `.ambient` session
(respects the silent switch, never interrupts other audio). Failures are swallowed by design.

## Conventions

- Views read `@Environment(DailySession.self)` / `AppRouter` / `SoundPlayer`; nothing is passed
  down manually through initialisers.
- Both `StoryReaderView` and `ShotCourtView` honour `accessibilityReduceMotion`, and the quiz
  has a VoiceOver-driven fallback path — keep new interactions reachable without the gesture.
- Comments in this codebase explain *why* a decision was made (usually recording an approach
  that failed). Match that; don't strip them.
