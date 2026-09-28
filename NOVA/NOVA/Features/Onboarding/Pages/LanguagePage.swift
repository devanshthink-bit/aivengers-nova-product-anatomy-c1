//
//  LanguagePage.swift
//  NOVA
//

import SwiftUI

/// The first question, before anything is sold: which language the news comes in.
///
/// Two tiles in the topics page's language — inverted white when chosen — each name
/// written in its own script, so a reader who can't read the other one still finds theirs.
/// The line under the headline is in both languages for the same reason.
struct LanguagePage: View {
    @Binding var language: ContentLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Headline(text: headline)
                    .onboardingEntry(0)

                Subhead(text: "खबरें हिन्दी में या अंग्रेज़ी में। You can change this later in Profile.")
                    .onboardingEntry(1)
            }

            VStack(spacing: 12) {
                ForEach(Array(ContentLanguage.allCases.enumerated()), id: \.element) { index, option in
                    Button {
                        withAnimation(.snappy(duration: 0.3)) { language = option }
                    } label: {
                        ChoiceTile(title: option.nativeName, symbol: nil, tint: nil, isOn: language == option, height: 76)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.nativeName)
                    .accessibilityAddTraits(language == option ? [.isSelected, .isButton] : .isButton)
                    .onboardingEntry(2 + index)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var headline: Text {
        Text("News in\n").foregroundStyle(.secondary)
        + Text("your language").foregroundStyle(.primary)
    }
}

#Preview {
    @Previewable @State var language = ContentLanguage.hindi
    LanguagePage(language: $language)
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Onboarding.ground)
}
