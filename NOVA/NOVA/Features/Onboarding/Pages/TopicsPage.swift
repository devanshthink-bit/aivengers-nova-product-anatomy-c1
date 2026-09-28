//
//  TopicsPage.swift
//  NOVA
//

import SwiftUI

/// The seven categories, with the symbols and tint squares they carry elsewhere.
///
/// Chosen tiles invert to white (see `ChoiceTile`). They used to flood with their own
/// tint, and with two or three chosen out of seven the page became a patchwork of accents
/// that nothing else in the app uses. The promise in the subtitle is the literal
/// behaviour: chosen categories fill the deck first and nothing is removed. Saying "lead
/// with these" rather than "only these" is the difference between a preference and a lie.
struct TopicsPage: View {
    @Binding var selection: TopicSelection

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Headline(text: headline)
                    .onboardingEntry(0)

                Subhead(text: "We'll lead with these. You'll still see everything.")
                    .onboardingEntry(1)
            }

            // Pairs, with a lone last tile spanning both columns: seven doesn't divide by
            // two, and a half-width tile under a full row reads as a leftover.
            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(StoryCategory.allCases.chunked(into: 2).enumerated()), id: \.offset) { row, pair in
                    GridRow {
                        ForEach(Array(pair.enumerated()), id: \.element) { column, category in
                            tile(for: category, index: row * 2 + column)
                                .gridCellColumns(pair.count == 1 ? 2 : 1)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func tile(for category: StoryCategory, index: Int) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.3)) {
                selection.toggle(category)
            }
        } label: {
            ChoiceTile(
                title: category.title,
                symbol: category.symbolName,
                tint: category.tint,
                isOn: selection.contains(category)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityValue(selection.contains(category) ? "Chosen" : "Not chosen")
        .accessibilityAddTraits(selection.contains(category) ? [.isSelected, .isButton] : .isButton)
        .onboardingEntry(2 + index)
    }

    private var headline: Text {
        Text("What do you\n").foregroundStyle(.secondary)
        + Text("want first?").foregroundStyle(.primary)
    }
}

#Preview {
    @Previewable @State var selection = TopicSelection(categories: [.technology, .india])
    TopicsPage(selection: $selection)
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Onboarding.ground)
}
