//
//  ManifestoPage.swift
//  NOVA
//

import SwiftUI

/// The opener. One sentence, one size, one weight, two colours.
///
/// The page is deliberately still, so the ripple that follows the tap has something to
/// disturb. Nothing is asked here and nothing is explained — it is a statement of intent.
struct ManifestoPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            copy
                .font(Onboarding.headline())
                .tracking(-0.8)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
                .onboardingEntry(0)

            Spacer(minLength: 0)
        }
    }

    /// Two colours do all the work: the words that carry the sentence in `.primary`,
    /// the connective tissue in `.secondary`. No bold, no size change.
    private var copy: Text {
        Text("Know").foregroundStyle(.primary)
        + Text(" the world and ").foregroundStyle(.secondary)
        + Text("local").foregroundStyle(.primary)
        + Text(" updates quick and smooth ").foregroundStyle(.secondary)
        + Text("like water").foregroundStyle(.primary)
        + Text(".").foregroundStyle(.secondary)
    }
}

#Preview {
    ManifestoPage()
        .padding(.horizontal, Nova.screenPadding)
}
