//
//  WelcomeView.swift
//  NOVA
//

import SwiftUI

/// The first thing a new reader sees. One sentence, one size, one weight, two colours.
///
/// The screen is paper, not the reader's gradient: it should feel still, so the ripple
/// that follows the tap has something to disturb. The button is the drop point.
struct WelcomeView: View {
    var tuning = RippleWave.Tuning()
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isLeaving = false

    var body: some View {
        page
            .safeAreaBar(edge: .bottom) { callToAction }
            .background(backdrop.ignoresSafeArea())
    }

    // MARK: - Pieces

    /// Wordmark and copy. This is the layer the ripple runs over in Task 4.
    private var page: some View {
        VStack(alignment: .leading, spacing: 28) {
            Label("NOVA", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            copy
                .font(.system(.largeTitle, design: .default, weight: .semibold))
                .tracking(-0.8)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var callToAction: some View {
        Button("Get started") {
            leave()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .disabled(isLeaving)
    }

    /// Near-white with a breath of the accent at the top. Inside the rippled layer so the
    /// shader always samples an opaque pixel.
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.background)
            LinearGradient(
                colors: [Nova.accent.opacity(0.07), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )
        }
    }

    // MARK: - Leaving

    private func leave() {
        guard !isLeaving else { return }
        isLeaving = true
        onFinished()
    }
}

#Preview("Welcome") {
    WelcomeView { }
        .tint(Nova.accent)
}
