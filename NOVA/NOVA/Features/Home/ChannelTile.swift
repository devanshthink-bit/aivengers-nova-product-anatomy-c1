//
//  ChannelTile.swift
//  NOVA
//

import SwiftUI

/// One source in the rail across the top of Home.
///
/// A monogram when there's no logo: NOVA has no licence to most of these brands' marks
/// and scraping favicons would ship someone else's trademark inside the app. The initials
/// on the category tint read as a recognisable set without pretending to be the real thing.
struct ChannelTile: View {
    let feed: RSSFeed
    let action: () -> Void

    private static let size: CGFloat = 60

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                SourceMark(source: feed.source, category: feed.category, size: Self.size)
                    .overlay {
                        RoundedRectangle(cornerRadius: Self.size * 0.26, style: .continuous)
                            .strokeBorder(Nova.hairline, lineWidth: 1)
                    }

                Text(feed.source)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: Self.size + 14)
            }
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(feed.source)
        .accessibilityHint("Opens \(feed.source) stories")
    }
}

extension RSSFeed {
    var logoAssetName: String { Nova.logoAssetName(for: source) }
    var monogram: String { Nova.monogram(for: source) }
}

#Preview {
    ScrollView(.horizontal) {
        HStack(spacing: 14) {
            ForEach(RSSFeed.all) { feed in
                ChannelTile(feed: feed) {}
            }
        }
        .padding()
    }
    .novaPaperSurface()
}
