//
//  HomeView.swift
//  NOVA
//

import SwiftUI

/// Browsing, as opposed to playing.
///
/// A masthead with today's round pinned under it, the rail of sources, then the newest
/// stories from every feed as an Artifact-style river, narrowed by the category tabs that
/// pin over it once it scrolls up. Nothing here touches the round:
/// reading from Home marks nothing read and unlocks no quiz — that all lives in the
/// Scroll tab. The round card only *reports* on it and offers the way in.
struct HomeView: View {
    @Environment(NewsStore.self) private var store
    @Environment(AppRouter.self) private var router

    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""
    /// What the reader tapped. Nil is "All". Read through `activeCategory`, never directly:
    /// a tapped category can stop arriving (a language switch, a feed down).
    @State private var category: StoryCategory?

    private var availableCategories: [StoryCategory] {
        store.categories(ordered: TopicSelection(rawValue: pickedTopicsRaw))
    }

    private var activeCategory: StoryCategory? {
        NewsStore.resolvedCategory(category, among: availableCategories)
    }

    init(initialCategory: StoryCategory? = nil) {
        _category = State(initialValue: initialCategory)
    }

    var body: some View {
        ScrollView {
            // Lazy only because pinned section headers need a lazy stack: the tabs have to
            // stay reachable while the reader is forty rows down.
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
        .novaPaperSurface()
        .navigationTitle("Home")
        .novaHiddenNavigationBar()
        // Rewrites the stories already on screen. Everything renders from the feed's own
        // text first, so this only ever improves what is showing — it never blocks it.
        .onChange(of: store.allStories.count, initial: true) {
            guard !store.allStories.isEmpty else { return }
            store.generateSummaries()
        }
    }

    private static let riverLimit = 40

    // MARK: - Masthead

    /// Artifact's wordmark treatment: heavy type, and the asterisk beside it.
    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .center, spacing: 8) {
                Text("NOVA")
                    .font(Nova.poster(.largeTitle))
                    .tracking(0.5)
                AsteriskMark()
                    .fill(.primary)
                    .frame(width: 18, height: 18)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("NOVA")
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 12)

            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                .novaMeta(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.top, 8)
        .frame(maxWidth: Nova.readingMaxWidth)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Channels

