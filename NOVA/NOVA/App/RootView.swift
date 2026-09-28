//
//  RootView.swift
//  NOVA
//

import SwiftUI

struct RootView: View {
    @State private var archive: QuestionArchive
    @State private var session: DailySession
    @State private var store = NewsStore()
    @State private var router = AppRouter()
    @State private var sound = SoundPlayer()
    @State private var history = PlayHistory()
    @State private var voice = VoiceAssistant()
    @State private var reminders = ReminderScheduler()
    @State private var showsVoicePanel = false

    @AppStorage("hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""
    @AppStorage(ContentLanguage.storageKey) private var languageRaw = ContentLanguage.preferred().rawValue
    /// The voice panel keeps its own choice; it only follows the news language when that
    /// changes, so a reader who picked the other chip keeps it across launches.
    @AppStorage("voiceLanguage") private var voiceLanguageRaw = VoiceLanguage.preferred().rawValue

    private var language: ContentLanguage { ContentLanguage(rawValue: languageRaw) ?? .english }

    /// The archive is made first because the session records into it: every answer, from
    /// either way of answering, lands in one place for the Prep tab.
    init() {
        let archive = QuestionArchive()
        _archive = State(initialValue: archive)
        _session = State(initialValue: DailySession(archive: archive))
    }

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
                                .novaHiddenTabBar()
                            }
                    }
                }

                Tab("Prep", systemImage: "graduationcap", value: AppTab.prep) {
                    NavigationStack {
                        PrepView()
                    }
                }

                Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                    NavigationStack {
                        ProfileView()
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
                // Onboarding is charcoal and covers the whole window, so it can take the
                // dark appearance outright — status bar included — without the paper
                // underneath ever being seen in it.
                .preferredColorScheme(.dark)
                .transition(.opacity)
                .zIndex(1)
            }
        }
        // Written before the `.environment` calls so the sheet sits inside them. A sheet
        // presents its own hierarchy, and it only inherits what was injected above the
        // point it's attached. Attached after the injections, the panel would crash
        // looking for `VoiceAssistant`.
        .overlay(alignment: .bottomTrailing) {
            if showsVoiceFloater {
                VoiceFloater { showsVoicePanel = true }
                    .padding(.trailing, Nova.screenPadding)
                    // Clears the floating tab bar.
                    .padding(.bottom, 72)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(isPresented: $showsVoicePanel) {
            VoiceBriefingPanel()
        }
        .environment(session)
        .environment(store)
        .environment(router)
        .environment(sound)
        .environment(history)
        .environment(voice)
        .environment(archive)
        .environment(reminders)
        .tint(Nova.accent)
        .onChange(of: languageRaw) { voiceLanguageRaw = language.voice.rawValue }
        // Also on every later launch, not just the one that finished onboarding —
        // otherwise a stored preference silently stops applying the next morning.
        //
        // Topics are applied first so the ordering is already in place when the deck
        // lands, and `load` re-applies them itself once the stories arrive.
        // One network pass for both tabs: the store reads every feed, then the round
        // is built from those same stories instead of fetching them again.
        //
        // Keyed on the news language, so choosing the other one in Profile or onboarding
        // reloads Home and rebuilds the day's deck in it.
        .task(id: languageRaw) {
            session.applyTopics(TopicSelection(rawValue: pickedTopicsRaw))
            await store.setLanguage(language)
            #if DEBUG
            // `-previewDeck YES`: the hand-written deck, whose questions always exist, so
            // the round can be exercised on a day the question service is down.
            if UserDefaults.standard.bool(forKey: "previewDeck") {
                await session.load(from: PreviewNewsService())
            } else {
                await session.load(from: liveService)
            }
            #else
            await session.load(from: liveService)
            #endif
            #if DEBUG
            simulateRoundIfAsked()
            // `-openVoice YES` opens the briefing on launch. Synthetic taps aren't available
            // from a shell, so this is the only way to screenshot the panel. Read-only, like
            // the other arguments.
            if UserDefaults.standard.bool(forKey: "openVoice") { showsVoicePanel = true }
            #endif
            // Tops the week of reminders back up, in the news language, skipping today if
            // it's already played. A no-op while reminders are off.
            await reminders.refresh(todayDone: history.hasPlayed(on: .now), language: language)
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

    private var liveService: LiveNewsService {
        LiveNewsService(
            loader: FeedLoader(language: language),
            generator: QuestionGenerator(language: language),
            prefetched: store.allStories,
            topics: TopicSelection(rawValue: pickedTopicsRaw)
        )
    }

    /// The mic stays off the charcoal round: the slingshot is aimed near the bottom edge,
    /// where the button would sit. It also waits for onboarding to finish.
    private var showsVoiceFloater: Bool {
        hasSeenWelcome && !(router.tab == .scroll && !router.path.isEmpty)
    }

    #if DEBUG
    /// `-simulateRound N` reads the whole deck and answers the first N questions right and
    /// the rest wrong, so the mosaic, the flood and the results can be screenshotted.
    /// Read-only like the other arguments: it changes the session, never the defaults.
    private func simulateRoundIfAsked() {
        guard UserDefaults.standard.object(forKey: "simulateRound") != nil else { return }
        let correct = UserDefaults.standard.integer(forKey: "simulateRound")
        session.stories.forEach(session.markRead)
        var answered = 0
        while let question = session.engine.currentQuestion {
            let right = question.correctAnswerIndex
            let wrong = question.answers.indices.first { $0 != right } ?? right
            session.submitAnswer(at: answered < correct ? right : wrong)
            session.advanceToNextQuestion()
            answered += 1
        }
    }

    /// Forgets everything onboarding stored and starts the journey over.
    private func restartOnboarding() {
        OnboardingReset.run(session: session, router: router)
    }
    #endif
}

#Preview {
    RootView()
}
