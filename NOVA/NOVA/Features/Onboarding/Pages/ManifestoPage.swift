//
//  ManifestoPage.swift
//  NOVA
//

import SwiftUI

/// The opener: one sentence, centred in an otherwise empty screen.
///
/// Nothing is asked and nothing is explained. The type is set larger here than anywhere
/// else in the app and given the whole page to sit in, because the emptiness around it is
/// what makes it read as a statement instead of a caption. It is also the stillest thing
/// NOVA ever shows, which is precisely what the ripple needs in order to disturb it.
struct ManifestoPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Headline(text: copy, size: Onboarding.manifestoSize)
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
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity)
        .background(Onboarding.ground)
}
