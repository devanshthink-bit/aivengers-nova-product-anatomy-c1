# Welcome screen with water-ripple CTA

First screen a new NOVA user sees. Typographic, one size, one weight, two colours.
A single "Get started" button at the bottom; tapping it sends a ring of refraction up
through the page, and when the ring has passed the page crossfades into what comes next.

Reference: Brink's onboarding opener (Mobbin screen `1cf947ad-…`). Read from the 1.9 s
clip: 0.0–0.9 s a distortion ring travels from the tap point, bending the text and
carrying a soft white highlight; ahead of and behind the ring the text is crisp.
1.0–1.3 s the whole screen crossfades to the next page. Two beats, not one.

## Scope

In: the screen, the ripple, the first-launch gate, the handoff point. Out: the pages that
follow (page 2 onward). The handoff target is a single point in `RootView` so page 2
replaces it later in one line.

## Screen

`WelcomeView` in `Features/Welcome/`.

- Background: near-white neutral (`.background`) with a faint indigo wash at the top
  (`Nova.accent` at ~6 %). Paper, not the reader's saturated gradient.
- Top-left: NOVA mark (`sparkles`-style SF Symbol) + "NOVA" in `.subheadline` semibold,
  `.secondary`.
- One text block in `Nova.display(.largeTitle)` — same size, same weight throughout.
  Key words `.primary`, the rest `.secondary`. No bold, no size change. Line spacing
  loose (~+6).
- Copy (emphasis shown in bold; the rendered text is one weight, two colours):
  > **Know** the world and **local** updates quick and smooth **like water**.
- Bottom: pill button "Get started", `.glassProminent`, tinted `Nova.accent`, in a
  `safeAreaBar(edge: .bottom)` like the quiz screens. Text capped at
  `Nova.readingMaxWidth` on iPad, as the reader does.
- Semantic colours only, so dark mode falls out for free.

## Ripple

Three pieces, separated so the maths is testable and the feel is tunable.

**`RippleWave` (struct, no SwiftUI).** Given `origin`, `screenDiagonal`, `duration`,
`bandWidth`, `amplitude`, exposes
`radius(at progress)`, `amplitude(at progress)` (decays linearly to ~20 % as the ring
grows), `isComplete(at progress)` (ring radius > diagonal + bandWidth), and the shader
argument list as a `[Float]`. Swift Testing covers these.

**`Ripple.metal` (one `[[stitchable]]` layer effect).** Per pixel: `d = distance(pos,
origin)`; `x = (d − radius) / bandWidth`; if `|x| < 1`: displace the sample toward
`origin` by `amplitude × sin(x·π) × (1 − |x|)`; add white by `highlight × (1 − |x|)²`.
Otherwise pass through. Applied with `.layerEffect(…, maxSampleOffset:)` on the text
stack only — the button and the wordmark stay still.

**Driver (inside `WelcomeView`).** Tap → record the button's centre in the view's
coordinate space (via `onGeometryChange`) → `.sensoryFeedback(.impact(weight: .light))`
→ `TimelineView(.animation)` advances `progress` from tap time over `duration` (0.9 s).
When `isComplete`, call `onFinished` and the parent crossfades (0.35 s, `.easeInOut`).
The button disables itself on tap so a second drop can't start.

**Tuning preview.** A second `#Preview` with `@Previewable @State` sliders for
`amplitude`, `bandWidth`, `duration`, `highlight`, and a "Drop" button. Numbers agreed
there become the defaults in `RippleWave`.

**Reduce Motion.** With `accessibilityReduceMotion` on, the tap skips the ripple and
goes straight to the crossfade. The shader is never applied.

## Flow and state

- `@AppStorage("hasSeenWelcome")` in `RootView`. While `false`, `WelcomeView` is
  overlaid on the `NavigationStack` with `.transition(.opacity)`. Its `onFinished` sets
  the flag `true` inside `withAnimation`, which is the crossfade.
- Not a `Route`. Like the reader it is not navigated *to*, and nothing may swipe back
  into it. `AppRouter` and `DailySession` are untouched.
- A debug-only way to reset the flag is not in scope; `xcrun simctl uninstall` does it.

## Testing

- `RippleWaveTests`: radius grows linearly with progress and reaches the diagonal;
  amplitude decays and never goes negative; `isComplete` flips exactly once; shader
  arguments have the expected count and order.
- Visual: frame-by-frame screenshots of the ripple on the simulator, compared against
  the Brink frames, plus dark mode and iPad width checks in the canvas.
- Existing 32 tests keep passing.

## Files

New: `NOVA/NOVA/Features/Welcome/WelcomeView.swift`, `…/RippleWave.swift`,
`…/Ripple.metal`, `NOVA/NOVATests/RippleWaveTests.swift`.
Touched: `NOVA/NOVA/App/RootView.swift`.
