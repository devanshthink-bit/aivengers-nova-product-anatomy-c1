//
//  TopicsPage.swift
//  NOVA
//

import SwiftUI

/// The five real categories, with the tints and symbols they already carry elsewhere.
///
/// Chosen tiles flood with their own colour and grow a white tick, so the selection is
/// legible from across the room rather than needing to be read. The promise in the
/// subtitle is the literal behaviour: chosen categories sort to the front of the deck and
/// nothing is removed, because the round needs all five stories. Saying "lead with these"
/// rather than "only these" is the difference between a preference and a lie.
struct TopicsPage: View {
    @Binding var selection: TopicSelection

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Headline(text: headline)
                    .onboardingEntry(0)

                Subhead(text: "We'll lead with these. You'll still see everything.")
                    .onboardingEntry(1)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element) { index, category in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) {
                            selection.toggle(category)
                        }
                    } label: {
                        TopicTile(category: category, isOn: selection.contains(category))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.title)
                    .accessibilityValue(selection.contains(category) ? "Chosen" : "Not chosen")
                    .accessibilityAddTraits(selection.contains(category) ? [.isSelected, .isButton] : .isButton)
                    .onboardingEntry(2 + index)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var headline: Text {
        Text("What do you\n").foregroundStyle(.secondary)
        + Text("want first?").foregroundStyle(.primary)
    }
}

/// Split out because the chosen/unchosen styling is a thicket of conditional shape
/// styles, and the type checker gives up when it all sits inline in the page.
private struct TopicTile: View {
    let category: StoryCategory
    let isOn: Bool

    private var fill: AnyShapeStyle {
        isOn
            ? AnyShapeStyle(category.tint.gradient)
            : AnyShapeStyle(Onboarding.surface)
    }

    private var symbolStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(.white) : AnyShapeStyle(category.tint)
    }

    private var titleStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Image(systemName: category.symbolName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(symbolStyle)

            Spacer(minLength: 12)

            Text(category.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(titleStyle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Onboarding.tileHeight, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                .fill(fill)
        }
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(category.tint)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.white))
                    .padding(14)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        // The chosen tiles lift off the page; the rest stay flat against it.
        .shadow(color: isOn ? category.tint.opacity(0.35) : .clear, radius: 16, y: 8)
    }
}

#Preview {
    @Previewable @State var selection = TopicSelection(categories: [.technology, .india])
    TopicsPage(selection: $selection)
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Onboarding.ground)
}
