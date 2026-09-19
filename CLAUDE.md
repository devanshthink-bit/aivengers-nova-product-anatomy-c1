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

**Toolchain requirement:** the project is saved in Xcode project format `objectVersion = 110`
(created with tools 27.0) and every deployment target is 27.0. Xcode 26.x refuses to open it —
`The project cannot be opened because it is in a future Xcode project file format (110)`. Xcode 27
must be installed and selected (`xcode-select -p`) before any command below will work.

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
- `RoundEngine` — a plain `struct` with no SwiftUI import: answer validation, scoring,
  accuracy, progression. Answering sets `pendingResult`; `advance()` must be called to clear
  it before the next answer is accepted. This two-step exists so the view can show feedback.
- A day is meant to hold several `GameRound`s; only one ships today, and `DailySession.engine`
  is the seam where the rest get added.

**Navigation (`App/AppRouter.swift`)**
- `StoryReaderView` is the *root*, not a route. Today's story index is a sheet over it.
- Only `.quizIntro`, `.quiz`, `.results` are routes. Use `replace(with:)` when moving forward
  through finished steps so they can't be swiped back into.

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

**Content (`Services/MockNewsService.swift`)** — all stories and questions are invented demo
content with fictional "NOVA desk" sources, guarded by `isDemoContent`. Keep sources fictional
when adding content, and replace this service before showing anything to real readers.

**Sound (`Services/SoundPlayer.swift`)** — preloaded `AVAudioPlayer`s on an `.ambient` session
(respects the silent switch, never interrupts other audio). Failures are swallowed by design.

## Conventions

- Views read `@Environment(DailySession.self)` / `AppRouter` / `SoundPlayer`; nothing is passed
  down manually through initialisers.
- Both `StoryReaderView` and `ShotCourtView` honour `accessibilityReduceMotion`, and the quiz
  has a VoiceOver-driven fallback path — keep new interactions reachable without the gesture.
- Comments in this codebase explain *why* a decision was made (usually recording an approach
  that failed). Match that; don't strip them.
