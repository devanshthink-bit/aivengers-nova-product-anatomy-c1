//
//  Question.swift
//  NOVA
//

import Foundation

struct Question: Identifiable, Codable, Hashable, Sendable {
    let id: QuestionID
    let storyID: StoryID
    let prompt: String
    /// Answer options in display order.
    ///
    /// The count is deliberately not fixed at four. Today the quiz renders one basket
    /// per answer, but the answer interaction is expected to change, so the shape of
    /// the interaction does not belong in the model.
    let answers: [String]
    let correctAnswerIndex: Int

    var correctAnswer: String {
        answers.indices.contains(correctAnswerIndex) ? answers[correctAnswerIndex] : ""
    }

    func isCorrect(_ answerIndex: Int) -> Bool {
        answerIndex == correctAnswerIndex
    }
}
