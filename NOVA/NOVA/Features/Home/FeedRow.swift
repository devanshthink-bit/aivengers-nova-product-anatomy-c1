//
//  FeedRow.swift
//  NOVA
//

import SwiftUI

/// A story as it appears while browsing.
///
/// Deliberately not `StoryRow`: that one carries the round's position number and read
/// checkmark, and neither means anything here — browsing doesn't count toward the game.
/// Sharing it would have meant passing fake positions and a permanent "unread" tick.
struct FeedRow: View {
    let story: Story
    var showsSource = true
    let action: () -> Void

    private static let thumbnailSize: CGFloat = 72

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    if showsSource {
                        Text("\(story.source) · \(story.publishedDescription)")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(story.category.tint)
                    } else {
                        Text(story.publishedDescription)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(story.title)
                        .font(Nova.display(.subheadline))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if !story.summary.isEmpty {
                        Text(story.summary)
                            .font(Nova.reading(.footnote))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer(minLength: 0)

                thumbnail
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .novaCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(story.title). \(story.source)")
        .accessibilityHint("Opens the story")
    }

    @ViewBuilder
    private var thumbnail: some View {
        switch story.artwork {
        case .remote(let url):
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFill()
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        case .none:
            // No empty box where a picture would be — an imageless row just reads wider.
            EmptyView()
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(story.category.tint.opacity(0.15))
            .overlay {
                Image(systemName: story.category.symbolName)
                    .font(.footnote)
                    .foregroundStyle(story.category.tint)
            }
    }
}

#Preview {
    VStack(spacing: 12) {
        FeedRow(story: MockNewsService.todayStories[0]) {}
        FeedRow(story: MockNewsService.todayStories[1], showsSource: false) {}
    }
    .padding()
}