    private var channelRail: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Channels")
                .padding(.horizontal, Nova.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.sources) { feed in
                        ChannelTile(feed: feed) {
                            router.pushHome(.source(feed.source))
                        }
                    }
                }
                .padding(.horizontal, Nova.screenPadding)
            }
            // The rail scrolls sideways inside a vertical ScrollView, so it must not
            // clip its own tiles at the screen edge.
            .scrollClipDisabled()
        }
    }

    // MARK: - Category tabs

    /// Pinned over the river once it scrolls up, on opaque paper with a hairline under it —
    /// no material behind the chips, per the Opaque Ground Rule. Chips follow the reader's
    /// topic order and only offer categories that actually arrived.
    private var categoryTabs: some View {
        let categories = availableCategories
        let active = activeCategory

        return VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Headlines")
                .padding(.horizontal, Nova.screenPadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    TopicChip(title: String(localized: "All"), tint: nil, isOn: active == nil) {
                        select(nil)
                    }
                    ForEach(categories, id: \.self) { item in
                        TopicChip(title: item.title, tint: item.tint, isOn: active == item) {
                            select(item)
                        }
                    }
                }
                .padding(.horizontal, Nova.screenPadding)
            }
            .scrollClipDisabled()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Categories")
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Nova.paper)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Nova.hairline).frame(height: 1)
        }
    }

    private func select(_ next: StoryCategory?) {
        withAnimation(.snappy(duration: 0.25)) { category = next }
        store.generateSummaries(forLatest: NewsStore.riverGenerationLimit, category: next)
    }

    // MARK: - Latest

    @ViewBuilder
    private var latestStories: some View {
        let active = activeCategory
        let stories = store.latest(limit: Self.riverLimit, category: active)

        VStack(alignment: .leading, spacing: 4) {
            if stories.isEmpty, let category = active, store.loadState == .loaded {
                Text("Nothing in \(category.title) right now. The feeds for it may be down.")
                    .font(Nova.reading(.body))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 20)
            } else if stories.isEmpty {
                riverPlaceholder
            } else if let lead = stories.first {
                LeadStory(story: lead) { router.pushHome(.story(lead.id)) }

                ForEach(stories.dropFirst()) { story in
                    Divider().overlay(Nova.hairline)
                    FeedRow(story: story) {
                        router.pushHome(.story(story.id))
                    }
                }
            }
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }

    /// Loading draws the motif; failure says what happened and what to do.
    @ViewBuilder
    private var riverPlaceholder: some View {
        switch store.loadState {
        case .failed:
            VStack(alignment: .leading, spacing: 10) {
                Text("The feeds didn't answer.")
                    .font(Nova.display(.title3))
                Text("Check your connection. Headlines will appear here as soon as one feed comes back.")
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Try again") { Task { await store.load() } }
                    .buttonStyle(PaperButtonStyle())
                    .padding(.top, 8)
            }
            .padding(.vertical, 20)
        default:
            HStack(spacing: 14) {
                PixelLoader(size: 10)
                Text("Reading the feeds")
                    .novaMeta(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 28)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Loading headlines")
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Nova.display(.title2))
            .tracking(-0.4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Lead story

/// The first headline gets Artifact's full-width treatment: picture, publisher, title.
private struct LeadStory: View {
    let story: Story
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                picture

                MetaLine(story: story)

                Text(story.title)
                    .font(Nova.display(.title2))
                    .tracking(-0.4)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                if !story.summary.isEmpty {
                    Text(story.summary)
                        .font(Nova.reading(.body))
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.bottom, 18)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(story.title). \(story.source), \(story.publishedDescription)")
        .accessibilityHint("Opens the story")
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var picture: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        switch story.artwork {
        case .remote(let url):
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            story.category.tint.opacity(0.16)
                        }
                    }
                }
                .clipShape(shape)
                .accessibilityHidden(true)
        case .asset(let name):
            Color.clear
                .aspectRatio(16 / 10, contentMode: .fit)
                .overlay { Image(name).resizable().scaledToFill() }
                .clipShape(shape)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Today's round

/// Today's round, pinned under the masthead: the week, the mosaic so far, and the way in.
///
/// This is the (Not Boring) rail brought onto paper. It reads the round, never changes it —
/// the button only switches to the Scroll tab and, once reading is done, opens the quiz.
private struct TodayRoundCard: View {
    @Environment(DailySession.self) private var session
    @Environment(PlayHistory.self) private var history
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 18) {
                MosaicView(
                    mosaic: session.mosaic,
                    tints: session.stories.map(\.category.tint),
                    cell: 9,
                    gap: 2
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text(status.headline)
                        .font(Nova.display(.title3))
                        .tracking(-0.3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(status.detail)
                        .novaMeta(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            WeekStrip(days: history.week(), dot: 26)

            Button(status.action) { open() }
                .buttonStyle(PaperButtonStyle())
        }
        .padding(20)
        .background(Nova.sheet, in: .rect(cornerRadius: Nova.cardCornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Nova.cardCornerRadius, style: .continuous)
                .strokeBorder(Nova.hairline, lineWidth: 1)
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private struct Status {
        let headline: String
        let detail: String
        let action: String
    }

    private var status: Status {
        let total = session.stories.count
        let read = session.storiesReadCount
        let engine = session.engine
        let streak = history.streak()
        let streakText = streak > 0 ? String(localized: "\(streak)-day streak") : String(localized: "Round 1 of today")

        if !session.hasRound {
            let left = total - read
            return Status(
                headline: left == 0
                    ? String(localized: "All \(total) read.")
                    : left == 1 ? String(localized: "1 story to read.") : String(localized: "\(left) stories to read."),
                detail: String(localized: "No questions could be written today"),
                action: read == 0 ? String(localized: "Start reading") : String(localized: "Keep reading")
            )
        }
        if engine.isComplete {
            return Status(
                headline: String(localized: "Round done. \(engine.correctAnswers) of \(engine.questionCount) sunk."),
                detail: streakText,
                action: String(localized: "See your round")
            )
        }
        if session.hasReadAllStories {
            return Status(
                headline: String(localized: "All \(total) read. Your shots are waiting."),
                detail: streakText,
                action: String(localized: "Take your shots")
            )
        }
        if read == 0 {
            return Status(
                headline: String(localized: "Today's \(total) are waiting."),
                detail: streakText,
                action: String(localized: "Start reading")
            )
        }
        let left = total - read
        return Status(
            headline: left == 1 ? String(localized: "1 story to go.") : String(localized: "\(left) stories to go."),
            detail: String(localized: "\(read) / \(total) read · \(streakText)"),
            action: String(localized: "Keep reading")
        )
    }

    private func open() {
        if !session.hasRound {
            // Nothing to play, so the button only ever goes to the stories.
        } else if session.engine.isComplete {
            router.replace(with: [.results])
        } else if session.hasReadAllStories, router.path.isEmpty {
            router.replace(with: [.quizIntro])
        }
        router.tab = .scroll
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(NewsStore())
    .environment(DailySession())
    .environment(PlayHistory())
    .environment(AppRouter())
}
