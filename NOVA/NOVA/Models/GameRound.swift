//
//  GameRound.swift
//  NOVA
//

import Foundation

/// A single round: the stories the player reads and the questions they then answer.
/// A day is made of several of these, though the first build only ships one.
struct GameRound: Identifiable, Codable, Hashable, Sendable {
    let id: RoundID
    let storyIDs: [StoryID]
    let questionIDs: [QuestionID]
    var currentQuestionIndex: Int
    var score: Int
    var correctAnswers: Int

    init(
        id: RoundID,
        storyIDs: [StoryID],
        questionIDs: [QuestionID],
        currentQuestionIndex: Int = 0,
        score: Int = 0,
        correctAnswers: Int = 0
    ) {
        self.id = id
        self.storyIDs = storyIDs
        self.questionIDs = questionIDs
        self.currentQuestionIndex = currentQuestionIndex
        self.score = score
        self.correctAnswers = correctAnswers
    }
}
