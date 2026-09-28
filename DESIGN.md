---
name: NOVA
description: A daily news deck you read on paper and then play on charcoal, earning a pixel mosaic as you go.
colors:
  paper: "#F6F4EE"
  paper-dark: "#121212"
  sheet: "#FFFFFF"
  sheet-dark: "#1D1D1F"
  ink: "#17160F"
  ink-dark: "#F2F0EA"
  hairline: "rgba(23, 22, 15, 0.10)"
  charcoal: "#1C1C1E"
  charcoal-raised: "#2A2A2D"
  charcoal-line: "rgba(255, 255, 255, 0.12)"
  marigold: "#F5B53A"
  marigold-ink: "#3A2204"
  tint-india: "#E0592A"
  tint-technology: "#3550DA"
  tint-business: "#1E9A72"
  tint-world: "#4DA3E8"
  tint-science: "#A64B9C"
  tint-sports: "#138496"
  tint-entertainment: "#D6457A"
  mosaic-sky: "#A9D3F5"
  mosaic-navy: "#23208F"
  feedback-right: "#3DDC97"
  feedback-wrong: "#FF6B5E"
typography:
  poster-hero:
    fontFamily: "SF Pro Compressed, system-ui"
    fontSize: "54pt (onboarding), 60pt (manifesto), 76pt (quiz intro), 96pt (score), 112pt (reward); all Dynamic Type scaled"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "0.3pt"
  poster:
    fontFamily: "SF Pro Compressed, system-ui"
    fontSize: "Dynamic Type largeTitle / title2"
    fontWeight: 800
    lineHeight: 1
  display:
    fontFamily: "SF Pro, system-ui"
    fontSize: "Dynamic Type title (28pt) / title2 (22pt) / title3 (20pt)"
    fontWeight: 700
    lineHeight: 1.15
    letterSpacing: "-0.3pt to -0.6pt"
  headline:
    fontFamily: "SF Pro, system-ui"
    fontSize: "Dynamic Type headline (17pt)"
    fontWeight: 600
  body:
    fontFamily: "New York, Georgia, serif"
    fontSize: "Dynamic Type body (17pt) / subheadline (15pt)"
    fontWeight: 400
    lineHeight: "+6pt line spacing on long copy"
  meta:
    fontFamily: "SF Mono, ui-monospace"
    fontSize: "Dynamic Type caption (12pt) / caption2 (11pt); subheadline (15pt) on buttons"
    fontWeight: 500
    letterSpacing: "1.2pt"
    fontFeature: "uppercase"
rounded:
  pixel: "1.5pt"
  image: "14pt"
  button-paper: "14pt"
  basket: "18pt"
  card: "20pt"
  tile: "22pt"
  story-sheet: "28pt"
  source-mark: "26% of side"
spacing:
  pixel-gap: "4pt"
  meta-gap: "7pt"
  stack: "12pt"
  stack-loose: "14pt"
  card-inset: "20pt"
  screen: "20pt"
  onboarding-page: "24pt"
  section: "30pt"
  control-height: "56pt"
  reading-max-width: "620pt"
components:
  button-paper:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.paper}"
    typography: "{typography.headline}"
    rounded: "{rounded.button-paper}"
    height: "{spacing.control-height}"
    width: "100%"
  button-chevron-prominent:
    backgroundColor: "#FFFFFF"
    textColor: "{colors.charcoal}"
    typography: "{typography.meta}"
    padding: "0 36pt"
    height: "{spacing.control-height}"
  button-chevron-outline:
    backgroundColor: "transparent"
    textColor: "#FFFFFF"
    typography: "{typography.meta}"
    padding: "0 36pt"
    height: "{spacing.control-height}"
  round-card:
    backgroundColor: "{colors.sheet}"
    rounded: "{rounded.card}"
    padding: "{spacing.card-inset}"
  story-sheet:
    backgroundColor: "{colors.sheet}"
    rounded: "{rounded.story-sheet}"
    padding: "18pt 22pt"
  question-card:
    backgroundColor: "{colors.charcoal-raised}"
    textColor: "#FFFFFF"
    rounded: "{rounded.card}"
    padding: "18pt"
  answer-board:
    backgroundColor: "{colors.charcoal-raised}"
    textColor: "#FFFFFF"
    rounded: "{rounded.basket}"
    padding: "12pt"
  topic-tile:
    backgroundColor: "{colors.charcoal-raised}"
    backgroundColorChosen: "#FFFFFF"
    textColor: "secondary"
    textColorChosen: "{colors.charcoal}"
    border: "1pt {colors.charcoal-line} (unchosen only)"
    rounded: "{rounded.tile}"
    padding: "14pt 16pt"
    height: "88pt"
  ribbon-badge:
    backgroundColor: "{colors.marigold}"
    textColor: "{colors.marigold-ink}"
    typography: "{typography.meta}"
    padding: "9pt 22pt"
  category-badge:
    textColor: "{colors.ink}"
    typography: "{typography.meta}"
    size: "8pt square + label"
