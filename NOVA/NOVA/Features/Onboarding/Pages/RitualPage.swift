//
//  RitualPage.swift
//  NOVA
//

import SwiftUI

/// The daily loop, stated before anything is asked of the reader.
///
/// Every news app's onboarding sells personalisation. NOVA's actual shape — read five,
/// then play five — is the thing none of them have, so it goes first and it goes plainly.
///
/// The three beats are set as numbered editorial rows rather than a card of icons. A box
/// around them would make them look like settings; a big grey numeral makes them read as
/// steps, and costs no chrome at all.
struct RitualPage: View {
    private struct Beat {
        let title: String
        let detail: String
    }

    private let beats: [Beat] = [
        Beat(title: "Read", detail: "Five stories a day, swiped through like cards."),
        Beat(title: "Play", detail: "One question on each. Sink your answer in the hoop."),
        Beat(title: "Know", detail: "Come back tomorrow, and five more are waiting."),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            Headline(text: headline)
                .onboardingEntry(0)

            VStack(alignment: .leading, spacing: 26) {
                ForEach(Array(beats.enumerated()), id: \.offset) { index, beat in
                    row(index: index, beat: beat)
                        .onboardingEntry(1 + index)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var headline: Text {
        Text("Five stories.\nFive shots.\n").foregroundStyle(.primary)
        + Text("Every day.").foregroundStyle(.secondary)
    }

    private func row(index: Int, beat: Beat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 18) {
            Text(String(format: "%02d", index + 1))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 24, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(beat.title)
                    .font(.system(size: 19, weight: .bold))
                Text(beat.detail)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

#Preview {
    RitualPage()
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Onboarding.ground)
}
