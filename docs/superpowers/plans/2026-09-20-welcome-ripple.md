# Welcome Screen with Water-Ripple CTA — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A first-launch welcome screen whose "Get started" button sends a ring of refraction up through the page, then crossfades into the reader.

**Architecture:** The ripple splits into three pieces: `RippleWave` (plain maths, tested), `Ripple.metal` (a SwiftUI `layerEffect` shader that displaces and highlights inside a ring), and a driver inside `WelcomeView` (a `TimelineView` feeding elapsed time to the shader). `RootView` overlays the screen while an `@AppStorage` flag is false and crossfades it away when the ripple finishes.

**Tech Stack:** SwiftUI (iOS/macOS/visionOS 26), Metal Shading Language via `SwiftUI/SwiftUI.h`, Swift Testing, `@AppStorage`.

**Spec:** `docs/superpowers/specs/2026-09-20-welcome-ripple-design.md`

## Global Constraints

- Copy, verbatim: `Know the world and local updates quick and smooth like water.` Emphasised words (`.primary`): **Know**, **local**, **like water**. Everything else `.secondary`. One font, one size, one weight.
- CTA label: `Get started`.
- No new `Route`. `AppRouter` and `DailySession` are not modified.
- Semantic colours only (`.background`, `.primary`, `.secondary`, `Nova.accent`).
- Ripple default timing: `duration 0.9 s`, crossfade `0.35 s easeInOut`.
- Reduce Motion on → no ripple, crossfade only, shader never applied.
- All commands run from `NOVA/` (the folder containing `NOVA.xcodeproj`). Build/test destination: `platform=iOS Simulator,name=iPhone 17 Pro`. The existing 32 tests must keep passing.
- Every commit ends with `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`.
- Files placed under `NOVA/NOVA/` or `NOVA/NOVATests/` are picked up automatically (the project uses Xcode synchronized folder groups). A `.metal` file there is compiled into the app's default Metal library with no project edits.

---

### Task 1: `RippleWave` — the maths, test-first

**Files:**
- Create: `NOVA/NOVA/Features/Welcome/RippleWave.swift`
- Test: `NOVA/NOVATests/RippleWaveTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct RippleWave: Equatable, Sendable {
      struct Tuning: Equatable, Sendable {
          var duration: Double = 0.9
          var bandWidth: CGFloat = 110
          var amplitude: CGFloat = 26
          var highlight: Double = 0.35
      }
      let origin: CGPoint
      let reach: CGFloat          // distance from origin to the farthest corner
      let tuning: Tuning
      init(origin: CGPoint, in size: CGSize, tuning: Tuning = Tuning())
      func progress(elapsed: TimeInterval) -> Double   // 0...1, clamped
      func radius(at progress: Double) -> CGFloat      // eased, ends at reach + bandWidth
      func amplitude(at progress: Double) -> CGFloat   // decays to 20 % of tuning.amplitude
      func isComplete(at progress: Double) -> Bool
  }
  ```

- [ ] **Step 1: Write the failing tests**

