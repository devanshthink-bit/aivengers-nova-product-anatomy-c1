//
//  StoryReaderView.swift
//  NOVA
//

import SwiftUI

/// The app's home: a deck of story cards, all the same size.
///
/// Swipe up and the card is thrown off while the one underneath rises into place. Swipe
/// down and the previous card slides back in from above. Swiping up past the last story
/// hands straight over to the quiz. There are no buttons for any of it.
struct StoryReaderView: View {
    /// How far the card must travel, as a fraction of screen height, to be let go of.
    private static let releaseFraction: CGFloat = 0.16
    /// A fast flick counts even if it didn't travel far.
    private static let flickFraction: CGFloat = 0.4
    /// Drag distance over which the card underneath finishes rising.
    private static let revealDistance: CGFloat = 220
    /// Every card fills the screen. Same size, edge to edge.
    /// How much of a sideways drag the card follows, and how much it tilts doing it.
    private static let sidewaysFollow: CGFloat = 0.35
    private static let tiltPerPoint: Double = 0.035

    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var topIndex = 0
    @State private var drag: CGSize = .zero
    @State private var showingIndex = false

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            switch session.loadState {
            case .loading:
                loadingState
            case .failed:
                failedState
            case .idle, .loaded:
                GeometryReader { proxy in
                    deck(in: proxy.size)
                }
                .ignoresSafeArea()

                progressOverlay
            }
        }
        .novaHiddenNavigationBar()
        .sheet(isPresented: $showingIndex) {
            TodayView { index in topIndex = index }
        }
        .task {
            topIndex = session.firstUnreadStoryIndex
            markCurrentStoryRead()
        }
        .onChange(of: topIndex) { markCurrentStoryRead() }
    }

    // MARK: - Load states

    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
            Text("Gathering today's stories")
                .font(Nova.display(.headline))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }

    private var failedState: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)

            Text("Today's stories didn't arrive")
                .font(Nova.display(.title3))

            Text("Check your connection and try again.")
                .font(Nova.reading(.subheadline))
                .foregroundStyle(.secondary)

            Button("Try again") {
                Task { await session.load(from: LiveNewsService()) }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
        .multilineTextAlignment(.center)
        .padding(40)
    }

    // MARK: - Deck

    private func deck(in size: CGSize) -> some View {
        let cardHeight = size.height

        // No GlassEffectContainer here on purpose. Inside a container the cards' glass
        // merges instead of each card sampling what's behind it, which let the next
        // card's text show through the top card at full sharpness.
        return ZStack {
            // The card underneath only exists while the top one is being thrown, so at
            // rest there is never a second card bleeding through the glass.
            if revealProgress > 0, let story = story(at: topIndex + 1) {
                card(story, at: topIndex + 1, size: size, cardHeight: cardHeight)
                    .scaleEffect(effects ? 0.9 + 0.1 * revealProgress : 1)
                    .offset(y: effects ? 70 * (1 - revealProgress) : 0)
                    .opacity(min(Double(revealProgress) * 1.6, 1))
                    .zIndex(0)
            }

            if let story = story(at: topIndex) {
                card(story, at: topIndex, size: size, cardHeight: cardHeight, isTop: true)
                    .scaleEffect(effects ? 1 - 0.03 * revealProgress : 1)
                    .rotationEffect(.degrees(tilt), anchor: .bottom)
                    .offset(x: drag.width * Self.sidewaysFollow, y: min(drag.height, 0))
                    .gesture(deckGesture(height: size.height))
                    .zIndex(1)
            }

            // The previous card, parked off the top edge until pulled back down.
            if drag.height > 0, let story = story(at: topIndex - 1) {
                card(story, at: topIndex - 1, size: size, cardHeight: cardHeight)
                    .offset(y: -previousTravel(in: size.height) + max(drag.height, 0))
                    .zIndex(2)
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func card(
        _ story: Story,
        at index: Int,
        size: CGSize,
        cardHeight: CGFloat,
        isTop: Bool = false
    ) -> some View {
        StoryCardView(
            story: story,
            position: index + 1,
            total: session.stories.count,
            onShowIndex: { showingIndex = true },
            onNext: { advance(height: size.height) }
        )
        .frame(width: size.width, height: cardHeight)
        .allowsHitTesting(isTop)
        .accessibilityHidden(!isTop)
    }

    // MARK: - Chrome

    private var backdrop: some View {
        NovaBackdrop(tint: story(at: topIndex)?.category.tint ?? Nova.accent)
            .animation(.smooth(duration: 0.5), value: topIndex)
    }

    private var progressOverlay: some View {
        VStack {
            ProgressPips(
                completed: session.storiesReadCount,
                total: session.stories.count,
                label: "stories read"
            )
            .safeAreaPadding(.top, 4)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Gesture

    private func deckGesture(height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                // Downward only has somewhere to go when there's a card above.
                let vertical = (value.translation.height > 0 && !hasPrevious)
                    ? value.translation.height * 0.18
                    : value.translation.height
                drag = CGSize(width: value.translation.width, height: vertical)
            }
            .onEnded { value in
                let travelled = value.translation.height
                let predicted = value.predictedEndTranslation.height
                let release = height * Self.releaseFraction
                let flick = height * Self.flickFraction

                if travelled < -release || predicted < -flick {
                    advance(height: height, throwVelocity: predicted - travelled)
                } else if hasPrevious, travelled > release || predicted > flick {
                    goBack(height: height)
                } else {
                    withAnimation(.snappy(duration: 0.3)) { drag = .zero }
                }
            }
    }

    /// Throws the top card clear of the screen, then commits to the next story.
    ///
    /// The card keeps drifting in whatever direction it was already going, and a harder
    /// flick throws it faster, so the release feels like letting go of something moving
    /// rather than triggering an animation.
    private func advance(height: CGFloat, throwVelocity: CGFloat = 0) {
        guard effects, height > 0 else {
            drag = .zero
            commitNext()
            return
        }

        // 0.34s for a gentle push, down to 0.2s for a hard flick.
        let duration = min(max(0.34 - Double(abs(throwVelocity)) / 3200, 0.2), 0.34)

        withAnimation(.easeOut(duration: duration)) {
            drag = CGSize(width: drag.width * 2.2, height: -(height * 1.35))
        } completion: {
            drag = .zero
            commitNext()
        }
    }

    private func goBack(height: CGFloat) {
        guard hasPrevious else { return }
        guard effects else {
            drag = .zero
            topIndex -= 1
            return
        }
        withAnimation(.easeOut(duration: 0.32)) {
            drag = CGSize(width: 0, height: previousTravel(in: height))
        } completion: {
            drag = .zero
            topIndex -= 1
        }
    }

    /// Reading all five is what unlocks the game, so the last swipe either starts the
    /// quiz or drops the reader back on whatever was skipped.
    private func commitNext() {
        if topIndex + 1 < session.stories.count {
            topIndex += 1
        } else if session.hasReadAllStories {
            router.replace(with: [.quizIntro])
        } else {
            topIndex = session.firstUnreadStoryIndex
        }
    }

    // MARK: - Derived state

    /// Animation flourishes are dropped when Reduce Motion is on; the deck still works.
    private var effects: Bool { !reduceMotion }

    private var revealProgress: CGFloat {
        min(max(-min(drag.height, 0) / Self.revealDistance, 0), 1)
    }

    private var tilt: Double {
        guard effects else { return 0 }
        return Double(drag.width) * Self.tiltPerPoint
    }

    private var hasPrevious: Bool { topIndex > 0 }

    private func previousTravel(in height: CGFloat) -> CGFloat {
        height + 60
    }

    private func story(at index: Int) -> Story? {
        session.stories.indices.contains(index) ? session.stories[index] : nil
    }

    private func markCurrentStoryRead() {
        guard let story = story(at: topIndex) else { return }
        session.markRead(story)
    }
}

#Preview {
    NavigationStack {
        StoryReaderView()
    }
    .environment(DailySession())
    .environment(AppRouter())
    .tint(Nova.accent)
}
