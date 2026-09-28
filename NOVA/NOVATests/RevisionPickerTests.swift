//
//  RevisionPickerTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Revision picker")
struct RevisionPickerTests {
    private func entry(_ id: String, lastCorrect: Bool, revised: Double?, answered: Double = 0) -> ArchivedAnswer {
        ArchivedAnswer(
            id: QuestionID(id),
            question: Question(id: QuestionID(id), storyID: StoryID(id), prompt: id, answers: ["a", "b"], correctAnswerIndex: 0),
            storyTitle: id, source: "S", category: .india, day: "2026-09-28",
            answeredAt: Date(timeIntervalSince1970: answered), firstAttemptCorrect: lastCorrect,
            lastCorrect: lastCorrect, revisionCount: revised == nil ? 0 : 1,
            lastRevisedAt: revised.map(Date.init(timeIntervalSince1970:))
        )
    }

    @Test("Wrong answers come first, then the least recently revised")
    func order() {
        let picked = RevisionPicker.pick(from: [
            entry("right-old", lastCorrect: true, revised: 10),
            entry("wrong", lastCorrect: false, revised: 500),
            entry("right-never", lastCorrect: true, revised: nil, answered: 5)
        ])

        #expect(picked.map(\.id.rawValue) == ["wrong", "right-never", "right-old"])
    }

    @Test("Never more than the limit, and an empty archive gives an empty round")
    func limits() {
        let many = (0..<25).map { entry("e\($0)", lastCorrect: true, revised: Double($0)) }

        #expect(RevisionPicker.pick(from: many).count == RevisionPicker.size)
        #expect(RevisionPicker.pick(from: []).isEmpty)
        #expect(RevisionPicker.pick(from: Array(many.prefix(3))).count == 3)
    }
}