```swift
//
//  RippleWaveTests.swift
//  NOVATests
//

import CoreGraphics
import Testing
@testable import NOVA

@Suite("Ripple wave")
struct RippleWaveTests {

    private static let size = CGSize(width: 400, height: 800)
    /// A drop near the bottom centre, where the CTA sits.
    private static let wave = RippleWave(origin: CGPoint(x: 200, y: 720), in: size)

    @Test("Reach is the distance to the farthest corner")
    func reachIsFarthestCorner() {
        // Farthest corner from (200, 720) in a 400×800 space is a top corner: (0, 0) or (400, 0).
        let expected = hypot(200, 720)
        #expect(abs(Self.wave.reach - expected) < 0.001)
    }

    @Test("Progress is elapsed time over duration, clamped to 0...1")
    func progressClamps() {
        let wave = Self.wave
        #expect(wave.progress(elapsed: -1) == 0)
        #expect(wave.progress(elapsed: 0) == 0)
        #expect(abs(wave.progress(elapsed: 0.45) - 0.5) < 0.001)
        #expect(wave.progress(elapsed: 0.9) == 1)
        #expect(wave.progress(elapsed: 5) == 1)
    }

    @Test("The ring starts at the origin and ends past the farthest corner")
    func radiusSpansTheScreen() {
        let wave = Self.wave
        #expect(wave.radius(at: 0) == 0)
        // At the end the far edge of the band has cleared the farthest corner.
        #expect(wave.radius(at: 1) >= wave.reach + wave.tuning.bandWidth)
    }

    @Test("The ring only ever moves outward")
    func radiusIsMonotonic() {
        let wave = Self.wave
        var last = wave.radius(at: 0)
        for step in 1...50 {
            let r = wave.radius(at: Double(step) / 50)
            #expect(r >= last)
            last = r
        }
    }

    @Test("The ring decelerates: it covers more ground early than late")
    func radiusEasesOut() {
        let wave = Self.wave
        let early = wave.radius(at: 0.25) - wave.radius(at: 0)
        let late = wave.radius(at: 1) - wave.radius(at: 0.75)
        #expect(early > late)
    }

    @Test("Amplitude decays to a fifth and never goes negative")
    func amplitudeDecays() {
        let wave = Self.wave
        #expect(abs(wave.amplitude(at: 0) - wave.tuning.amplitude) < 0.001)
        #expect(abs(wave.amplitude(at: 1) - wave.tuning.amplitude * 0.2) < 0.001)
        for step in 0...20 {
            #expect(wave.amplitude(at: Double(step) / 20) >= 0)
        }
        #expect(wave.amplitude(at: 0.5) < wave.amplitude(at: 0))
    }

    @Test("Completion flips exactly at the end")
    func completion() {
        let wave = Self.wave
        #expect(wave.isComplete(at: 0) == false)
        #expect(wave.isComplete(at: 0.999) == false)
        #expect(wave.isComplete(at: 1) == true)
    }

    @Test("Tuning is carried through")
    func tuningIsStored() {
        let tuning = RippleWave.Tuning(duration: 2, bandWidth: 50, amplitude: 10, highlight: 0.1)
        let wave = RippleWave(origin: .zero, in: Self.size, tuning: tuning)
        #expect(wave.tuning == tuning)
        #expect(abs(wave.progress(elapsed: 1) - 0.5) < 0.001)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run (from `NOVA/`):
```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test -only-testing:NOVATests/RippleWaveTests 2>&1 | grep -E "error:|TEST (SUCCEEDED|FAILED)" | head
```
Expected: compile errors — `cannot find 'RippleWave' in scope` — and `** TEST FAILED **`.

- [ ] **Step 3: Write the implementation**

```swift
//
//  RippleWave.swift
//  NOVA
//

import CoreGraphics
import Foundation

/// The geometry and timing of one drop: where it landed, how far the ring has to travel
/// to clear the screen, and how the ring's size and strength change over its life.
///
/// Plain maths with no SwiftUI, so the feel can be tuned and tested. The shader that
/// draws it and the view that drives it both read from here.
struct RippleWave: Equatable, Sendable {

    /// The knobs that decide how the water feels. Defaults were settled in the
    /// tuning preview; change them there first, then here.
    struct Tuning: Equatable, Sendable {
        /// How long the ring takes to clear the screen.
        var duration: Double = 0.9
        /// Thickness of the distorting band, in points.
        var bandWidth: CGFloat = 110
        /// How far a pixel inside the band is pulled toward the drop, in points, at the start.
        var amplitude: CGFloat = 26
        /// Strength of the white glow riding the wavefront, 0 to 1.
        var highlight: Double = 0.35
    }

    /// Where the drop landed, in the rippled layer's coordinate space.
    let origin: CGPoint
    /// Distance from the origin to the farthest corner of the layer.
    let reach: CGFloat
    let tuning: Tuning

    init(origin: CGPoint, in size: CGSize, tuning: Tuning = Tuning()) {
        self.origin = origin
        self.tuning = tuning
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        self.reach = corners.map { hypot($0.x - origin.x, $0.y - origin.y) }.max() ?? 0
    }

