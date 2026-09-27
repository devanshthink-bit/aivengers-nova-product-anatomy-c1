//
//  FeedRow.swift
//  NOVA
//

import SwiftUI

/// A story as it appears while browsing: Artifact's row.
///
/// Publisher line, headline, two lines of summary, thumbnail on the right — and no card
/// around it. Rows are separated by hairlines drawn by the list, because a stack of forty
/// boxes is forty borders competing with forty headlines.
///
/// Deliberately not `StoryRow`: that one carries the round's position and read state, and
/// neither means anything here — browsing doesn't count toward the game.
struct FeedRow: View {
    let story: Story
    var showsSource = true
    let action: () -> Void

    private static let thumbnailSize: CGFloat = 76

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    MetaLine(story: story, showsSource: showsSource)

                    Text(story.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !story.summary.isEmpty {
                        Text(story.summary)
                            .font(Nova.reading(.subheadline))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                StoryThumbnail(story: story, size: Self.thumbnailSize)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(story.title). \(story.source), \(story.publishedDescription)")
        .accessibilityHint("Opens the story")
        .accessibilityAddTraits(.isButton)
    }
}

/// A story's picture at thumbnail size, or nothing at all.
///
/// No empty box where a picture would be — an imageless row just reads wider. While a
/// remote image loads, a flat square in the category tint holds its place so the row
/// doesn't reflow under the reader's thumb.
struct StoryThumbnail: View {
    let story: Story
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)

        switch story.artwork {
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    story.category.tint.opacity(0.16)
                }
            }
            .frame(width: size, height: size)
            .clipShape(shape)
            .accessibilityHidden(true)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(shape)
                .accessibilityHidden(true)
        case .none:
            EmptyView()
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        FeedRow(story: MockNewsService.todayStories[0]) {}
        Divider()
        FeedRow(story: MockNewsService.todayStories[1], showsSource: false) {}
    }
    .padding(.horizontal)
    .novaPaperSurface()
}
