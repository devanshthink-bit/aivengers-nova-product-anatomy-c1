//
//  RootView.swift
//  NOVA
//

import SwiftUI

struct RootView: View {
    @State private var session = DailySession()
    @State private var router = AppRouter()
    @State private var sound = SoundPlayer()

    var body: some View {
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
        .environment(session)
        .environment(router)
        .environment(sound)
        .tint(Nova.accent)
    }
}

#Preview {
    RootView()
}