    /// Share of the ring's life that has passed, from 0 to 1.
    func progress(elapsed: TimeInterval) -> Double {
        guard tuning.duration > 0 else { return 1 }
        return min(max(elapsed / tuning.duration, 0), 1)
    }

    /// Radius of the ring's centre line. Eases out so the ring leaves the drop fast and
    /// slows as it spreads, the way a real ripple loses pace. Ends with the band's far
    /// edge past the farthest corner, so nothing is left mid-bend when the view moves on.
    func radius(at progress: Double) -> CGFloat {
        let p = min(max(progress, 0), 1)
        let eased = 1 - (1 - p) * (1 - p)
        return (reach + tuning.bandWidth) * CGFloat(eased)
    }

    /// How hard the band bends the picture at this moment. Fades to a fifth of its
    /// starting strength so the ring softens as it grows, rather than snapping off.
    func amplitude(at progress: Double) -> CGFloat {
        let p = min(max(progress, 0), 1)
        return tuning.amplitude * CGFloat(1 - 0.8 * p)
    }

    func isComplete(at progress: Double) -> Bool {
        progress >= 1
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run (from `NOVA/`):
```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|Test run with|TEST (SUCCEEDED|FAILED)" | tail -3
```
Expected: `Test run with 40 tests in 5 suites passed` and `** TEST SUCCEEDED **`.

- [ ] **Step 5: Commit**

```bash
git add NOVA/NOVA/Features/Welcome/RippleWave.swift NOVA/NOVATests/RippleWaveTests.swift
git commit -F - <<'EOF'
Add RippleWave: the timing and geometry of one drop

Plain maths for the welcome screen's ripple, kept out of the view so the
feel can be tuned and tested. The ring eases out and its bend fades as it
spreads.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 2: The Metal layer effect

**Files:**
- Create: `NOVA/NOVA/Features/Welcome/Ripple.metal`
- Create: `NOVA/NOVA/Features/Welcome/RippleWave+Shader.swift`

**Interfaces:**
- Consumes: `RippleWave` (Task 1) — `origin`, `radius(at:)`, `amplitude(at:)`, `tuning.bandWidth`, `tuning.highlight`.
- Produces:
  ```swift
  extension RippleWave {
      /// The shader for this moment of the ring, ready for `.layerEffect`.
      func shader(at progress: Double) -> Shader
      /// How far the shader may sample from a pixel, for `maxSampleOffset`.
      var maxSampleOffset: CGSize
  }
  ```
  Metal entry point: `ripple(float2 position, SwiftUI::Layer layer, float2 origin, float radius, float bandWidth, float amplitude, float highlight)`.

- [ ] **Step 1: Write the shader**

```metal
//
//  Ripple.metal
//  NOVA
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// One ring of water passing over the layer.
///
/// Inside a band of `bandWidth` centred on `radius` from `origin`, each pixel samples the
/// layer from a point pulled toward the origin — that is the bend — and is lightened by a
/// glow that peaks on the ring's centre line. Outside the band the layer is untouched, so
/// text ahead of and behind the ring stays crisp.
///
/// `position` and `origin` are in the layer's own points. The caller sets
/// `maxSampleOffset` to at least `amplitude` so the displaced samples are available.
[[ stitchable ]] half4 ripple(float2 position,
                              SwiftUI::Layer layer,
                              float2 origin,
                              float radius,
                              float bandWidth,
                              float amplitude,
                              float highlight) {
    float d = distance(position, origin);
    // -1 at the band's inner edge, 0 on the ring, +1 at the outer edge.
    float x = (d - radius) / bandWidth;

    if (abs(x) >= 1.0 || d < 0.5) {
        return layer.sample(position);
    }

    // Peaks on the ring, zero at both edges, so the band has no hard border.
    float falloff = 1.0 - abs(x);
    float2 towardOrigin = (origin - position) / d;
    float shift = amplitude * sin(x * M_PI_F) * falloff;

    half4 color = layer.sample(position + towardOrigin * shift);

    // The layer is opaque (its background is inside it), so a straight mix toward
    // white reads as a highlight rather than a haze.
    half glow = half(highlight * falloff * falloff);
    color.rgb = mix(color.rgb, half3(1.0h), glow * color.a);
    return color;
}
```

- [ ] **Step 2: Write the Swift bridge**

```swift
//
//  RippleWave+Shader.swift
//  NOVA
//

import SwiftUI

extension RippleWave {
    /// The `ripple` layer effect for this moment of the ring.
    func shader(at progress: Double) -> Shader {
        ShaderLibrary.ripple(
            .float2(origin),
            .float(radius(at: progress)),
            .float(tuning.bandWidth),
            .float(amplitude(at: progress)),
            .float(tuning.highlight)
        )
    }

    /// The shader pulls samples up to `amplitude` points toward the origin, so the
    /// layer has to be rendered with at least that much slack on every side.
    var maxSampleOffset: CGSize {
        CGSize(width: tuning.amplitude, height: tuning.amplitude)
    }
}
```

- [ ] **Step 3: Build to verify the shader compiles**

Run (from `NOVA/`):
```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|warning: .*metal|BUILD (SUCCEEDED|FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **` with no Metal errors. If the compiler cannot find `SwiftUI/SwiftUI.h`, the file is not in the app target — confirm it sits under `NOVA/NOVA/Features/Welcome/`.

- [ ] **Step 4: Run the tests to confirm nothing regressed**

```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)" | tail -2
```
Expected: 40 tests pass.

- [ ] **Step 5: Commit**

```bash
git add NOVA/NOVA/Features/Welcome/Ripple.metal "NOVA/NOVA/Features/Welcome/RippleWave+Shader.swift"
git commit -F - <<'EOF'
Add the ripple layer effect

A Metal layer effect that bends and lightens the layer inside one ring, plus
the bridge that builds it from a RippleWave for a given moment.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 3: `WelcomeView` layout and the first-launch gate

The screen without motion yet: the type, the CTA, and `RootView` showing it on first launch. Tapping the button crossfades straight to the reader for now; Task 4 puts the ripple in front of that.

**Files:**
- Create: `NOVA/NOVA/Features/Welcome/WelcomeView.swift`
- Modify: `NOVA/NOVA/App/RootView.swift`

**Interfaces:**
- Consumes: `Nova.accent`, `Nova.screenPadding`, `Nova.readingMaxWidth` (`DesignSystem/NovaTheme.swift`), `RippleWave.Tuning` (Task 1).
- Produces:
  ```swift
  struct WelcomeView: View {
      var tuning: RippleWave.Tuning = RippleWave.Tuning()
      let onFinished: () -> Void
  }
  ```
  `RootView` gains `@AppStorage("hasSeenWelcome") private var hasSeenWelcome = false`.

- [ ] **Step 1: Write `WelcomeView` (static)**

```swift
//
//  WelcomeView.swift
//  NOVA
//

import SwiftUI

/// The first thing a new reader sees. One sentence, one size, one weight, two colours.
///
/// The screen is paper, not the reader's gradient: it should feel still, so the ripple
/// that follows the tap has something to disturb. The button is the drop point.
struct WelcomeView: View {
    var tuning = RippleWave.Tuning()
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isLeaving = false

    var body: some View {
        page
            .safeAreaBar(edge: .bottom) { callToAction }
            .background(backdrop.ignoresSafeArea())
    }

    // MARK: - Pieces

    /// Wordmark and copy. This is the layer the ripple runs over in Task 4.
    private var page: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("NOVA", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            copy
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .tracking(-0.8)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Two colours do all the work: the words that carry the sentence in `.primary`,
    /// the connective tissue in `.secondary`. No bold, no size change.
    private var copy: Text {
        Text("Know").foregroundStyle(.primary)
        + Text(" the world and ").foregroundStyle(.secondary)
        + Text("local").foregroundStyle(.primary)
        + Text(" updates quick and smooth ").foregroundStyle(.secondary)
        + Text("like water").foregroundStyle(.primary)
        + Text(".").foregroundStyle(.secondary)
    }

    private var callToAction: some View {
        Button("Get started") {
            leave()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .disabled(isLeaving)
    }

    /// Near-white with a breath of the accent at the top. Inside the rippled layer so the
    /// shader always samples an opaque pixel.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.background)
            LinearGradient(
                colors: [Nova.accent.opacity(0.07), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
        }
    }

    // MARK: - Leaving

    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        onFinished()
    }
}

#Preview("Welcome") {
    WelcomeView { }
        .tint(Nova.accent)
}
```

- [ ] **Step 2: Gate it in `RootView`**

Replace the whole `body` of `RootView` (currently the `NavigationStack` with `.environment` modifiers) with:

```swift
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false

    var body: some View {
        ZStack {
            NavigationStack(path: $router.path) {
                StoryReaderView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .quizIntro:
                            QuizIntroView()
                        case .quiz:
                            QuizView()
                        case .results:
                            ResultsView()
                        }
                    }
            }

            // Not a route: like the reader it isn't navigated to, and nothing may swipe
            // back into it. It sits over the stack until the ripple has finished.
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenWelcome = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(session)
        .environment(router)
        .environment(sound)
        .tint(Nova.accent)
    }
```

Place the `@AppStorage` line with the other `@State` properties at the top of `RootView`.

- [ ] **Step 3: Build and run on the simulator**

From `NOVA/`:
```bash
SIM=$(xcrun simctl list devices available | grep "iPhone 17 Pro (" | grep -oE "[0-9A-F-]{36}")
xcrun simctl boot "$SIM" 2>/dev/null; open -a Simulator
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination "id=$SIM" -derivedDataPath /tmp/nova-dd build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -3
xcrun simctl install "$SIM" /tmp/nova-dd/Build/Products/Debug-iphonesimulator/NOVA.app
# `-hasSeenWelcome NO` overrides the stored flag for this launch, so the screen shows even after it has been dismissed once.
xcrun simctl launch "$SIM" com.iosnewsapp.NOVA -hasSeenWelcome NO
sleep 2; xcrun simctl io "$SIM" screenshot /tmp/welcome-light.png
```
Expected: `** BUILD SUCCEEDED **`. Open `/tmp/welcome-light.png` and check: "NOVA" wordmark top-left; the sentence in large semibold type with **Know**, **local**, **like water** dark and the rest grey; a single accent-coloured "Get started" pill at the bottom; no navigation bar, no story visible.

- [ ] **Step 4: Check dark mode and the handoff**

```bash
xcrun simctl ui "$SIM" appearance dark
sleep 1; xcrun simctl io "$SIM" screenshot /tmp/welcome-dark.png
xcrun simctl ui "$SIM" appearance light
```
Expected: dark background, light text, the same two-tone hierarchy. Then tap "Get started" in the Simulator window by hand: the welcome fades out over ~0.35 s and the story reader is underneath. Relaunch **without** the override (`xcrun simctl launch "$SIM" com.iosnewsapp.NOVA`) and confirm the reader opens directly.

- [ ] **Step 5: Run the tests**

```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination "id=$SIM" test 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)" | tail -2
```
Expected: 40 tests pass.

- [ ] **Step 6: Commit**

```bash
git add NOVA/NOVA/Features/Welcome/WelcomeView.swift NOVA/NOVA/App/RootView.swift
git commit -F - <<'EOF'
Add the welcome screen and show it on first launch

One sentence in two colours over paper, with a single Get started button.
RootView overlays it on the reader until a stored flag says it has been
seen, then crossfades it away. It is not a route, so it cannot be swiped
back into.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 4: Drive the ripple from the button

**Files:**
- Modify: `NOVA/NOVA/Features/Welcome/WelcomeView.swift`

**Interfaces:**
- Consumes: `RippleWave` (Task 1), `RippleWave.shader(at:)` and `.maxSampleOffset` (Task 2).
- Produces: the same public `WelcomeView(tuning:onFinished:)`; internally a `drop(from:)` method and a `TimelineView`-driven layer effect. A `DEBUG`-only launch argument `-welcomeAutoDrop YES` fires the drop one second after appear, for automated visual checks.

- [ ] **Step 1: Replace `WelcomeView.swift` with the animated version**

```swift
//
//  WelcomeView.swift
//  NOVA
//

import SwiftUI

/// The first thing a new reader sees. One sentence, one size, one weight, two colours.
///
/// The screen is paper, not the reader's gradient: it should feel still, so the ripple
/// that follows the tap has something to disturb. The button is the drop point: tap it
/// and a ring of refraction runs up through the page, then the page gives way.
struct WelcomeView: View {
    var tuning = RippleWave.Tuning()
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The ring in flight, and when it started. Nil until the button is tapped.
    @State private var wave: RippleWave?
    @State private var dropTime: Date?
    @State private var isLeaving = false
    /// Frames in global space, so the button's centre can be expressed in the layer's
    /// own coordinates. The layer ignores the safe area and the bar does not, so the
    /// two do not share an origin.
    @State private var layerFrame: CGRect = .zero
    @State private var buttonCentre: CGPoint = .zero

    var body: some View {
        TimelineView(.animation(paused: wave == nil)) { timeline in
            let progress = wave.map { $0.progress(elapsed: timeline.date.timeIntervalSince(dropTime ?? timeline.date)) } ?? 0
            rippledPage(progress: progress)
        }
        .safeAreaBar(edge: .bottom) { callToAction }
        .sensoryFeedback(.impact(weight: .light), trigger: dropTime)
        #if DEBUG
        .task { await autoDropIfAsked() }
        #endif
    }

    // MARK: - Pieces

    /// The page with the ring over it. `isEnabled` keeps the shader entirely out of the
    /// pipeline while nothing is rippling.
    private func rippledPage(progress: Double) -> some View {
        page
            .background(backdrop)
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { layerFrame = $0 }
            .layerEffect(
                wave?.shader(at: progress) ?? RippleWave(origin: .zero, in: .zero).shader(at: 0),
                maxSampleOffset: wave?.maxSampleOffset ?? .zero,
                isEnabled: wave != nil
            )
    }

    /// Wordmark and copy.
    private var page: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("NOVA", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            copy
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .tracking(-0.8)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .safeAreaPadding()
    }

    /// Two colours do all the work: the words that carry the sentence in `.primary`,
    /// the connective tissue in `.secondary`. No bold, no size change.
    private var copy: Text {
        Text("Know").foregroundStyle(.primary)
        + Text(" the world and ").foregroundStyle(.secondary)
        + Text("local").foregroundStyle(.primary)
        + Text(" updates quick and smooth ").foregroundStyle(.secondary)
        + Text("like water").foregroundStyle(.primary)
        + Text(".").foregroundStyle(.secondary)
    }

    private var callToAction: some View {
        Button("Get started") {
            drop()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).center } action: { buttonCentre = $0 }
        .disabled(isLeaving)
    }

    /// Near-white with a breath of the accent at the top. Inside the rippled layer so the
    /// shader always samples an opaque pixel.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.background)
            LinearGradient(
                colors: [Nova.accent.opacity(0.07), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
        }
    }

    // MARK: - The drop

    /// Starts the ring from the button, then hands over once it has cleared the screen.
    /// With Reduce Motion on there is no ring: the page simply gives way.
    private func drop() {
        guard !isLeaving else { return }
        isLeaving = true

        guard !reduceMotion else {
            onFinished()
            return
        }

        let origin = CGPoint(
            x: buttonCentre.x - layerFrame.minX,
            y: buttonCentre.y - layerFrame.minY
        )
        wave = RippleWave(origin: origin, in: layerFrame.size, tuning: tuning)
        dropTime = .now

        Task {
            try? await Task.sleep(for: .seconds(tuning.duration))
            onFinished()
        }
    }

    #if DEBUG
    /// `xcrun simctl launch … -welcomeAutoDrop YES` taps the button for us a second after
    /// the screen appears, so the ripple can be recorded without a finger.
    private func autoDropIfAsked() async {
        guard UserDefaults.standard.bool(forKey: "welcomeAutoDrop") else { return }
        try? await Task.sleep(for: .seconds(1))
        drop()
    }
    #endif
}

// MARK: - Previews

#Preview("Welcome") {
    WelcomeView { }
        .tint(Nova.accent)
}

