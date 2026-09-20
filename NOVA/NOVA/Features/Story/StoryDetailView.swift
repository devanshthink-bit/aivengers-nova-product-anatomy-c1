//
//  StoryDetailView.swift
//  NOVA
//

import SwiftUI

/// A single story, opened from Home.
///
/// Separate from `StoryCardView` because the deck card is a fixed-height surface built to
/// be thrown off-screen — it can't scroll, and a long story would be clipped inside it.
/// This is the scrollable reading view.
///
/// Reading here does not mark the story read: browsing is deliberately outside the round.
struct StoryDetailView: View {
    let storyID: StoryID

    @Environment(NewsStore.self) private var store

    private var story: Story? { store.story(withID: storyID) }

    var body: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 18) {
                    artwork(for: story)

                    VStack(alignment: .leading, spacing: 12) {
                        CategoryBadge(category: story.category)

                        Text(story.title)
                            .font(Nova.display(.title))
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(story.source) · \(story.publishedDescription)")
                            .font(Nova.reading(.footnote))
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        Text(story.summary)
                            .font(Nova.reading(.body))
                            .fixedSize(horizontal: false, vertical: true)

                        generationNotice
                    }
                    .padding(.horizontal, Nova.screenPadding)
                }
                .padding(.bottom, 32)
                .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView(
                    "Story unavailable",
                    systemImage: "doc.questionmark",
                    description: Text("It may have dropped off the feed since you opened the list.")
                )
                .padding(.top, 60)
            }
        }
        .background(NovaBackdrop(tint: story?.category.tint ?? Nova.accent, intensity: 0.4).ignoresSafeArea())
        .novaInlineTitle()
    }

    @ViewBuilder
    private func artwork(for story: Story) -> some View {
        switch story.artwork {
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    Color.clear
                }
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipped()
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipped()
        case .none:
            EmptyView()
        }
    }

    /// The summary shown here is machine-written from the headline and the feed's own
    /// blurb. Saying so is the honest thing to do when the text is not the publisher's.
    private var generationNotice: some View {
        Label(
            "Summarised automatically from \(story?.source ?? "the feed"). Open the publisher for the full report.",
            systemImage: "sparkles"
        )
        .font(.caption)
        .foregroundStyle(.tertiary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 8)
    }
}
