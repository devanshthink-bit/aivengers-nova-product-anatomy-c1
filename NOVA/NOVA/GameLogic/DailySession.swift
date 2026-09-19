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
    private(set) var stories: [Story]
    let questions: [Question]

    private(set) var readStoryIDs: Set<StoryID> = []
    private(set) var engine: RoundEngine
    /// The categories the reader asked to lead with, from onboarding.
    private(set) var topics = TopicSelection()

    init(
        stories: [Story] = MockNewsService.todayStories,
        questions: [Question] = MockNewsService.todayQuestions,
        roundID: RoundID = RoundID("round-1")
    ) {
        self.stories = stories
        self.questions = questions
        self.engine = RoundEngine(
            round: GameRound(
                id: roundID,
                storyIDs: stories.map(\.id),
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
        stories = MockNewsService.todayStories.leading(with: selection)
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
