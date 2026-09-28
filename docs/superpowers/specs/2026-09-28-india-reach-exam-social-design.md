# India reach, exam prep and sharing — design

Date: 2026-09-28 · Branch: `feat/india-reach-exam-social`

## Intent

**What the user asked for.** Implement the gap-analysis ranking for Indian readers, one item
after another, on one branch: (1) language, Hindi first; (2) daily reminders and WhatsApp-style
sharing; (3) more categories, cricket and markets especially; (4) exam prep. Research Indian RSS
feeds and add the ones that hold up. Exam prep and social are the parts the user is most keen on.

**Assumptions (correct these).**
- "Language" means *two* things: the news itself in Hindi, and the app's own words in Hindi.
  Regional languages (Tamil, Bengali, Marathi, Telugu) are out of scope for this branch.
- Rank 5 (Android, a shared backend) is a strategic decision, not a feature, and is not built.
- Anything that needs a server — groups, leaderboards, a tappable challenge link — is out.
  WhatsApp only linkifies `http(s)`, and the project has no domain for universal links, so a
  `nova://` challenge link would arrive as dead text. Sharing is therefore images and plain text.

**Success looks like.**
- A reader who picks Hindi gets a Hindi deck, Hindi summaries and Hindi questions, and sees the
  app's chrome in Hindi when the phone (or NOVA's per-app setting) is Hindi.
- Cricket and Bollywood stories reach the deck and Home; India, business and tech carry
  Indian sources.
- Every question a reader answers is kept, and a Prep tab lets them revise — wrong ones first —
  and read back the week as a revision sheet.
- Finishing a round offers a shareable scorecard image and a Wordle-style text grid, and a
  single question can be shared as a "can you answer this?" card.
- A reader can turn on one daily reminder at a time they choose.
- The existing rules still hold: generated text is labelled as generated, progress is honest,
  every interaction works without the gesture, and the fallback path with no AI still works.

## 1. Feeds and categories

### New categories

`StoryCategory` gains `.sports` and `.entertainment` (seven in total). Each needs a title, an SF
Symbol (`cricket.ball` / `film`) and a tint in `NovaTheme.swift` drawn from the mosaic family
(fills only, as today). `TopicSelection`, the topics page, Profile chips and `FlowChips` already
iterate `allCases`, so they pick the new ones up; the topics page layout is checked at seven.

### Picking five from seven