---

# Design System: NOVA

## Overview

**Creative North Star: "Read on Paper, Play on Charcoal"**

NOVA has two grounds and one motif. **Paper** is where you read: a warm off-white ground, a white sheet lifting off it, near-black ink, hairlines instead of boxes, a publisher line above every headline and a New York serif for the body (the Artifact half). **Charcoal** is where you play: one focal object per screen, heavy compressed capitals, mono capitals for every label, chevron-ended buttons and a single marigold accent that only appears when the reader earned it (the (Not Boring) Habits half). The **pixel mosaic** and the drawn **asterisk** run through both and are what a day of reading builds.

The switch of ground is the mode change. A reader knows they have gone from reading to playing before they read a word, because the screen goes dark. Everything is flat and opaque: the frosted glass plates and gradient backdrops the app once had were removed on purpose, because body text swam on translucency.

**Key Characteristics:**
- Two surfaces, strictly assigned: paper for reading, charcoal for play.
- Square pixels, not rounded tiles, carry progress everywhere (mosaic, pips, loader).
- Marigold is a reward, never a decoration.
- Mono capitals for anything that is a measurement: counts, dates, ages, steps, labels.
- Motion is sized by frequency: presses near-instant, floods and mosaics allowed a moment.

## Colors

A warm neutral pair (paper and charcoal), one earned accent, and a seven-hue category family shared with the mosaic.

### Primary
- **Marigold** (`marigold`): the achievement colour. Full-screen floods on a correct shot and on a results screen with at least one hit, the ribbon badge, the live score once it is above zero, the underline under today in the week strip. Nothing else.
- **Marigold Ink** (`marigold-ink`): the brown that sits on marigold. When a flood arrives, every white element on it turns this brown rather than black.

### Secondary (category family)
- **Vermilion** (`tint-india`), **Cobalt** (`tint-technology`), **Jade** (`tint-business`), **Sky** (`tint-world`), **Plum** (`tint-science`), **Teal** (`tint-sports`), **Rose** (`tint-entertainment`): one per story category. They fill mosaic squares, progress pips, category-badge squares, source monograms, image placeholders (at 14 % with a 55 % asterisk) and the four hoop rims. The same hue family supplies the basket styles.
- **Mosaic Sky** (`mosaic-sky`) and **Mosaic Navy** (`mosaic-navy`): only in the decorative pixel scatter, alongside Vermilion and one marigold square.

### Tertiary (feedback on charcoal)
- **Right** (`feedback-right`) and **Wrong** (`feedback-wrong`): answer-board borders, tinted fills (14 % mixed into charcoal-raised) and status labels. They are brighter than system green and red, which go muddy on charcoal. They always come with a text label and a symbol.

### Neutral
- **Paper** (`paper` / `paper-dark`): the reading ground. Not white on purpose, so the sheet has something to lift off. It follows appearance.
- **Sheet** (`sheet` / `sheet-dark`): the story card, the round card, anything one step above paper.
- **Ink** (`ink` / `ink-dark`): all text and the paper button. It is also the app-wide tint, so interactive text on paper is ink, not a colour.
- **Hairline** (ink at 10 %): dividers between river rows and borders on sheets.
- **Charcoal** (`charcoal`): the play ground. It is fixed and does not follow appearance.
- **Charcoal Raised** (`charcoal-raised`): boards, tiles, fields and the question card on charcoal.
- **Charcoal Line** (white at 12 %): idle board borders.

