//
//  RoundEngineTests.swift
//  NOVATests
//

import Testing
@testable import NOVA

@Suite("Round engine")
struct RoundEngineTests {

    // MARK: - Fixtures

    /// Every fixture question has four answers and the correct one at index 1.
    private static func question(_ number: Int) -> Question {
        Question(
            id: QuestionID("q\(number)"),
            storyID: StoryID("s\(number)"),
            prompt: "Question \(number)?",
            answers: ["A", "B", "C", "D"],
            correctAnswerIndex: 1
        )
    }

    private static let correctIndex = 1
    private static let wrongIndex = 2

    private static func makeEngine(questionCount: Int = 5) -> RoundEngine {
        let questions = (1...questionCount).map { question($0) }
        return RoundEngine(
            round: GameRound(
                id: RoundID("test-round"),
                storyIDs: questions.map(\.storyID),
                questionIDs: questions.map(\.id)
            ),
            questions: questions
        )
    }

    /// Answers the next `count` questions, alternating right and wrong as told.
    private static func answer(_ engine: inout RoundEngine, correctly: [Bool]) {
        for isCorrect in correctly {
            engine.submitAnswer(at: isCorrect ? correctIndex : wrongIndex)
            engine.advance()
        }
    }

    // MARK: - Scoring

    @Test("A correct answer increments the score")
    func correctAnswerIncrementsScore() {
        var engine = Self.makeEngine()

        let result = engine.submitAnswer(at: Self.correctIndex)

        #expect(result?.isCorrect == true)
        #expect(engine.score == RoundEngine.pointsPerCorrectAnswer)
        #expect(engine.correctAnswers == 1)
    }

    @Test("An incorrect answer does not increment the score")
    func incorrectAnswerDoesNotIncrementScore() {
        var engine = Self.makeEngine()

        let result = engine.submitAnswer(at: Self.wrongIndex)

        #expect(result?.isCorrect == false)
        #expect(engine.score == 0)
        #expect(engine.correctAnswers == 0)
        // It still counts as an answered question.
        #expect(engine.answeredCount == 1)
    }

    @Test("Score accumulates across the round")
    func scoreAccumulates() {
        var engine = Self.makeEngine()

        Self.answer(&engine, correctly: [true, false, true, true, false])

        #expect(engine.score == 3 * RoundEngine.pointsPerCorrectAnswer)
        #expect(engine.correctAnswers == 3)
    }

    // MARK: - Accuracy

    @Test("Accuracy is the share of answered questions that were correct")
    func accuracyUsesAnsweredQuestions() {
        var engine = Self.makeEngine()

        Self.answer(&engine, correctly: [true, false, true, true, false])

        #expect(engine.accuracy == 0.6)
    }

    @Test("Accuracy is zero before anything is answered")
    func accuracyStartsAtZero() {
        let engine = Self.makeEngine()

        #expect(engine.accuracy == 0)
    }

    @Test("Accuracy only counts what has been answered so far")
    func accuracyIgnoresUnansweredQuestions() {
        var engine = Self.makeEngine()

        Self.answer(&engine, correctly: [true, false])

        #expect(engine.accuracy == 0.5)
    }

    // MARK: - Progression

    @Test("The round completes after all five questions")
    func roundCompletesAfterFiveQuestions() {
        var engine = Self.makeEngine(questionCount: 5)

        Self.answer(&engine, correctly: [true, true, true, true])
        #expect(engine.isComplete == false)
        #expect(engine.currentQuestion != nil)

        Self.answer(&engine, correctly: [true])
        #expect(engine.isComplete == true)
        #expect(engine.currentQuestion == nil)
        #expect(engine.answeredCount == 5)
    }

    @Test("The current question only moves on after the result is acknowledged")
    func advanceRequiresAnAnswer() {
        var engine = Self.makeEngine()
        let first = engine.currentQuestion

        engine.advance()
        #expect(engine.currentQuestion == first)

        engine.submitAnswer(at: Self.correctIndex)
        #expect(engine.currentQuestion == first)

        engine.advance()
        #expect(engine.currentQuestion != first)
    }

    @Test("A second answer is ignored until the player has seen the result")
    func doubleSubmissionIsIgnored() {
        var engine = Self.makeEngine()

        engine.submitAnswer(at: Self.correctIndex)
        let second = engine.submitAnswer(at: Self.correctIndex)

        #expect(second == nil)
        #expect(engine.score == RoundEngine.pointsPerCorrectAnswer)
        #expect(engine.answeredCount == 1)
    }

    @Test("An answer outside the available options is rejected")
    func outOfRangeAnswerIsRejected() {
        var engine = Self.makeEngine()

        #expect(engine.submitAnswer(at: 9) == nil)
        #expect(engine.answeredCount == 0)
        #expect(engine.score == 0)
    }

    @Test("Answering past the end of the round does nothing")
    func answeringAfterCompletionDoesNothing() {
        var engine = Self.makeEngine()
        Self.answer(&engine, correctly: [true, true, true, true, true])

        #expect(engine.submitAnswer(at: Self.correctIndex) == nil)
        #expect(engine.answeredCount == 5)
        #expect(engine.score == 5 * RoundEngine.pointsPerCorrectAnswer)
    }

    @Test("Questions follow the order set by the round")
    func questionsFollowRoundOrder() {
        let questions = [Self.question(1), Self.question(2), Self.question(3)]
        let engine = RoundEngine(
            round: GameRound(
                id: RoundID("test-round"),
                storyIDs: questions.map(\.storyID),
                questionIDs: [QuestionID("q3"), QuestionID("q1"), QuestionID("q2")]
            ),
            questions: questions
        )

        #expect(engine.questions.map(\.id.rawValue) == ["q3", "q1", "q2"])
        #expect(engine.questionCount == 3)
    }
}
