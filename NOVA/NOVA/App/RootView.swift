//
//  RootView.swift
//  NOVA
//

import SwiftUI

struct RootView: View {
    @State private var session = DailySession()
    @State private var store = NewsStore()
    @State private var router = AppRouter()
    @State private var sound = SoundPlayer()

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("readerName") private var readerName = ""
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""

    var body: some View {
        ZStack {
            @Bindable var router = router

            // Native TabView on purpose: on this deployment target it already renders as
            // a floating glass bar. Hand-rolling a pill would be the parallel glass
            // system the design system exists to avoid.
            TabView(selection: $router.tab) {
                Tab("Home", systemImage: "square.grid.2x2", value: AppTab.home) {
                    NavigationStack(path: $router.homePath) {
                        HomeView()
                            .navigationDestination(for: HomeRoute.self) { route in
                                switch route {
                                case .source(let name):
                                    SourceView(source: name)
                                case .story(let id):
                                    StoryDetailView(storyID: id)
                                }
                            }
                    }
                }

                Tab("Scroll", systemImage: "rectangle.stack", value: AppTab.scroll) {
                    NavigationStack(path: $router.path) {
                        StoryReaderView()
                            .navigationDestination(for: Route.self) { route in
                                Group {
                                    switch route {
                                    case .quizIntro:
                                        QuizIntroView()
                                    case .quiz:
                                        QuizView()
                                    case .results:
                                        ResultsView()
                                    }
                                }
                                // A round owns the screen. The shot is aimed near the
                                // bottom edge, so a floating tab bar would sit directly
                                // under the slingshot and steal the drag.
                                .toolbar(.hidden, for: .tabBar)
                            }
                    }
                }
            }

            // Not a route: like the reader it isn't navigated to, and nothing may swipe
            // back into it. It sits over the stack until the last ripple has finished.
            if !hasSeenWelcome {
                OnboardingFlow {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenWelcome = true
                    }
                    // The deck only reorders once the reader has actually chosen.
                    session.applyTopics(TopicSelection(rawValue: pickedTopicsRaw))
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(session)
        .environment(store)
        .environment(router)
        .environment(sound)
        .tint(Nova.accent)
        // Also on every later launch, not just the one that finished onboarding —
        // otherwise a stored preference silently stops applying the next morning.
        //
        // Topics are applied first so the ordering is already in place when the deck
        // lands, and `load` re-applies them itself once the stories arrive.
        // One network pass for both tabs: the store reads all nine feeds, then the round
        // is built from those same stories instead of fetching them again.
        .task {
            session.applyTopics(TopicSelection(rawValue: pickedTopicsRaw))
            await store.load()
            await session.load(from: LiveNewsService(prefetched: store.allStories))
        }
        #if DEBUG
        // Only over the deck. Home has a navigation bar now, and the button sat on top
        // of its title.
        .overlay(alignment: .topLeading) {
            if router.tab == .scroll {
                DebugRestartButton(action: restartOnboarding)
                    .zIndex(2)
            }
        }
        #endif
    }

    #if DEBUG
    /// Forgets everything onboarding stored and starts the journey over.
    private func restartOnboarding() {
        readerName = ""
        pickedTopicsRaw = ""
        session.applyTopics(TopicSelection())
        router.popToReader()
        withAnimation(.easeInOut(duration: 0.3)) {
            hasSeenWelcome = false
        }
    }
    #endif
}

#Preview {
    RootView()
}
