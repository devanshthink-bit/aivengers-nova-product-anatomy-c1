# Product

<!-- impeccable:product-schema 1 -->

## Platform

ios

## Users
Readers who want to keep up with the news in a few minutes a day and actually remember it —
in English or Hindi — including competitive-exam aspirants (UPSC, SSC, banking) for whom
current affairs is a syllabus, not a pastime.
Categories (India, Technology, Business, World, Science) and the Indian publishers in the
feed list point at an India-based reader following both local and world news.
_Inferred from the repository; not confirmed in an interview._

## Product Purpose
NOVA is a daily news ritual: read five stories as a swipeable deck, then answer one
question per story by slingshotting a paper ball into the hoop that holds your answer.
Success is a reader who comes back tomorrow and holds on to what they read.

## Positioning
Every news app sells personalisation. NOVA's shape — read five, then play five — turns
comprehension into a game, so reading has a finish line and a score.

## Operating Context
A short session, usually on a phone, often in transit or first thing in the morning. One
round a day today; the day is designed to hold several rounds later.

## Capabilities and Constraints
- Live RSS from English and Hindi publisher feeds across seven categories (India, World,
  Sports, Business, Technology, Entertainment, Science); no API keys.
- Hindi throughout: Hindi feeds and questions by choice, and a Hindi UI via iOS's per-app language.
- Every answer is kept on the device for revision in the Prep tab; rounds and questions share
  as images and text; an optional local daily reminder.
- Everything free: no keys, accounts, paid services or push server.
- Card summaries and quiz questions are machine-generated from the feed via an unofficial
  endpoint, with a fallback to the feed's own summary and no question.
- Multiplatform target (iOS, macOS, visionOS); iOS-only APIs must be wrapped.
- Honour Reduce Motion, Reduce Transparency and VoiceOver; the quiz has a tap-to-shoot path.

## Brand Commitments
- Name: NOVA.
- Visual direction chosen by the user (2026-09-27): a blend of Artifact (paper reading
  surfaces, publisher metadata line, pixel-mosaic motif), (Not Boring) Habits (charcoal
  play surfaces, one focal object per screen, condensed caps with mono, a single marigold
  achievement accent, colour floods, ribbon rewards, week-strip rail) and an editorial
  serif for reading.

## Evidence on Hand
- Publisher logos for six sources in `NOVA/NOVA/Assets.xcassets` (monograms stand in for the rest).
- No testimonials, user counts or press. "Reads" counts like Artifact's do not exist and
  must not be invented.

## Product Principles
1. Reading comes first; the game rewards it and never replaces it.
2. Generated text is labelled as generated — never presented as verified reporting.
3. Every interaction works without the gesture.
4. Progress is honest: nothing counts that the reader did not do.

## Accessibility & Inclusion
Dynamic Type, Reduce Motion, Reduce Transparency, VoiceOver parity for the shot, and
colour never as the only cue (answer letters carry meaning).
