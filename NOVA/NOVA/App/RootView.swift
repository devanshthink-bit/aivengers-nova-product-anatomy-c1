//
//  RootView.swift
//  NOVA
//

import SwiftUI

struct RootView: View {
    @State private var session = DailySession()
    @State private var router = AppRouter()
    @State private var sound = SoundPlayer()

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("readerName") private var readerName = ""
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""

    var body: some View {
        ZStack {
            NavigationStack(path: $router.path) {
                StoryReaderView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .quizIntro:
                            QuizIntroView()
                        case .quiz:
                            QuizView()
                        case .results:
                            ResultsView()
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
        .environment(router)
        .environment(sound)
        .tint(Nova.accent)
        // Also on every later launch, not just the one that finished onboarding —
        // otherwise a stored preference silently stops applying the next morning.
        .task { session.applyTopics(TopicSelection(rawValue: pickedTopicsRaw)) }
        #if DEBUG
        .overlay(alignment: .topLeading) {
            DebugRestartButton(action: restartOnboarding)
                .zIndex(2)
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
