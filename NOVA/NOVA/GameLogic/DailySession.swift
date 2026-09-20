//
//  DailySession.swift
//  NOVA
//

import Foundation
import Observation

/// Observable state for today's session: reading progress plus the current round.
///
/// Views read from this and send user actions to it; they never compute scores
/// themselves. A day will eventually hold three rounds — for now it holds one, and
/// `round` is the seam where the rest get added.
@Observable
final class DailySession {
    /// How far the live load has got. The reader sees a different screen for each, so
    /// this is what `StoryReaderView` switches on.
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed

        var isFailed: Bool { self == .failed }
    }

    private(set) var stories: [Story]
    private(set) var questions: [Question]

    private(set) var readStoryIDs: Set<StoryID> = []
    private(set) var engine: RoundEngine
    private(set) var loadState: LoadState = .idle
    /// The categories the reader asked to lead with, from onboarding.
    private(set) var topics = TopicSelection()

    /// The deck as it arrived, before any topic reordering.
    ///
    /// Kept because `applyTopics` runs on every launch and needs a stable base to sort
    /// from. Sorting the already-sorted `stories` would make the order depend on how many
    /// times it had been applied.
    private var loadedStories: [Story]

    private let roundID: RoundID

    init(
        stories: [Story] = MockNewsService.todayStories,
        questions: [Question] = MockNewsService.todayQuestions,
        roundID: RoundID = RoundID("round-1")
    ) {
        self.stories = stories
        self.loadedStories = stories
        self.questions = questions
        self.roundID = roundID
        self.engine = RoundEngine(
            round: GameRound(
                id: roundID,
                storyIDs: stories.map(\.id),
                questionIDs: questions.map(\.id)
            ),
            questions: questions
        )
    }

    // MARK: - Loading

    /// Replaces the deck with today's live stories.
    ///
    /// Keeps the existing deck on failure rather than emptying it — a reader who already
    /// has stories on screen should not lose them because a refresh timed out.
    func load(from service: NewsService) async {
        guard loadState != .loading else { return }
        loadState = .loading

        do {
            let deck = try await service.todayDeck()
            guard !deck.isEmpty else {
                loadState = .failed
                return
            }

            loadedStories = deck.map(\.story)
            questions = deck.compactMap(\.question)
            readStoryIDs = []
            stories = loadedStories.leading(with: topics)
            rebuildEngine()
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    /// A round covers only the stories that actually got a question. A story whose
    /// generation failed still reads in the deck, it just isn't asked about.
    private func rebuildEngine() {
        engine = RoundEngine(
            round: GameRound(
                id: roundID,
                storyIDs: questions.map(\.storyID),
                questionIDs: questions.map(\.id)
            ),
            questions: questions
        )
    }

    // MARK: - Topics

    /// Reorders today's deck so the reader's chosen categories come first.
    ///
    /// Nothing is dropped: the round needs all five stories, and the onboarding copy
    /// promises the reader still sees everything. Reading progress is left alone, since
    /// a story that has been read stays read wherever it lands in the deck.
    func applyTopics(_ selection: TopicSelection) {
        topics = selection
        // Reorders the deck that was actually loaded. This used to sort
        // `MockNewsService.todayStories`, which was invisible while the mock *was* the
        // deck — but `RootView` calls this on every launch, so once stories came from a
        // feed it would have thrown all five away and silently restored the demo content.
        stories = loadedStories.leading(with: selection)
    }

    // MARK: - Reading

    var storiesReadCount: Int { readStoryIDs.count }

    var hasReadAllStories: Bool {
        readStoryIDs.isSuperset(of: stories.map(\.id))
    }

    /// Where "Continue reading" should drop the player back in.
    var firstUnreadStoryIndex: Int {
        stories.firstIndex { !isRead($0) } ?? 0
    }

    func isRead(_ story: Story) -> Bool {
        readStoryIDs.contains(story.id)
    }

    func markRead(_ story: Story) {
        readStoryIDs.insert(story.id)
    }

    // MARK: - Round

    func story(for question: Question) -> Story? {
        stories.first { $0.id == question.storyID }
    }

    /// Position of a question's story in today's list, for the "Story 3" label.
    func storyNumber(for question: Question) -> Int? {
        stories.firstIndex { $0.id == question.storyID }.map { $0 + 1 }
    }

    func question(withID id: QuestionID) -> Question? {
        questions.first { $0.id == id }
    }

    @discardableResult
    func submitAnswer(at answerIndex: Int) -> AnswerSubmission? {
        engine.submitAnswer(at: answerIndex)
    }

    func advanceToNextQuestion() {
        engine.advance()
    }
}