/// Drag until the water feels right, then move the numbers into `RippleWave.Tuning`.
#Preview("Tuning") {
    @Previewable @State var duration = 0.9
    @Previewable @State var bandWidth: CGFloat = 110
    @Previewable @State var amplitude: CGFloat = 26
    @Previewable @State var highlight = 0.35
    @Previewable @State var generation = 0

    VStack(spacing: 0) {
        WelcomeView(
            tuning: RippleWave.Tuning(
                duration: duration,
                bandWidth: bandWidth,
                amplitude: amplitude,
                highlight: highlight
            )
        ) {
            // Bring the screen back so the drop can be tried again.
            generation += 1
        }
        .id(generation)
        .tint(Nova.accent)

        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Duration \(duration, format: .number.precision(.fractionLength(2))) s")
                Slider(value: $duration, in: 0.3...2.0)
            }
            GridRow {
                Text("Band \(Int(bandWidth)) pt")
                Slider(value: $bandWidth, in: 30...260)
            }
            GridRow {
                Text("Bend \(Int(amplitude)) pt")
                Slider(value: $amplitude, in: 0...60)
            }
            GridRow {
                Text("Glow \(highlight, format: .number.precision(.fractionLength(2)))")
                Slider(value: $highlight, in: 0...1)
            }
        }
        .font(.caption.monospacedDigit())
        .padding()
        .background(.background.secondary)
    }
}
```

- [ ] **Step 2: Build**

From `NOVA/` (reuse `SIM` from Task 3):
```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination "id=$SIM" -derivedDataPath /tmp/nova-dd build 2>&1 | grep -E "error:|BUILD (SUCCEEDED|FAILED)" | tail -5
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 3: Record the ripple on the simulator**

