//
//  HomeView.swift
//  NOVA
//

import SwiftUI

/// Browsing, as opposed to playing.
///
/// The rail of sources sits on top and the newest stories from every feed run underneath.
/// Nothing here touches the round: reading from Home marks nothing read and unlocks no
/// quiz — that all lives in the Scroll tab.
struct HomeView: View {
    @Environment(NewsStore.self) private var store
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                channelRail
                latestStories
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(NovaBackdrop(tint: Nova.accent, intensity: 0.35).ignoresSafeArea())
        .navigationTitle("Home")
        .novaInlineTitle()
        .overlay {
            if store.loadState == .loading && store.allStories.isEmpty {
                ProgressView()
            }
        }
        // Rewrites the stories already on screen. Everything renders from the feed's own
        // text first, so this only ever improves what is showing — it never blocks it.
        .onChange(of: store.allStories.count, initial: true) {
            guard !store.allStories.isEmpty else { return }
            store.generateSummaries()
        }
    }

    private static let riverLimit = 40

    // MARK: - Channels

    private var channelRail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Channels")
                .font(Nova.display(.headline))
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

    // MARK: - Latest

    private var latestStories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest")
                .font(Nova.display(.headline))

            ForEach(store.latest(limit: Self.riverLimit)) { story in
                FeedRow(story: story) {
                    router.pushHome(.story(story.id))
                }
            }
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NavigationStack {
        HomeView()
            .environment(NewsStore())
            .environment(AppRouter())
            .tint(Nova.accent)
    }
}
