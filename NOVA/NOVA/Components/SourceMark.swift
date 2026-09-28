//
//  SourceMark.swift
//  NOVA
//

import SwiftUI

/// A publisher's mark at the size of a favicon: the logo if it's in the catalog, otherwise
/// the monogram on the category's tint.
///
/// This is Artifact's metadata line — the mark is what lets you tell sources apart at a
/// glance without reading the name.
struct SourceMark: View {
    let source: String
    let category: StoryCategory
    var size: CGFloat = 18

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
        let asset = Nova.logoAssetName(for: source)

        Group {
            if Nova.hasAsset(asset) {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                shape
                    .fill(category.tint)
                    .overlay {
                        Text(Nova.monogram(for: source))
                            .font(.system(size: size * 0.42, weight: .heavy))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                    }
            }
        }
        .frame(width: size, height: size)
        .clipShape(shape)
        .accessibilityHidden(true)
    }
}

/// Artifact's line above every headline: mark, publisher, age.
struct MetaLine: View {
    let story: Story
    var showsSource = true

    var body: some View {
        HStack(spacing: 7) {
            if showsSource {
                SourceMark(source: story.source, category: story.category)
                Text(story.source)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            } else {
                CategoryBadge(category: story.category)
            }

            Text(story.shortAge)
                .font(Nova.meta(.caption2))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(showsSource ? "\(story.source), \(story.publishedDescription)" : story.publishedDescription)
    }
}

extension Nova {
    /// Asset catalog name for a publisher's logo: "BBC News" → "logo-bbc-news".
    ///
    /// Derived from the source name rather than stored, so adding a feed needs no second
    /// edit — drop in a matching asset and every mark picks it up.
    static func logoAssetName(for source: String) -> String {
        // Section feeds are one publisher and share one mark, so they all resolve to the
        // same asset rather than needing identical copies: the BBC's four, The Hindu's
        // cricket, science and entertainment feeds, and News18's Hindi edition.
        let publishers = ["BBC": "logo-bbc", "The Hindu": "logo-the-hindu", "News18": "logo-news18"]
        if let match = publishers.first(where: { source.hasPrefix($0.key) }) { return match.value }
        return "logo-" + source.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    /// "BBC Business" → "BB", "Mint" → "MI". Two letters keeps every mark the same
    /// visual weight, which a variable-length wordmark would not.
    static func monogram(for source: String) -> String {
        let words = source.split(separator: " ")
        if words.count >= 2, let a = words[0].first, let b = words[1].first {
            return "\(a)\(b)".uppercased()
        }
        return String(source.prefix(2)).uppercased()
    }
}
