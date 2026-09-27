//
//  StoryCardView.swift
//  NOVA
//

import SwiftUI

/// One story on a sheet of paper. `StoryReaderView` stacks these into a deck.
///
/// Opaque on purpose. This used to be a frosted glass plate over a gradient, and the
/// glass needed a rim light, a sheen and an inner lip before the text stopped swimming —
/// all to fix a problem the glass itself caused. A sheet reads like the page it is.
///
/// There is no next button. Advancing is a swipe, and `onNext` exists only as a VoiceOver
/// action so the deck stays operable without the gesture.
struct StoryCardView: View {
    let story: Story
    let position: Int
    let total: Int
    let onShowIndex: () -> Void
    let onNext: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Nova.storyCardCornerRadius, style: .continuous)
    }

    var body: some View {
        face
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Nova.sheet, in: shape)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Nova.hairline, lineWidth: 1) }
            // One soft, offset shadow: enough for the sheet underneath to read as
            // underneath while this one is being thrown.
            .shadow(color: .black.opacity(0.12), radius: 24, y: 14)
            .contentShape(shape)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Story \(position) of \(total)")
            .accessibilityAction(named: isLast ? "Finish reading" : "Next story", onNext)
    }

    // MARK: - Content

    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 14) {
                header

                Text(story.title)
                    .font(Nova.display(.title2))
                    .tracking(-0.5)
                    .lineLimit(4)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                MetaLine(story: story)

                Text(story.summary)
                    .font(Nova.reading(.body))
                    .lineSpacing(6)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
                    .layoutPriority(1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 18)
            // Clears the floating tab bar. The card ignores the safe area on purpose so
            // it can be thrown off-screen, which also means it never receives the inset
            // the tab bar would otherwise contribute — at 40 the footer sat underneath
            // the pill and "Swipe up" was half-hidden behind it.
            .padding(.bottom, 108)
        }
    }

    private var photo: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                switch story.artwork {
                case .asset(let name):
                    Image(name)
                        .resizable()
                        .scaledToFill()
                case .remote(let url):
                    // A feed image can be slow or gone. The placeholder is the same shape
                    // as the loaded photo so the card never resizes under the reader
                    // mid-swipe, which would break the deck gesture.
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            artworkPlaceholder
                        }
                    }
                case .none:
                    artworkPlaceholder
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }

    /// Stands in for missing or still-loading art: the asterisk on the category's colour,
    /// so a deck of imageless cards still reads as five distinct stories, in the app's own
    /// mark rather than a generic symbol.
    private var artworkPlaceholder: some View {
        story.category.tint.opacity(0.14)
            .overlay {
                AsteriskMark()
                    .fill(story.category.tint.opacity(0.55))
                    .frame(width: 72, height: 72)
            }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            CategoryBadge(category: story.category)

            Text("\(position) / \(total)")
                .font(Nova.meta(.caption2))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            Button(action: onShowIndex) {
                Image(systemName: "list.bullet")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.primary.opacity(0.07), in: .circle)
                    // A 36 pt circle is what shows; 44 pt is what the finger gets.
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Today's stories")
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.up")
                .font(.caption2.weight(.heavy))
            Text(isLast ? "Swipe up to finish" : "Swipe up")
                .novaMeta(.caption2, weight: .semibold)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    private var isLast: Bool { position >= total }
}

#Preview {
    StoryCardView(story: MockNewsService.todayStories[1], position: 2, total: 5) {} onNext: {}
        .frame(height: 720)
        .padding(16)
        .novaPaperSurface()
}
