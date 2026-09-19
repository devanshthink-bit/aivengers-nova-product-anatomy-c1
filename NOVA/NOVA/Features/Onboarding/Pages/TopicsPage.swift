//
//  TopicsPage.swift
//  NOVA
//

import SwiftUI

/// The five real categories, with the tints and symbols they already carry elsewhere.
///
/// The promise in the subtitle is the literal behaviour: chosen categories sort to the
/// front of the deck and nothing is removed, because the round needs all five stories.
/// Saying "lead with these" rather than "only these" is the difference between a
/// preference and a lie.
struct TopicsPage: View {
    @Binding var selection: TopicSelection

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(text: "Your world")
                    Spacer(minLength: 0)
                    counter
                }
                .onboardingEntry(0)

                headline
                    .font(Onboarding.headline())
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntry(1)

                Text("We'll lead with these. You'll still see everything.")
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntry(2)
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(StoryCategory.allCases.enumerated()), id: \.element) { index, category in
                    tile(category)
                        .onboardingEntry(3 + index)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var headline: Text {
        Text("What do you\n").foregroundStyle(.secondary)
        + Text("want first?").foregroundStyle(.primary)
    }

    @ViewBuilder
    private var counter: some View {
        Text(selection.isComplete ? "\(selection.count) chosen" : "Pick \(selection.remaining) more")
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(selection.isComplete ? Nova.accent : .secondary)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.3), value: selection)
    }

    private func tile(_ category: StoryCategory) -> some View {
        let isOn = selection.contains(category)

        return Button {
            withAnimation(.snappy(duration: 0.28)) {
                selection.toggle(category)
            }
        } label: {
            TopicTile(category: category, isOn: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityValue(isOn ? "Chosen" : "Not chosen")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

/// Split out of `TopicsPage` because the chosen/unchosen styling is a thicket of
/// conditional shape styles, and the type checker gives up when it all sits inline.
private struct TopicTile: View {
    let category: StoryCategory
    let isOn: Bool

    private var symbolStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(.white) : AnyShapeStyle(category.tint)
    }

    private var tileStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(.white.opacity(0.22)) : AnyShapeStyle(category.tint.opacity(0.14))
    }

    private var surfaceStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(category.tint.gradient) : AnyShapeStyle(Color(.secondarySystemBackground))
    }

    private var titleStyle: AnyShapeStyle {
        isOn ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
    }

    private var shadowColor: Color {
        isOn ? category.tint.opacity(0.3) : .black.opacity(0.05)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: category.symbolName)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(symbolStyle)
                .frame(width: 36, height: 36)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(tileStyle)
                }

            Text(category.title)
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(titleStyle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(surfaceStyle)
        }
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(7)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .shadow(color: shadowColor, radius: isOn ? 14 : 8, y: isOn ? 7 : 4)
    }
}

#Preview {
    @Previewable @State var selection = TopicSelection(categories: [.technology])
    TopicsPage(selection: $selection)
        .padding(.horizontal, Nova.screenPadding)
}
