//
//  RoundEngine.swift
//  NOVA
//

import Foundation

/// One answered question, kept so the results screen can review the round.
struct AnswerSubmission: Hashable, Sendable {
    let questionID: QuestionID
    let chosenAnswerIndex: Int
    let correctAnswerIndex: Int
    let isCorrect: Bool
    let pointsAwarded: Int
}

/// All of the round's rules: answer validation, scoring, accuracy and progression.
///
/// This is a plain value type with no SwiftUI and no knowledge of how the player
/// picks an answer, so it can be unit tested and survives changes to the game's
/// interaction.
struct RoundEngine {
    static let pointsPerCorrectAnswer = 100

    /// The round's questions, ordered by `round.questionIDs`.
    let questions: [Question]
    private(set) var round: GameRound
    private(set) var submissions: [AnswerSubmission] = []
    /// The result the player is currently being shown. `advance()` clears it.
    private(set) var pendingResult: AnswerSubmission?

    init(round: GameRound, questions: [Question]) {
        self.round = round
        self.questions = round.questionIDs.compactMap { id in
            questions.first { $0.id == id }
        }
    }

    var questionCount: Int { questions.count }

    var currentQuestion: Question? {
        guard questions.indices.contains(round.currentQuestionIndex) else { return nil }
        return questions[round.currentQuestionIndex]
    }

    /// 1-based position of the current question, for display.
    var currentQuestionNumber: Int {
        min(round.currentQuestionIndex + 1, questionCount)
    }

    var answeredCount: Int { submissions.count }
    var score: Int { round.score }
    var correctAnswers: Int { round.correctAnswers }
    var isComplete: Bool { answeredCount >= questionCount }

    /// Share of answered questions that were correct, from 0 to 1.
    var accuracy: Double {
        guard answeredCount > 0 else { return 0 }
        return Double(round.correctAnswers) / Double(answeredCount)
    }

    /// Validates an answer for the current question and updates the score.
    ///
    /// Returns `nil` when there is nothing to answer: the round is over, the index is
    /// out of range, or a previous result has not been acknowledged with `advance()`.
    @discardableResult
    mutating func submitAnswer(at answerIndex: Int) -> AnswerSubmission? {
        guard pendingResult == nil,
              let question = currentQuestion,
              question.answers.indices.contains(answerIndex)
        else { return nil }

        let isCorrect = question.isCorrect(answerIndex)
        let points = isCorrect ? Self.pointsPerCorrectAnswer : 0

        round.score += points
        if isCorrect { round.correctAnswers += 1 }

        let submission = AnswerSubmission(
            questionID: question.id,
            chosenAnswerIndex: answerIndex,
            correctAnswerIndex: question.correctAnswerIndex,
            isCorrect: isCorrect,
            pointsAwarded: points
        )
        submissions.append(submission)
        pendingResult = submission
        return submission
    }

    /// Moves on once the player has seen the feedback for their last shot.
    mutating func advance() {
        guard pendingResult != nil else { return }
        pendingResult = nil
        round.currentQuestionIndex += 1
    }
}