`LiveNewsService.pick` currently takes the newest story per category until it has five. With
seven categories that would let whichever two categories published last drop out at random, and
could drop a category the reader chose. New rule: **categories the reader chose are filled first,
then the rest by recency**, still one per category, still topped up when fewer categories came
back. The deck still never *filters* — the reader chose what leads, not what exists — and
`leading(with:)` still orders the result. `pick` takes the `TopicSelection` as a parameter
(defaulting to empty, so today's tests keep their meaning).

### Feeds added (all checked 2026-09-28: HTTP 200, XML items, images on nearly every item)

English:

| Source | Category | URL |
|---|---|---|
| Indian Express | India | `indianexpress.com/section/india/feed/` |
| The Hindu Cricket | Sports | `thehindu.com/sport/cricket/feeder/default.rss` |
| Indian Express Sports | Sports | `indianexpress.com/section/sports/feed/` |
| The Hindu Entertainment | Entertainment | `thehindu.com/entertainment/feeder/default.rss` |
| Bollywood Hungama | Entertainment | `bollywoodhungama.com/rss/news.xml` |
| Business Standard Markets | Business | `business-standard.com/rss/markets-106.rss` |
| Inc42 | Technology | `inc42.com/feed/` |
| The Hindu Science | Science | `thehindu.com/sci-tech/science/feeder/default.rss` |

Hindi (each is a section feed, so the category is pure):

| Source | Categories |
|---|---|
| Live Hindustan (`api.livehindustan.com/feeds/rss/<section>/rssfeed.xml`) | national→India, international→World, cricket→Sports, business→Business, entertainment→Entertainment, gadgets→Technology |
| News18 Hindi (`hindi.news18.com/rss/khabar/<section>/<section>.xml`) | nation→India, world→World, sports→Sports, business→Business, entertainment→Entertainment, tech→Technology |
| Dainik Bhaskar (`bhaskar.com/rss-v1--category-<id>.xml`) | 1061→India, 1125→World, 1053→Sports, 1051→Business, 3998→Entertainment |

No Hindi science feed passed. A Hindi deck therefore runs on six categories and `pick`'s top-up
covers the gap — a known limit, not a bug.

Rejected, added to the comment block at the bottom of `RSSFeed.swift` so they don't return:
BBC Hindi (every section URL serves the same mixed feed), NDTV India and ABP Live Hindi (one
feed mixing politics, Bollywood and cricket), Aaj Tak, Amar Ujala, Moneycontrol and PIB (no
images), Jagran, Navbharat Times, Down To Earth and The Hindu explainers (404), ThePrint (HTML),
DD News (timed out), YourStory (personal-finance advice mixed into startup news), MediaNama (one
image in ten), IE Explained (mixes every category), ESPNcricinfo (mostly English county cricket,
little for an Indian reader). BBC Tamil, Bengali, Marathi and Telugu all work and are noted for
a later regional-language branch.

### Language on the feed

`RSSFeed` gains `language: ContentLanguage`. `FeedLoader` fetches only the reader's language,
so a Hindi reader doesn't pay for English feeds or the other way round. Home's source list
follows the same filter because it reads `NewsStore`, which uses `FeedLoader`.

### Parser check

Each new feed is fetched once and saved as a trimmed sample under `NOVATests`, and
`RSSParserTests` gains one case per new publisher (items parse, dates parse, an image is found).
Any feed that fails to parse is fixed in the parser or dropped — nothing ships unparsed.

## 2. Language

### Content language (in-app choice)

A new `ContentLanguage` enum (`en`, `hi`) in `Models/`, stored as `@AppStorage("contentLanguage")`.
Its default comes from the phone the same way `VoiceLanguage.preferred` works. It is chosen:
- in onboarding, on a new **language page** placed *first* — before the manifesto, because a
  Hindi reader shouldn't have to get through two English pages to find the switch. It shows
  two large tiles, "English" and "हिन्दी", in the onboarding style. `OnboardingPage` becomes six
  cases, and `OnboardingTests` and the `-onboardingPage N` numbering shift by one;
- in Profile, as a two-option row. Changing it reloads `NewsStore` and the day's deck.

`QuestionGenerator` takes the language. For Hindi, the system prompt tells the model to write
the summary, question and answers in Hindi (Devanagari) while keeping names, numbers and
abbreviations as the story gives them. The JSON keys stay English. `truncatedToWords` works
unchanged on Devanagari, since words are space-separated.

The voice panel's language default follows the content language, but the reader can still
switch it.

### App language (system choice)

UI strings move into a String Catalog, `NOVA/NOVA/Resources/Localizable.xcstrings`, with English
and Hindi entries, and `knownRegions` gains `hi`. That also makes iOS show NOVA's own
per-app Language setting in Settings. Profile links to it ("App language → Settings") instead
of building a second in-app switch. An in-app override would mean passing `\.locale` through
every view, and `String(localized:)` calls in non-view code wouldn't follow it.

What gets translated: every user-facing literal in views, the onboarding copy, the results and
Prep copy, and notification text. Literals that are currently computed `String`s passed to
`Text(_:)` (`headline`, `badge` and similar) become `String(localized:)` so they are extracted.
Publisher names, and the mono `novaMeta` labels that are brand chrome ("NOVA"), stay in English.
Hindi text is set in the system font. The editorial serif and the compressed poster face have no
Devanagari glyphs, so `Nova.reading`/`Nova.poster` fall back to the system font when the
resolved language is Hindi; otherwise the fallback font would be picked glyph by glyph.

## 3. Exam prep

### Keeping every answer

A new `QuestionArchive` in `GameLogic/` stores, for every submitted answer: the question
(prompt, answers, correct index, optional explanation), the story's title, source, category and
publish date, the day played, the chosen index and whether it was right. It is saved as JSON in
Application Support, capped at the most recent 1,000 entries. It is plain Foundation, has no
SwiftUI, and is tested with an injected file URL. `DailySession.submitAnswer` records into it, so
the rule "views never compute scores" still holds. Revision answers update the entry's "last
revised" state and never touch `PlayHistory` or the streak — a streak counts days the reader did
the daily round, and revision isn't that.

### Exam-style questions and explanations

`Question` gains `var explanation: String? = nil` (defaulted, so the existing memberwise uses
and Codable data still work). The generator prompt gains two rules: prefer factual questions an
exam would ask (who, which body, which scheme, where, how much), and add one sentence of
`"context"` — why the story matters — drawn only from the story. The model still must not invent
facts; the prompt says so and the explanation is shown with the same "machine-written" label as
the question. This is on for every reader rather than behind a toggle: questions that are about
facts are better questions for everyone, and a toggle would split the prompt into two to
maintain.

The explanation appears under each row in the results review and on the Prep answer screen.

### The Prep tab

A fourth tab, **Prep** (`graduationcap`), on paper, between Scroll and Profile:
- **Header:** total questions kept, overall accuracy, and accuracy per category as a row of
  category squares with percentages (ink text, tint fill — the existing badge rule).
- **Revise:** starts a revision round of up to ten archived questions, the ones got wrong first,
  then the ones revised least recently. It is answered by tapping one of the options — the
  paper, reading-side interaction, not the charcoal slingshot, since revision is study rather
  than the daily game. It uses the existing `RoundEngine`, so the scoring and the two-step
  feedback are the tested ones. After each answer it shows right/wrong, the correct answer, the
  explanation and the source line.
- **This week:** a revision sheet grouped by day — the question, the correct answer and the
  context — readable as a list. It can be shared as text, which is how exam aspirants pass
  notes around on WhatsApp.
- **Empty state:** before the first round, one line saying that answered questions collect here,
  and a button to go to today's deck.
- A standing footnote: "Questions are machine-written from news feeds and not checked. Verify
  before relying on them for an exam." This carries the generated-text principle into the one
  place a reader might trust the text most.

Prep reads `QuestionArchive` from the environment, the way the other stores are injected.

## 4. Sharing

- **Scorecard image.** Results gains a share button that exports a 1080×1350 card rendered with
  `ImageRenderer`: charcoal (or marigold, if the round earned the flood), the mosaic, the score
  "4 / 5", the date, the streak, and "NOVA". The rendering is a plain view with fixed sizes, so it
  doesn't depend on the screen it was shared from. It is shared via `ShareLink` as a
  `Transferable` PNG, together with the text below.
- **Text grid.** It replaces today's share line: `NOVA · 28 Sep` / `🟨🟨⬜🟨🟨 4/5` / `🔥 6-day
  streak`. One square per question in story order, filled for correct. It works in any chat app
  without an image, and says nothing it can't back up: no rank and no percentile.
- **Share a question.** Each row in the results review, and each Prep answer screen, can share
  that question as a card image: the prompt, the four lettered options, the source, and "Answer
  in NOVA". The answer is *not* printed on the card, which is the whole point.
- Shared images carry a small "machine-written question" line, like the app does.

## 5. Daily reminder

- A new `ReminderScheduler` in `Services/` wraps `UNUserNotificationCenter` behind a small
  protocol, so tests use a fake. It schedules one *non-repeating* notification per day for the
  next seven days, at the chosen hour and minute, each identified by its day key
  (`reminder-2026-09-29`). The text is in the content language: "Today's five stories are ready" /
  "आज की पाँच खबरें तैयार हैं". It does not use a repeating trigger because a repeating trigger
  can't skip one day. The seven days are topped back up on every launch and every time settings
  change.
- Settings are stored as `@AppStorage("reminderEnabled")` and `("reminderTime")`, default off,
  default time 08:00.
- It is offered, not forced: on the results screen *after* the first finished round ("Remind me
  tomorrow at 8:00?"), and as a toggle and time picker in Profile. Permission is only requested
  when the reader turns it on. If permission was denied, Profile says so and links to Settings.
- The notification is not sent on a day the round is already done: when a round is recorded,
  that day's pending request is removed by its identifier. This mirrors `PlayHistory`'s honesty:
  a reminder for work that's already done would be noise. The only logic that needs testing —
  which days to schedule, given the time, today, and whether today is done — is a pure
  function.
- On macOS and visionOS it compiles and works through the same API. Nothing here is iOS-only.

## Architecture summary

| New / changed | Kind | Tested by |
|---|---|---|
| `StoryCategory` +2, tints | model | existing + category tests |
| `RSSFeed.language`, new feeds | data | `RSSParserTests` with new samples |
| `LiveNewsService.pick(from:topics:)` | logic | `NewsServiceTests` |
| `ContentLanguage` | model | unit |
| `QuestionGenerator` language + context | service | `QuestionGeneratorTests` (prompt and decode) |
| `Question.explanation` | model | decode tests |
| `QuestionArchive` | logic | `QuestionArchiveTests` |
| `RevisionPicker` (which ten, in what order) | logic | `RevisionPickerTests` |
| `ShareGrid` (the emoji text) | logic | `ShareGridTests` |
| `ReminderScheduler` | service | `ReminderSchedulerTests` with a fake centre |
| Onboarding language page | view | `OnboardingTests` updated |
| Prep tab, revision screen | view | previews + simulator screenshots |
| Scorecard / question cards | view | previews + a render smoke test |
| `Localizable.xcstrings` (en, hi) | resource | build + Hindi screenshots |

New DEBUG launch argument, read-only like the others: `-startTab prep`.
CLAUDE.md is updated for the four tabs, `NewsStore`, the Prep tab, the archive, languages and
reminders. It also gets two corrections: 11 feeds, not nine, and a deployment target of 26.0.

## Error handling

- Hindi feeds down → the same "a feed that fails contributes nothing" rule. All Hindi feeds
  down → the deck's `.failed` state, with a line offering to switch to English for today.
- Generation fails in Hindi → the fallback is the Hindi feed summary with no question, the same
  as English.
- A corrupt or unreadable archive file → start empty and keep the bad file aside as
  `.corrupt` rather than overwrite it. Losing revision history silently is worse than losing it
  loudly.
- Notification permission denied → the toggle turns itself back off, and Profile explains why.
- `ImageRenderer` returns nil → share the text grid alone.

## Out of scope

Android, a backend or shared deck, groups and leaderboards, tappable challenge links, regional
languages beyond Hindi, a home-screen widget, streak freezes, an offline deck, and a fake-news
round. The last needs content that is verified as fake, and generating fakes would break the
generated-text principle.

## Build order (one commit per part)

1. Categories and English feeds, plus `pick` by topic.
2. `ContentLanguage`, Hindi feeds, the Hindi generator, and the onboarding and Profile choice.
3. The String Catalog and Hindi UI strings, with the font fallback.
4. `Question.explanation`, `QuestionArchive`, and the Prep tab with revision.
5. Sharing: the text grid, the scorecard image and the question card.
6. The daily reminder.
7. CLAUDE.md, DESIGN.md and PRODUCT.md updates, a full test run, and simulator screenshots.
