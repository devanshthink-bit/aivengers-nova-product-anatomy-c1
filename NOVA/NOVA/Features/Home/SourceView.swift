//
//  SourceView.swift
//  NOVA
//

import SwiftUI

/// One publisher's page: a header, then its most recent stories.
///
/// Opening this is what triggers generation for those stories. Everything renders from
/// the feed's own wording immediately and swaps to the rewrite as each batch lands, so
/// the page is readable from the first frame.
struct SourceView: View {
    let source: String

    @Environment(NewsStore.self) private var store
    @Environment(AppRouter.self) private var router

    private var feed: RSSFeed? {
        RSSFeed.all.first { $0.source == source }
    }

    private var stories: [Story] { store.stories(from: source) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                storyList
            }
            .padding(.horizontal, Nova.screenPadding)
            .padding(.bottom, 32)
            .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .novaPaperSurface()
        .navigationTitle(source)
        .novaInlineTitle()
        // Keyed on the story count, not `onAppear`: the page can be on screen before the
        // feeds have finished loading, and an `onAppear` pass filtered an empty list,
        // enqueued nothing and never ran again — leaving every row on the publisher's
        // own wording for the whole session.
        .onChange(of: store.allStories.count, initial: true) {
            guard !store.allStories.isEmpty else { return }
            store.generateSummaries(forSource: source)
        }
    }

    // MARK: - Header

    /// No card: the mark, the name at headline scale, and a hairline to close it off.
    @ViewBuilder
    private var header: some View {
        if let feed {
            VStack(alignment: .leading, spacing: 16) {
                SourceMark(source: feed.source, category: feed.category, size: 64)

                VStack(alignment: .leading, spacing: 8) {
                    Text(feed.source)
                        .font(Nova.display(.largeTitle))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 12) {
                        CategoryBadge(category: feed.category)
                        Text("\(stories.count) recent \(stories.count == 1 ? "story" : "stories")")
                            .novaMeta(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider().overlay(Nova.hairline)
            }
            .padding(.top, 12)
        }
    }

    // MARK: - Stories

    @ViewBuilder
    private var storyList: some View {
        if stories.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                PixelLoader(tints: [feed?.category.tint ?? .primary], size: 12)
                    .opacity(store.loadState == .loading ? 1 : 0)
                Text(store.loadState == .loading ? "Reading \(source)…" : "Nothing from \(source) yet.")
                    .font(Nova.display(.title3))
                Text("This feed didn't return any stories on the last refresh.")
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)
                    .opacity(store.loadState == .loading ? 0 : 1)
            }
            .padding(.top, 24)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                // The source is already the page title, so repeating it on every row
                // would be noise.
                ForEach(Array(stories.enumerated()), id: \.element.id) { index, story in
                    if index > 0 { Divider().overlay(Nova.hairline) }
                    FeedRow(story: story, showsSource: false) {
                        router.pushHome(.story(story.id))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SourceView(source: "BBC News")
            .environment(NewsStore())
            .environment(AppRouter())
    }
}
