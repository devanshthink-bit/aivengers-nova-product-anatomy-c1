//
//  ShareGridTests.swift
//  NOVATests
//

import Foundation
import SwiftUI
import Testing
@testable import NOVA

@Suite("Share grid")
struct ShareGridTests {
    /// Noon UTC on 28 Sep 2026, so it is the 28th in every time zone the tests run in.
    private let date = Date(timeIntervalSince1970: 1_790_596_800)
    private let locale = Locale(identifier: "en_GB")

    @Test("One square per question, filled for correct, with the score and streak")
    func grid() {
        let text = ShareGrid.text(outcomes: [true, true, false, true, true], date: date, streak: 6, locale: locale)
        let lines = text.components(separatedBy: "\n")

        #expect(lines.count == 3)
        #expect(lines[0] == "NOVA · 28 Sep")
        #expect(lines[1] == "🟨🟨⬜🟨🟨 4/5")
        #expect(lines[2].contains("6"))
    }

    @Test("No streak line on a first day, and nothing invented")
    func noStreak() {
        let text = ShareGrid.text(outcomes: [false, true], date: date, streak: 0, locale: locale)

        #expect(text.components(separatedBy: "\n").count == 2)
        #expect(!text.contains("%"))
    }

    @MainActor
    @Test("The question card and the scorecard render to images")
    func renders() {
        let question = MockNewsService.todayQuestions[0]
        let card = ShareRenderer.image(of: QuestionShareCard(question: question, source: "Test"), size: ShareRenderer.cardSize)
        let score = ShareRenderer.image(
            of: ScorecardCard(mosaic: DailyMosaic(progress: [.correct, .missed]), tints: [.red, .blue],
                              correct: 1, total: 2, streak: 3, date: date),
            size: ShareRenderer.cardSize
        )

        #expect(card != nil)
        #expect(score != nil)
    }
}

@Suite("Story outcomes")
struct StoryOutcomeTests {
    @Test("Outcomes follow the deck's story order, one per answered question")
    func storyOrder() {
        let session = DailySession()
        var answered: [Bool] = []
        while let question = session.engine.currentQuestion, answered.count < 2 {
            let right = answered.isEmpty
            let wrong = question.answers.indices.first { $0 != question.correctAnswerIndex } ?? 0
            session.submitAnswer(at: right ? question.correctAnswerIndex : wrong)
            session.advanceToNextQuestion()
            answered.append(right)
        }

        #expect(session.storyOutcomes.count == 2)
        #expect(session.storyOutcomes.filter { $0 }.count == 1)
    }
}
