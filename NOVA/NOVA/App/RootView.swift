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
            // back into it. It sits over the stack until the ripple has finished.
            if !hasSeenWelcome {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenWelcome = true
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .environment(session)
        .environment(router)
        .environment(sound)
        .tint(Nova.accent)
    }
}

#Preview {
    RootView()
}