```bash
xcrun simctl install "$SIM" /tmp/nova-dd/Build/Products/Debug-iphonesimulator/NOVA.app
xcrun simctl terminate "$SIM" com.iosnewsapp.NOVA 2>/dev/null
xcrun simctl io "$SIM" recordVideo --codec h264 --force /tmp/ripple.mp4 &
REC=$!
sleep 1
xcrun simctl launch "$SIM" com.iosnewsapp.NOVA -hasSeenWelcome NO -welcomeAutoDrop YES
sleep 4
kill -INT $REC; wait $REC 2>/dev/null
```

Then extract frames. Save this as `/tmp/frames.swift`, compile once, and run it:

```swift
import AVFoundation
import AppKit

// usage: frames <video> <outPrefix> <count> [width]
let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let prefix = args[2], count = Int(args[3]) ?? 1
let width = args.count > 4 ? CGFloat(Double(args[4]) ?? 400) : 400
let gen = AVAssetImageGenerator(asset: asset)
gen.appliesPreferredTrackTransform = true
gen.requestedTimeToleranceBefore = .zero
gen.requestedTimeToleranceAfter = .zero
gen.maximumSize = CGSize(width: width, height: width * 3)
let sem = DispatchSemaphore(value: 0)
Task {
    let duration = try await asset.load(.duration).seconds
    for i in 0..<count {
        let t = count == 1 ? 0 : duration * Double(i) / Double(count - 1) * 0.999
        if let (cg, actual) = try? await gen.image(at: CMTime(seconds: t, preferredTimescale: 600)) {
            let data = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])!
            try? data.write(to: URL(fileURLWithPath: String(format: "%@_%02d_%.2fs.png", prefix, i, actual.seconds)))
        }
    }
    sem.signal()
}
sem.wait()
```

