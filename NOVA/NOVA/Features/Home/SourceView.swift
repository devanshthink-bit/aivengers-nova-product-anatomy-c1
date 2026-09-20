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
            VStack(alignment: .leading, spacing: 20) {
                header
                storyList
            }
            .padding(.horizontal, Nova.screenPadding)
            .padding(.bottom, 24)
            .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(NovaBackdrop(tint: Nova.accent, intensity: 0.35).ignoresSafeArea())
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

    @ViewBuilder
    private var header: some View {
        if let feed {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 14) {
                    Group {
                        if Nova.hasAsset(feed.logoAssetName) {
                            Image(feed.logoAssetName)
                                .resizable()
                                .scaledToFill()
                        } else {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(feed.category.tint.gradient)
                                .overlay {
                                    Text(feed.monogram)
                                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                        }
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 6) {
                        Text(feed.source)
                            .font(Nova.display(.title2))
                        CategoryBadge(category: feed.category)
                    }

                    Spacer(minLength: 0)
                }

                Text("\(stories.count) recent \(stories.count == 1 ? "story" : "stories")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .novaCard()
            .padding(.top, 4)
        }
    }

    // MARK: - Stories

    @ViewBuilder
    private var storyList: some View {
        if stories.isEmpty {
            ContentUnavailableView(
                "Nothing from \(source) yet",
                systemImage: "tray",
                description: Text("This feed didn't return any stories on the last refresh.")
            )
            .padding(.top, 40)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                // The source is already the page title, so repeating it on every row
                // would be noise.
                ForEach(stories) { story in
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
            .tint(Nova.accent)
    }
}
