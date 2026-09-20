//
//  ChannelTile.swift
//  NOVA
//

import SwiftUI

/// One source in the rail across the top of Home.
///
/// A monogram rather than a publisher logo: NOVA has no licence to any of these brands'
/// marks and scraping favicons would ship someone else's trademark inside the app. The
/// initials tinted by category read as a recognisable set without pretending to be the
/// real thing.
struct ChannelTile: View {
    let feed: RSSFeed
    let action: () -> Void

    private static let size: CGFloat = 68

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                logo
                    .frame(width: Self.size, height: Self.size)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: feed.category.symbolName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(feed.category.tint)
                            .padding(4)
                            .background(.background, in: .circle)
                            .offset(x: 4, y: 4)
                    }

                Text(feed.source)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: Self.size + 12)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(feed.source)
        .accessibilityHint("Opens \(feed.source) stories")
    }
}

extension ChannelTile {
    /// The publisher's logo if it's been added, otherwise the monogram.
    ///
    /// Falls back rather than requiring all nine at once, so logos can land one at a
    /// time without leaving empty tiles in the rail meanwhile.
    @ViewBuilder
    var logo: some View {
        if Nova.hasAsset(feed.logoAssetName) {
            Image(feed.logoAssetName)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(feed.category.tint.gradient)
                .overlay {
                    Text(feed.monogram)
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                }
        }
    }
}

extension RSSFeed {
    /// Asset catalog name for this publisher's logo: "BBC News" → "logo-bbc-news".
    ///
    /// Derived from the source name rather than stored, so adding a feed needs no second
    /// edit — drop in a matching asset and the tile picks it up.
    var logoAssetName: String {
        // The four BBC section feeds are one publisher and share one mark, so they all
        // resolve to the same asset rather than needing four identical copies.
        if source.hasPrefix("BBC") { return "logo-bbc" }
        return "logo-" + source.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// "BBC Business" → "BB", "Mint" → "MI". Two letters keeps every tile the same
    /// visual weight, which a variable-length wordmark would not.
    var monogram: String {
        let words = source.split(separator: " ")
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return "\(a)\(b)".uppercased()
        }
        return String(source.prefix(2)).uppercased()
    }
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
}