```bash
swiftc -O /tmp/frames.swift -o /tmp/frames 2>/dev/null
/tmp/frames /tmp/ripple.mp4 /tmp/rip 30 300
ls /tmp/rip_*.png | wc -l
```

Expected: 30 PNGs. Open the ones between roughly 1.0 s and 2.0 s. Check, against the Brink reference (`docs/superpowers/specs/…` describes it): a band of **bent** text with a soft white glow travels **upward from the button**; text ahead of and behind the band is crisp; the band has softened by the time it reaches the top; then the whole screen crossfades to the reader. Nothing should pop, and the button must not be bent (it is outside the layer).

If the ring starts from the wrong place, the origin conversion in `drop()` is off: log `layerFrame` and `buttonCentre` and confirm `origin` lands on the button in layer points.

- [ ] **Step 4: Run the tests**

```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination "id=$SIM" test 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)" | tail -2
```
Expected: 40 tests pass.

- [ ] **Step 5: Commit**

```bash
git add NOVA/NOVA/Features/Welcome/WelcomeView.swift
git commit -F - <<'EOF'
Run the ripple from the Get started button

Tapping the button drops a RippleWave at its centre; a TimelineView feeds
the elapsed time to the layer effect until the ring has cleared the screen,
then the parent crossfades. Reduce Motion skips the ring. A tuning preview
exposes the four knobs, and a DEBUG launch argument fires the drop for
recordings.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```

