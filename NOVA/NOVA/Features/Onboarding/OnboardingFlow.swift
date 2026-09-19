//
//  OnboardingFlow.swift
//  NOVA
//

import SwiftUI

/// The five pages, and the water that carries each one to the next.
///
/// The flow owns the ripple so it belongs to every transition rather than to one screen.
/// Tapping the button drops a ring at its centre; the page underneath swaps at 45 % of
/// the ring's life, behind the wavefront, so the water reveals the next page instead of
/// the page changing once the water has gone.
struct OnboardingFlow: View {
    let onFinished: () -> Void

    @AppStorage("readerName") private var readerName = ""
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var page: OnboardingPage = .manifesto
    @State private var isAdvancing = false

    /// The ring in flight, and when it started. Nil between transitions.
    @State private var wave: RippleWave?
    @State private var dropTime: Date?
    /// Frames in global space: the rippled layer ignores the safe area and the button's
    /// bar does not, so the drop point has to be converted between them.
    @State private var layerFrame: CGRect = .zero
    @State private var buttonCentre: CGPoint = .zero

    private var selection: Binding<TopicSelection> {
        Binding(
            get: { TopicSelection(rawValue: pickedTopicsRaw) },
            set: { pickedTopicsRaw = $0.rawValue }
        )
    }

    var body: some View {
        // The inset is read here and passed down as a value. Measuring it into `@State`
        // instead feeds the page's own layout back into the measurement that produced it,
        // and that loop stalls the render — the tallest page came up entirely blank.
        GeometryReader { proxy in
            TimelineView(.animation(paused: wave == nil)) { timeline in
                let progress = wave.map {
                    $0.progress(elapsed: timeline.date.timeIntervalSince(dropTime ?? timeline.date))
                } ?? 0

                rippledPage(progress: progress, topInset: proxy.safeAreaInsets.top)
            }
        }
        .safeAreaBar(edge: .bottom) { callToAction }
        .sensoryFeedback(.impact(weight: .light), trigger: dropTime)
        #if DEBUG
        .onAppear(perform: jumpToRequestedPage)
        .task { await autoPlayIfAsked() }
        #endif
    }

    #if DEBUG
    /// `xcrun simctl launch … -onboardingPage 4` opens straight onto that page, so a
    /// single screen can be iterated on without walking the whole journey each time.
    /// Reading a launch argument is safe; writing one back is not, which is why the
    /// restart button exists instead of a `-hasSeenWelcome` flag.
    private func jumpToRequestedPage() {
        let requested = UserDefaults.standard.integer(forKey: "onboardingPage")
        guard requested > 0, let target = OnboardingPage(rawValue: requested - 1) else { return }
        page = target
    }

    /// `xcrun simctl launch … -onboardingAutoPlay YES` walks the whole journey on its own,
    /// so the transitions can be recorded without a finger. Synthetic taps are not
    /// available from a shell, and the ripple between pages is the part worth watching.
    private func autoPlayIfAsked() async {
        guard UserDefaults.standard.bool(forKey: "onboardingAutoPlay") else { return }

        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1.3))

            // The topics page holds the flow until its minimum is met, so meet it.
            if page == .topics {
                var picks = TopicSelection(rawValue: pickedTopicsRaw)
                while !picks.isComplete, let next = StoryCategory.allCases.first(where: { !picks.contains($0) }) {
                    withAnimation(.snappy(duration: 0.28)) { picks.toggle(next) }
                    pickedTopicsRaw = picks.rawValue
                    try? await Task.sleep(for: .seconds(0.45))
                }
            }

            let wasLast = page.isLast
            advance()
            guard !wasLast else { return }

            try? await Task.sleep(for: .seconds(1.0))
        }
    }
    #endif

    // MARK: - Page

    /// The page with the ring over it. `isEnabled` keeps the shader out of the pipeline
    /// entirely while nothing is rippling.
    private func rippledPage(progress: Double, topInset: CGFloat) -> some View {
        pageBody(topInset: topInset)
            .background(backdrop)
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { layerFrame = $0 }
            .layerEffect(
                wave?.shader(at: progress) ?? RippleWave(origin: .zero, in: .zero).shader(at: 0),
                maxSampleOffset: wave?.maxSampleOffset ?? .zero,
                isEnabled: wave != nil
            )
    }

    private func pageBody(topInset: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: Onboarding.headlineTopSpace) {
            header

            Group {
                switch page {
                case .manifesto:
                    ManifestoPage()
                case .ritual:
                    RitualPage()
                case .name:
                    NamePage(name: $readerName)
                case .topics:
                    TopicsPage(selection: selection)
                case .ready:
                    ReadyPage(name: readerName, selection: selection.wrappedValue)
                }
            }
            // A fresh identity per page so each one runs its own entry stagger.
            .id(page)
            .transition(.opacity)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.top, topInset)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack {
            Label("NOVA", systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            OnboardingProgress(current: page)
        }
        .padding(.top, 8)
    }

    /// Near-white with a breath of the accent at the top. Inside the rippled layer so the
    /// shader always has an opaque pixel to sample.
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

    // MARK: - Button

    private var callToAction: some View {
        Button(buttonTitle) {
            advance()
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).center } action: { buttonCentre = $0 }
        .disabled(isAdvancing || !canAdvance)
        .animation(.smooth(duration: 0.3), value: canAdvance)
    }

    private var buttonTitle: String {
        switch page {
        case .manifesto: "Get started"
        case .ritual: "Sounds good"
        case .name: readerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Skip for now" : "Continue"
        case .topics: "Continue"
        case .ready: "Start reading"
        }
    }

    /// Only the topics page can hold the flow back, and only until its minimum is met.
    private var canAdvance: Bool {
        switch page {
        case .topics: selection.wrappedValue.isComplete
        default: true
        }
    }

    // MARK: - Advancing

    private func advance() {
        guard !isAdvancing, canAdvance else { return }
        isAdvancing = true

        let next = page.next
        let tuning: RippleWave.Tuning = next == nil ? .finale : .page

        guard !reduceMotion else {
            withAnimation(.easeInOut(duration: 0.3)) {
                if let next { page = next } else { onFinished() }
            }
            isAdvancing = false
            return
        }

        let origin = CGPoint(
            x: buttonCentre.x - layerFrame.minX,
            y: buttonCentre.y - layerFrame.minY
        )
        wave = RippleWave(origin: origin, in: layerFrame.size, tuning: tuning)
        dropTime = .now

        Task {
            guard let next else {
                // The finale runs its full length before the reader takes over.
                try? await Task.sleep(for: .seconds(tuning.duration))
                onFinished()
                return
            }

            // Swap behind the wavefront, so the water reveals the next page.
            try? await Task.sleep(for: .seconds(tuning.duration * 0.45))
            withAnimation(.easeInOut(duration: 0.28)) { page = next }

            try? await Task.sleep(for: .seconds(tuning.duration * 0.55))
            wave = nil
            dropTime = nil
            isAdvancing = false
        }
    }
}

// MARK: - Previews

#Preview("Flow") {
    OnboardingFlow { }
        .tint(Nova.accent)
}

/// Drag until the water feels right, then move the numbers into `RippleWave.Tuning`.
#Preview("Ripple tuning") {
    @Previewable @State var duration = 0.7
    @Previewable @State var bandWidth: CGFloat = 96
    @Previewable @State var amplitude: CGFloat = 22
    @Previewable @State var highlight = 0.30

    VStack(spacing: 0) {
        OnboardingFlow { }
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
