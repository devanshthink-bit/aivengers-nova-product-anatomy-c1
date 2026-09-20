//
//  StoryCardView.swift
//  NOVA
//

import SwiftUI

/// One story sitting on a frosted glass plate. `StoryReaderView` stacks these into a deck.
///
/// The plate is edge to edge. Type is inset so it reads as written on the glass.
///
/// There is no next button. Advancing is a swipe, and `onNext` exists only as a VoiceOver
/// action so the deck stays operable without the gesture.
struct StoryCardView: View {
    let story: Story
    let position: Int
    let total: Int
    let onShowIndex: () -> Void
    let onNext: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Nova.storyCardCornerRadius, style: .continuous)
    }

    var body: some View {
        face
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background {
                if reduceTransparency {
                    shape.fill(.background)
                }
            }
            .glassEffect(glass, in: shape)
            .overlay { sheen }
            .overlay { rimLight }
            .overlay { innerLip }
            .shadow(color: .black.opacity(0.2), radius: 30, y: 16)
            .shadow(color: .white.opacity(0.35), radius: 1, y: -1)
            .contentShape(shape)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Story \(position) of \(total)")
            .accessibilityAction(named: isLast ? "Finish reading" : "Next story", onNext)
    }

    // MARK: - Glass

    /// Untinted liquid glass. Colour lives on the backdrop, not on the plate.
    private var glass: Glass {
        reduceTransparency
            ? .identity
            : .regular.interactive()
    }

    /// A thin catch-light across the top, not a coat of paint.
    private var sheen: some View {
        shape.fill(
            LinearGradient(
                colors: [.white.opacity(0.38), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.2)
            )
        )
        .allowsHitTesting(false)
    }

    /// Highlight on the lit corner, refraction on the far edge — all the way around.
    private var rimLight: some View {
        shape
            .strokeBorder(
                LinearGradient(
                    colors: [
                        .white.opacity(0.78),
                        .white.opacity(0.22),
                        .white.opacity(0.08),
                        .white.opacity(0.42)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.6
            )
            .allowsHitTesting(false)
    }

    /// Inset lip so the type sits inside the glass, not on the cut edge.
    private var innerLip: some View {
        shape
            .inset(by: 7)
            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
            .allowsHitTesting(false)
    }

    // MARK: - Content

    private var face: some View {
        VStack(alignment: .leading, spacing: 0) {
            photo

            VStack(alignment: .leading, spacing: 12) {
                header

                Text(story.title)
                    .font(Nova.display(.title2))
                    .tracking(-0.4)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(story.source) · \(story.publishedDescription)")
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)

                Text(story.summary)
                    .font(Nova.reading(.body))
                    .lineSpacing(6)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

                footer
                    .layoutPriority(1)
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
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
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: Nova.storyCardCornerRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: Nova.storyCardCornerRadius,
                    style: .continuous
                )
            )
            .accessibilityHidden(true)
    }

    /// Stands in for missing or still-loading art. Tinted by category so a deck of
    /// imageless cards still reads as five distinct stories rather than five grey boxes.
    private var artworkPlaceholder: some View {
        LinearGradient(
            colors: [
                Nova.accent.opacity(0.35),
                Nova.accent.opacity(0.08)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Image(systemName: story.category.symbolName)
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            CategoryBadge(category: story.category)

            Spacer(minLength: 0)

            Button(action: onShowIndex) {
                Image(systemName: "list.bullet")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(.quaternary, in: .circle)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Today's stories")
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Story \(position) of \(total)")
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Label(
                isLast ? "Swipe up to finish" : "Swipe up",
                systemImage: "chevron.up"
            )
            .font(.caption.weight(.medium))
            .foregroundStyle(Nova.accent)
            .labelStyle(.titleAndIcon)
        }
        .accessibilityHidden(true)
    }

    private var isLast: Bool { position >= total }
}

#Preview {
    ZStack {
        LinearGradient(
            colors: [.indigo.opacity(0.6), .teal.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        StoryCardView(story: MockNewsService.todayStories[1], position: 2, total: 5) {} onNext: {}
            .frame(height: 720)
            .padding(16)
    }
}
