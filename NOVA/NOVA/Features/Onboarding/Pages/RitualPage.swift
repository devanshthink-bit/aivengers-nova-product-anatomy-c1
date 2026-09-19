//
//  RitualPage.swift
//  NOVA
//

import SwiftUI

/// The daily loop, stated before anything is asked of the reader.
///
/// Every news app's onboarding sells personalisation. NOVA's actual shape — read five,
/// then play five — is the thing none of them have, so it goes first and it goes plainly.
struct RitualPage: View {
    private struct Beat: Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        let detail: String
    }

    private let beats: [Beat] = [
        Beat(
            symbol: "book.pages",
            title: "Read",
            detail: "Five stories a day, swiped through like cards."
        ),
        Beat(
            symbol: "basketball",
            title: "Play",
            detail: "One question on each. Sink your answer in the hoop."
        ),
        Beat(
            symbol: "sparkles",
            title: "Know",
            detail: "Come back tomorrow, and five more are waiting."
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "How it works")
                    .onboardingEntry(0)

                headline
                    .font(Onboarding.headline())
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntry(1)
            }

            VStack(spacing: 0) {
                ForEach(Array(beats.enumerated()), id: \.element.id) { index, beat in
                    row(beat)

                    if index < beats.count - 1 {
                        Divider().padding(.leading, Onboarding.iconTileSize + 16)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .onboardingCore()
            .onboardingShell()
            .onboardingEntry(2)

            Spacer(minLength: 0)
        }
    }

    private var headline: Text {
        Text("Five stories.\n").foregroundStyle(.primary)
        + Text("Five shots.\n").foregroundStyle(.primary)
        + Text("Every day.").foregroundStyle(.secondary)
    }

    private func row(_ beat: Beat) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: beat.symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Nova.accent)
                .frame(width: Onboarding.iconTileSize, height: Onboarding.iconTileSize)
                .background {
                    RoundedRectangle(cornerRadius: Onboarding.iconTileRadius, style: .continuous)
                        .fill(Nova.accent.opacity(0.12))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(beat.title)
                    .font(.headline)
                Text(beat.detail)
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
    }
}

#Preview {
    RitualPage()
        .padding(.horizontal, Nova.screenPadding)
}
