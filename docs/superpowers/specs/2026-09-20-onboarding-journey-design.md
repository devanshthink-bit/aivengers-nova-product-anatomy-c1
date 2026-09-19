# Onboarding journey

Five pages between first launch and the reader, with the ripple carrying each one to the
next so the water becomes the flow's transition rather than a single flourish.

## Research

Five iOS onboardings were read frame by frame on Mobbin before this was designed.

| App | Shape | Taken | Rejected |
|---|---|---|---|
| Brink | 12 steps: splash → auth → manifesto → 2 feature tours → name/age → topics | The typographic manifesto, the ripple, and a stated minimum ("Pick 3 to start") | The auth wall before any value is shown |
| NYTimes | "Step 1 of 2" → interests → review pre-checked suggestions | An explicit step counter; suggest-then-refine over ask-from-zero | Listy and toneless |
| Yahoo News | "Select 5 or more topics", chips grouped by theme | Grouping and an unambiguous minimum | Stock chips and a stock purple button |
| (Not Boring) | Black screen, a blinking face, a small SKIP | Personality costs almost no friction | Says nothing about the app |
| Evernote | Progress bar → "Personalizing… 40 %" + testimonial → paywall | A progress indicator sets expectations | The fake computation. It manufactures investment; we are not doing that. |

Every one of them sells personalisation. None sells a ritual or a game, which is what NOVA
actually has. The journey below sells the loop first and personalises second.

## The five pages

1. **Manifesto** — "Know the world and local updates quick and smooth like water."
   Unchanged from the first build. CTA "Get started".
2. **Ritual** — "Five stories. Five shots. Every day." Three rows: Read, Play, Know.
   This is the daily loop, stated before anything is asked of the reader. CTA "Sounds good".
3. **Name** — "What should we call you?" One field. Empty is allowed: the CTA reads
   "Skip for now" until something is typed, then "Continue". No dead end.
4. **Topics** — "What do you want first?" The five real `StoryCategory` values with their
   existing tints and symbols. At least two. CTA disabled below the minimum.
5. **Ready** — "Your first five are waiting, <name>." CTA "Start reading", and the last
   ripple hands over to the reader.

## What the answers do

- **Name** is stored and used on page 5 and on the results screen. Nothing else.
- **Topics reorder the deck; they do not filter it.** `MockNewsService` ships exactly five
  stories, one per category, and the round needs all five, so filtering would break the
  game. Chosen categories sort to the front, everything else keeps its order behind them.
  The copy says "We'll lead with these. You'll still see everything." — which is true.

## Visual language

Type does everything. A headline large enough to fill the width needs no container to give
it weight, so there are no cards, no bezels and no borders anywhere in the flow — every box
removed is more air for the water to move through.

Direction taken from Neuecast and Brink: enormous bold type on a flat grey ground, colour
rather than weight carrying emphasis, saturated fills for anything chosen, and one
unmissable black button that means "go".

- **Ground** `systemGroupedBackground` — flat, slightly warm, never white. Black type sits
  on it without glaring, and the ripple's highlight has somewhere to lift from.
- **Headline** 36 pt bold, tracking −1.1. Past that size the sentences start stranding
  single words on the last line.
- **Two colours only.** `.primary` for the words that carry the sentence, `.secondary` for
  the connective tissue. No bold, no size change, no third colour.
- **Surfaces recede.** Unselected tiles and the name field are `tertiarySystemFill`, a
  shade *darker* than the ground, so a chosen tile is the only thing on the page.
- **Chosen tiles flood** with the category's own colour, grow a white tick in a circle, and
  lift on a shadow in that same colour.
- **The button** is full width, `.primary`-filled — not literal black, so it inverts to
  white on a dark ground instead of disappearing into it. Disabled it goes quiet and grey,
  and its label says what is still missing ("Pick 2 more") rather than leaving a dead
  control with no explanation.
- **Chrome is one line:** "01 / 05" in the top corner, monospaced and tertiary. No
  wordmark, no progress bar.
- **Entry** is staggered — each element fades up 18 pt out of a 5 pt blur, 75 ms apart, on
  a `.smooth` curve. Nothing appears statically. Skipped under Reduce Motion.

## Ripple between pages

Two presets on `RippleWave.Tuning`:

- `.page` — 0.7 s, band 96, bend 22, glow 0.30. Quick enough to read as a page turn.
- `.finale` — 0.95 s, band 120, bend 28, glow 0.38. The last drop, into the reader.

The page swaps at 45 % of the ripple, behind the wavefront, so the water reveals the next
page rather than the page changing after the water has gone. Under Reduce Motion there is
no ring: pages crossfade.

## Restarting, for testing

A DEBUG-only capsule pinned top-left of `RootView`, above everything including the
onboarding overlay — the full-width button now owns the bottom edge, so the corner opposite
the step marker is the only one that never collides with content — that clears the name, the topics and the seen flag and returns to page
one. It replaces the `-hasSeenWelcome NO` launch argument, which could never be combined
with `-welcomeAutoDrop YES` because an argument-domain override masks the write.

## Files

New under `NOVA/NOVA/Features/Onboarding/`: `OnboardingPage.swift`, `TopicSelection.swift`,
`OnboardingStyle.swift`, `OnboardingFlow.swift`, `DebugRestartButton.swift`, and
`Pages/{Manifesto,Ritual,Name,Topics,Ready}Page.swift`.
Changed: `App/RootView.swift`, `GameLogic/DailySession.swift`, `Features/Welcome/` folds
into `Features/Onboarding/`.
Tests: `NOVATests/OnboardingTests.swift` covers `TopicSelection` encoding and the minimum,
and the story ordering.