---

### Task 5: Reduce Motion check, docs, and wrap-up

**Files:**
- Modify: `CLAUDE.md` (Architecture section)
- Modify: `docs/superpowers/specs/2026-09-20-welcome-ripple-design.md` (one line, only if Task 4's layout differs from the spec)

- [ ] **Step 1: Verify Reduce Motion on the simulator**

```bash
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility ReduceMotionEnabled -bool true
xcrun simctl terminate "$SIM" com.iosnewsapp.NOVA 2>/dev/null
xcrun simctl launch "$SIM" com.iosnewsapp.NOVA -hasSeenWelcome NO -welcomeAutoDrop YES
sleep 2.5; xcrun simctl io "$SIM" screenshot /tmp/reduce-motion.png
xcrun simctl spawn "$SIM" defaults write com.apple.Accessibility ReduceMotionEnabled -bool false
```
Expected: at 2.5 s (1 s auto-drop + 0.35 s fade, plus margin) the screenshot shows the **story reader**, and at no point was a ring drawn. If the welcome screen is still showing, `reduceMotion` is not being read — check the `@Environment(\.accessibilityReduceMotion)` line.

- [ ] **Step 2: Note the new pieces in `CLAUDE.md`**

Add this bullet block to the **Architecture** section of `CLAUDE.md`, after the **Navigation** block:

```markdown
**Welcome (`Features/Welcome/`)**
- `WelcomeView` is overlaid by `RootView` while `@AppStorage("hasSeenWelcome")` is false.
  Not a route. Launch with `-hasSeenWelcome NO` to see it again; `-welcomeAutoDrop YES`
  (DEBUG only) taps the button for you after a second, for recordings.
- The ripple is `RippleWave` (maths, tested) + `Ripple.metal` (a `layerEffect`) + a
  `TimelineView` driver in the view. Tune the feel in the "Tuning" preview, then move
  the numbers into `RippleWave.Tuning`.
```

- [ ] **Step 3: Reconcile the spec with what shipped**

Two places where what shipped differs from the spec, on purpose:

1. The spec says the wordmark stays still; in Task 4 the wordmark sits inside the rippled layer (the whole page is water, only the button stays still — this matches the Brink frames better). Update the spec's Ripple section sentence to:

```
Applied with `.layerEffect(…, maxSampleOffset:)` on the page layer — the button stays still.
```

2. The spec names `Nova.display(.largeTitle)` (bold). Brink's type is one medium weight, and bold at that size shouts, so the view uses `.system(.largeTitle, weight: .semibold)`. Update the spec's Screen section to:

```
- One text block in `.system(.largeTitle, weight: .semibold)` — same size, same weight throughout.
```

- [ ] **Step 4: Full test run and a clean tree**

```bash
xcodebuild -project NOVA.xcodeproj -scheme NOVA -destination "id=$SIM" test 2>&1 | grep -E "Test run with|TEST (SUCCEEDED|FAILED)" | tail -2
git status --short
```
Expected: 40 tests pass; only `CLAUDE.md` and the spec are modified.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md docs/superpowers/specs/2026-09-20-welcome-ripple-design.md
git commit -F - <<'EOF'
Document the welcome screen and its launch arguments

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
EOF
```