### Named Rules
**The Earned Marigold Rule.** Marigold appears only because the reader did something: a sunk shot, a finished round, a score above zero, today's marker. It is never text on paper (it fails contrast there), never a hoop colour (it is the reward, not a target) and never decoration on charcoal. A results screen with zero hits stays charcoal.

**The Coloured Square Rule.** Category tints are fills and squares, never small text. None reach 4.5:1 as small type on paper, so a category label is always an 8pt tinted square next to mono ink text at secondary opacity.

**The Surface Follows Primary Rule.** Mosaic, pips and week strip draw in `.primary`, so one view reads as ink on paper and white on charcoal. Don't build a second variant per surface.

## Typography

**Display Font:** SF Pro, bold (system)
**Poster Font:** SF Pro Compressed, heavy (the system's own compressed width, so it follows Dynamic Type and ships no font files)
**Body Font:** New York (system serif)
**Label/Mono Font:** SF Mono

**Character:** Sharp sans headlines over a bookish serif on paper; shouting compressed capitals over tight mono measurements on charcoal.

### Hierarchy
- **Poster Hero** (heavy compressed, 54 to 112pt, scaled, uppercase): one statement per charcoal screen. Onboarding headlines, the quiz-intro title ("FIVE SHOTS."), the results score ("3 / 5"), the "+100" reward on a flood.
- **Poster** (heavy compressed, largeTitle or title2): the NOVA wordmark on Home (with the asterisk beside it) and the "SUNK IT" / "NOT QUITE" feedback line.
- **Display** (SF bold, title to title3, tracking -0.3 to -0.6pt): headlines on paper, section titles ("Channels", "Headlines"), the story-sheet title, the quiz prompt and the results line.
- **Headline** (SF semibold 17pt): river-row titles and the paper button label.
- **Body** (New York regular, body or subheadline, +6pt line spacing on long copy): story summaries, lead-story deck, row summaries, empty-state explanations. Held to a 620pt column.
- **Meta** (SF Mono medium, caption or caption2, uppercase, 1.2pt tracking): ages ("2H"), positions ("2 / 5"), dates, streaks, week-day labels, step markers, button labels on charcoal, ribbon text.

### Named Rules
**The Measurement Rule.** Anything that counts, dates or labels is set in mono capitals, because digits that don't shift width are what make a counter feel like one. Prose is never set in mono, except the short how-to lines on charcoal.

**The Two-Tone Headline Rule.** Onboarding headlines carry emphasis with colour alone: key words in `.primary`, the rest in `.secondary`, all in the same heavy compressed capitals. No weight or size changes inside a headline.

## Layout

One column, 20pt screen inset (24pt on onboarding pages), capped at a 620pt reading width and centred on wider screens. Sections on Home stack 30pt apart. Inside cards and rows, stacks run 12 to 14pt, and meta lines use 6 to 7pt gaps. The Home river is a full-width lead story (16:10 image, 14pt corners) followed by hairline-separated rows with a 76pt thumbnail on the right. The channel rail scrolls sideways and does not clip at the screen edge.

Charcoal screens centre a single object (the mosaic, the court, the score) with generous flexible space around it. Actions sit in a bottom safe-area bar and the quiz rail sits in a top bar. The quiz and results hide the status bar and navigation bar so a flood can reach the top edge. All controls are 56pt tall. Icon buttons show a 36pt circle inside a 44pt hit area.

## Elevation & Depth

Depth comes from tone, not shadow: sheet over paper, charcoal-raised over charcoal, with hairlines on paper sheets. Only two things cast shadows, and both are about physical lift. The story sheet in the deck casts one soft, low shadow, so the sheet underneath reads as underneath while this one is thrown. A chosen topic tile lifts on a deeper soft shadow, and unchosen tiles stay flat. Soft gradients and shading appear only on physical game objects (the paper ball, the hoop rims, the fading aim guide), never on a ground.

### Named Rules
**The Opaque Ground Rule.** Body text never sits on translucency. There are no glass plates, frosted cards or gradient backdrops behind reading or play surfaces. Onboarding is flat charcoal so the ripple has something legible to bend.

## Shapes

Continuous-corner rectangles throughout, with radius growing with the size of the object: 1.5pt on pixels, 14pt on images and the paper button, 18pt on answer boards, 20pt on cards, 22pt on topic tiles and 28pt on the story sheet. Source marks round at 26 % of their side, like an app icon. Mosaic squares round at only 14 % of their side. They stay pixels, because the moment the corners go soft they read as a grid of buttons. The **chevron capsule** (pointed ends, point depth 34 % of height) is the charcoal button silhouette. The **asterisk** is always drawn as three crossed bars, never typed. The **ribbon** is a flat band with two darker notched tails tucked behind it.

## Components

### Buttons
- **Paper button:** a full-width ink slab with 14pt corners, 56pt tall, with a paper-coloured headline label. Because it uses ink, it inverts to a light slab in Dark Mode. Disabled, the ink drops to 30 %. One per paper card or empty state.
- **Chevron prominent:** a filled white chevron capsule with a charcoal mono-capital label and 36pt side padding. One per charcoal screen, and it is the way forward. The onboarding version is full width. Disabled, it becomes charcoal-raised with a secondary label, and the label says what is missing.
- **Chevron outline:** a 1.5pt white stroke at 90 % with rounded joins, for everything else on charcoal (Share). On a flood, stroke and label turn marigold-ink.
- **Press:** every button and tappable row scales to 0.97 over 0.14s ease-out with no bounce. Rows (`PressableStyle`) also dip to 85 % opacity.

### Choice tiles (onboarding)
Topic and language tiles on charcoal. Unchosen: charcoal-raised with a 1pt charcoal-line border, the symbol at 55 % white and the label in secondary mono capitals. Chosen: **inverted to solid white** with a charcoal symbol and label, a small charcoal check disc and the soft lift shadow. The category tint appears only as the 8pt square beside the label — tiles used to flood with their tint, which with several chosen made a second accent system. Seven topics sit in pairs at 88pt, the odd last one spanning both columns.

### Category tabs (Home)
A sideways row of `TopicChip`s — "All" then each category that actually arrived, chosen topics first — as the pinned header of the Headlines river, on opaque paper with a hairline under it (no material). Chips are ink when active, sheet plus hairline otherwise, with the 9pt tint square, 44pt tall.

### Prep and revision
Prep is a reading surface: paper, display headline, `StatTile`s, per-topic rows with a thin **ink** bar on a hairline track (never the tint as a bar or text), and the week as hairline-separated rows. Revision answers are full-width sheet rows with a lettered mono square; once judged, the right answer takes a 2pt Jade border and the wrong pick a 2pt Vermilion border, each with a symbol — the charcoal feedback colours fall below 3:1 on paper.

### Share cards
Fixed 360×450pt (1080×1350px) renders. The scorecard is charcoal, or marigold with marigold-ink when the round earned the flood, with the mosaic, a 88pt compressed score and the streak in mono. The question card is always charcoal: prompt in display weight, lettered options, source, and a "machine-written question" line — never the answer.

### Hindi
Devanagari has no mono or compressed face. `novaMeta` labels set proportional and untracked in Hindi, since tracked mono split conjuncts; poster and serif faces fall back to the system Devanagari cleanly. Uppercase is a no-op there.

### Cards / Containers
- **Story sheet:** a white sheet with 28pt corners, a 1pt hairline and the one soft deck shadow. A 4:3 photo sits on top, falling back to a category-tint placeholder with a drawn asterisk that keeps the same shape so the card never resizes mid-swipe. It has no next button: you swipe up, and VoiceOver gets a named action.
- **Round card (Home):** a sheet with 20pt corners and a hairline border, holding the small mosaic, a display headline, a mono status line, the week strip and the paper button.
- **Question card (quiz):** charcoal-raised with 20pt corners. It has a meta row (story number, category badge, progress pips) above a display-weight white prompt.

### Answer boards
Flat charcoal-raised boards (18pt corners, 1pt charcoal-line border). The letter sits in a 20pt square of the hoop's rim colour. Once judged, the border goes to 2pt feedback-right or feedback-wrong and a mono status label with a symbol appears. Other boards dim to 45 %.

### Meta line and Source mark
The line above every paper headline: an 18pt source mark (the logo, or a two-letter heavy monogram on the category tint), the publisher name in semibold footnote, and the age in mono. In the Today sheet the source is swapped for a category badge. The channel rail uses the same mark at 60pt.

### Signature: Mosaic, Pixels and Loader
- **Mosaic:** the day's asterisk built from square cells. There are four states: unread (primary at 7 %), read (tint outline over a 14 % fill), missed (primary outline at 22 %) and correct (full tint at full scale). Squares land centre-outward on a small bouncy spring, 18ms apart.
- **Progress pips:** 9pt squares, 4pt apart, filled with each story's tint when done.
- **Pixel loader:** five category squares lighting in turn. It replaces spinners.
- **Pixel scatter:** fixed, composed squares with the asterisk, tumbling in on the welcome screen.

### Colour flood
A circle of marigold grows to cover the screen from the point of the event (the hoop the ball went through, or the mosaic on results). It enters slowly on a 0.6s strong ease-out, cubic-bezier(0.23, 1, 0.32, 1), and leaves fast on a 0.28s ease-out. While flooded, the environment flips to light so bars and labels turn marigold-ink. Under Reduce Motion it is a 0.25s crossfade.

### Ribbon badge
A mono bold label on a flat band with darker notched tails. It is marigold with marigold-ink by default. On results it is charcoal-raised with white text before the flood, and charcoal with marigold text after it.

### Week strip
Seven 26 to 30pt circles with mono weekday labels. Played days are a filled primary disc with a knocked-out checkmark, unplayed days are a faint outline, and today is a stronger outline with a bold label and a 16 × 2.5pt marigold underline.

### Motion tokens
Press 0.14s ease-out. Settle is a 0.45s spring with 0.18 bounce. Enter is 0.55s on the strong ease-out. Pop is a 0.38s spring with 0.34 bounce, used for rewards only. Stagger is 45ms. Onboarding elements rise 18pt out of a 5pt blur, 75ms apart. Every one of these has a Reduce Motion path: things are simply there, or a short ease-out fade replaces the movement.

## Do's and Don'ts

### Do:
- **Do** put every reading screen (Home, Source, Story detail, the story deck, the Today sheet) on paper with `novaPaperSurface()`, and every play screen (onboarding, quiz intro, quiz, results) on charcoal with `novaCharcoalSurface()`.
- **Do** label categories with an 8pt tinted square plus mono ink text at secondary opacity.
- **Do** show progress as square pixels in story tints (mosaic, pips, loader) rather than bars or spinners.
- **Do** keep one prominent action per screen: the paper slab on paper, the white chevron on charcoal.
- **Do** start floods from where the event happened, enter them slowly (0.6s) and leave fast (0.28s).
- **Do** give every button and tappable row the 0.97 scale press on 0.14s ease-out.
- **Do** give every animation a Reduce Motion fallback, and keep every gesture reachable by a button or accessibility action.
- **Do** draw the asterisk with `AsteriskMark`, never a typed character.

### Don't:
- **Don't** set marigold as text on paper, use it on a hoop, or show it when nothing was earned.
- **Don't** set category tints as small text on paper.
- **Don't** put glass, frosted material or gradient backdrops behind reading or play surfaces.
- **Don't** round mosaic squares into tiles, or swap pixels for dots or bars.
- **Don't** use `.preferredColorScheme` to make a charcoal screen dark. It flips the whole window, so the paper reader underneath goes dark mid-push. Use the surface modifier.
- **Don't** add a second accent or a parallel colour system. New states take ink, charcoal tones or the category family.
- **Don't** use literal black for the paper button. Use ink so it inverts in Dark Mode.
