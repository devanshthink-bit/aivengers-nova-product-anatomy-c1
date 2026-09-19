//
//  WelcomeView.swift
//  NOVA
//

import SwiftUI

/// The first thing a new reader sees. One sentence, one size, one weight, two colours.
///
/// The screen is paper, not the reader's gradient: it should feel still, so the ripple
/// that follows the tap has something to disturb. The button is the drop point: tap it
/// and a ring of refraction runs up through the page, then the page gives way.
struct WelcomeView: View {
    var tuning = RippleWave.Tuning()
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The ring in flight, and when it started. Nil until the button is tapped.
    @State private var wave: RippleWave?
    @State private var dropTime: Date?
    @State private var isLeaving = false
    /// Frames in global space, so the button's centre can be expressed in the layer's
    /// own coordinates. The layer ignores the safe area and the bar does not, so the
    /// two do not share an origin.
    @State private var layerFrame: CGRect = .zero
    @State private var buttonCentre: CGPoint = .zero

    var body: some View {
        TimelineView(.animation(paused: wave == nil)) { timeline in
            let progress = wave.map { $0.progress(elapsed: timeline.date.timeIntervalSince(dropTime ?? timeline.date)) } ?? 0
            rippledPage(progress: progress)
        }
        .safeAreaBar(edge: .bottom) { callToAction }
        .sensoryFeedback(.impact(weight: .light), trigger: dropTime)
        #if DEBUG
        .task { await autoDropIfAsked() }
        #endif
    }

    // MARK: - Pieces

    /// The page with the ring over it. `isEnabled` keeps the shader entirely out of the
    /// pipeline while nothing is rippling.
    private func rippledPage(progress: Double) -> some View {
        page
            .background(backdrop)
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { layerFrame = $0 }
            .layerEffect(
                wave?.shader(at: progress) ?? RippleWave(origin: .zero, in: .zero).shader(at: 0),
                maxSampleOffset: wave?.maxSampleOffset ?? .zero,
                isEnabled: wave != nil
            )
    }

    /// Wordmark and copy.
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
        .safeAreaPadding()
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
            drop()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).center } action: { buttonCentre = $0 }
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

    // MARK: - The drop

    /// Starts the ring from the button, then hands over once it has cleared the screen.
    /// With Reduce Motion on there is no ring: the page simply gives way.
    private func drop() {
        guard !isLeaving else { return }
        isLeaving = true

        guard !reduceMotion else {
            onFinished()
            return
        }

        let origin = CGPoint(
            x: buttonCentre.x - layerFrame.minX,
            y: buttonCentre.y - layerFrame.minY
        )
        wave = RippleWave(origin: origin, in: layerFrame.size, tuning: tuning)
        dropTime = .now

        Task {
            try? await Task.sleep(for: .seconds(tuning.duration))
            onFinished()
        }
    }

    #if DEBUG
    /// `xcrun simctl launch … -welcomeAutoDrop YES` taps the button for us a second after
    /// the screen appears, so the ripple can be recorded without a finger.
    private func autoDropIfAsked() async {
        guard UserDefaults.standard.bool(forKey: "welcomeAutoDrop") else { return }
        try? await Task.sleep(for: .seconds(1))
        drop()
    }
    #endif
}

// MARK: - Previews

#Preview("Welcome") {
    WelcomeView { }
        .tint(Nova.accent)
}

/// Drag until the water feels right, then move the numbers into `RippleWave.Tuning`.
#Preview("Tuning") {
    @Previewable @State var duration = 0.9
    @Previewable @State var bandWidth: CGFloat = 110
    @Previewable @State var amplitude: CGFloat = 26
    @Previewable @State var highlight = 0.35
    @Previewable @State var generation = 0

    VStack(spacing: 0) {
        WelcomeView(
            tuning: RippleWave.Tuning(
                duration: duration,
                bandWidth: bandWidth,
                amplitude: amplitude,
                highlight: highlight
            )
        ) {
            // Bring the screen back so the drop can be tried again.
            generation += 1
        }
        .id(generation)
        .tint(Nova.accent)

        Grid(alignment: .leading, verticalSpacing: 6) {
            GridRow {
                Text("Duration \(duration, format: .number.precision(.fractionLength(2))) s")
                Slider(value: $duration, in: 0.3...2.0)
            }
            GridRow {
                Text("Band \(Int(bandWidth)) pt")
                Slider(value: $bandWidth, in: 30...260)
            }
            GridRow {
                Text("Bend \(Int(amplitude)) pt")
                Slider(value: $amplitude, in: 0...60)
            }
            GridRow {
                Text("Glow \(highlight, format: .number.precision(.fractionLength(2)))")
                Slider(value: $highlight, in: 0...1)
            }
        }
        .font(.caption.monospacedDigit())
        .padding()
        .background(.background.secondary)
    }
}
