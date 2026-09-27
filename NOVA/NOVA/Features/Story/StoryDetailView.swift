//
//  StoryDetailView.swift
//  NOVA
//

import SwiftUI

/// A single story, opened from Home: Artifact's reader.
///
/// Publisher line, a big sans headline, the picture, then serif body copy at a comfortable
/// measure. Separate from `StoryCardView` because the deck card is a fixed-height surface
/// built to be thrown off-screen — it can't scroll, and a long story would be clipped.
///
/// Reading here does not mark the story read: browsing is deliberately outside the round.
struct StoryDetailView: View {
    let storyID: StoryID

    @Environment(NewsStore.self) private var store

    private var story: Story? { store.story(withID: storyID) }

    var body: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 14) {
                        MetaLine(story: story)

                        Text(story.title)
                            .font(Nova.display(.title))
                            .tracking(-0.6)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)

                        CategoryBadge(category: story.category)
                    }
                    .padding(.horizontal, Nova.screenPadding)

                    artwork(for: story)

                    VStack(alignment: .leading, spacing: 18) {
                        Text(story.summary)
                            .font(Nova.reading(.body))
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)

                        Divider().overlay(Nova.hairline)

                        generationNotice
                    }
                    .padding(.horizontal, Nova.screenPadding)
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
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
        .novaPaperSurface()
        .novaInlineTitle()
    }

    @ViewBuilder
    private func artwork(for story: Story) -> some View {
        switch story.artwork {
        case .remote(let url):
            Color.clear
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay {
                    AsyncImage(url: url) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                        } else {
                            story.category.tint.opacity(0.14)
                        }
                    }
                }
                .clipped()
                .accessibilityHidden(true)
        case .asset(let name):
            Color.clear
                .aspectRatio(3 / 2, contentMode: .fit)
                .overlay { Image(name).resizable().scaledToFill() }
                .clipped()
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }

    /// The summary shown here is machine-written from the headline and the feed's own
    /// blurb. Saying so is the honest thing to do when the text is not the publisher's.
    private var generationNotice: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "sparkles")
                .font(.caption)
            Text("Summarised automatically from \(story?.source ?? "the feed"). Open the publisher for the full report.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}
