//
//  QuestionArchiveTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Question archive")
struct QuestionArchiveTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("archive-\(UUID().uuidString)")
            .appendingPathComponent("question-archive.json")
    }

    private func question(_ id: String, category: StoryCategory = .india) -> (Question, Story) {
        let story = Story(
            id: StoryID("s-\(id)"), title: "Title \(id)", summary: "", source: "Src",
            category: category, publishedAt: Date(timeIntervalSince1970: 1_800_000_000), artwork: .none
        )
        let question = Question(
            id: QuestionID(id), storyID: story.id, prompt: "Prompt \(id)?",
            answers: ["A", "B", "C", "D"], correctAnswerIndex: 1, explanation: "Why \(id)."
        )
        return (question, story)
    }

    @Test("Answers survive a relaunch")
    func persists() {
        let url = tempURL()
        let (q, s) = question("q1")
        QuestionArchive(fileURL: url).record(q, story: s, correct: true)

        let reopened = QuestionArchive(fileURL: url)

        #expect(reopened.entries.count == 1)
        #expect(reopened.entries[0].question.explanation == "Why q1.")
        #expect(reopened.entries[0].firstAttemptCorrect)
    }

    @Test("A question asked again keeps its first result")
    func duplicateAnswerKeepsFirst() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")

        archive.record(q, story: s, correct: false)
        archive.record(q, story: s, correct: true)

        #expect(archive.entries.count == 1)
        #expect(archive.entries[0].firstAttemptCorrect == false)
    }

    @Test("Revision updates the latest result but never the first")
    func revisionUpdates() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")
        archive.record(q, story: s, correct: false)

        archive.recordRevision(q.id, correct: true, at: Date(timeIntervalSince1970: 1_800_100_000))

        #expect(archive.entries[0].firstAttemptCorrect == false)
        #expect(archive.entries[0].lastCorrect)
        #expect(archive.entries[0].revisionCount == 1)
        #expect(archive.entries[0].lastRevisedAt != nil)
    }

    @Test("A corrupt file is set aside, not overwritten, and the archive starts empty")
    func corruptFileIsSetAside() throws {
        let url = tempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("{ not json".utf8).write(to: url)

        let archive = QuestionArchive(fileURL: url)

        #expect(archive.entries.isEmpty)
        #expect(FileManager.default.fileExists(atPath: url.appendingPathExtension("corrupt").path))
    }

    @Test("The archive keeps only the newest thousand")
    func capped() {
        let archive = QuestionArchive(fileURL: tempURL())
        for index in 0..<(QuestionArchive.capacity + 5) {
            let (q, s) = question("q\(index)")
            archive.record(q, story: s, correct: true, at: Date(timeIntervalSince1970: Double(1_800_000_000 + index)))
        }

        #expect(archive.entries.count == QuestionArchive.capacity)
        #expect(archive.entries.first?.id == QuestionID("q\(QuestionArchive.capacity + 4)"))
    }

    @Test("Accuracy is by first attempt, per category, and nil before any answer")
    func accuracy() {
        let archive = QuestionArchive(fileURL: tempURL())
        #expect(archive.accuracy == nil)

        let (a, sa) = question("a", category: .india)
        let (b, sb) = question("b", category: .india)
        let (c, sc) = question("c", category: .sports)
        archive.record(a, story: sa, correct: true)
        archive.record(b, story: sb, correct: false)
        archive.record(c, story: sc, correct: true)

        #expect(archive.accuracy == 2.0 / 3.0)
        let india = archive.accuracyByCategory.first { $0.category == .india }
        #expect(india?.correct == 1)
        #expect(india?.total == 2)
    }

    @Test("The revision sheet lists each question with its answer and context")
    func sheet() {
        let archive = QuestionArchive(fileURL: tempURL())
        let (q, s) = question("q1")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        archive.record(q, story: s, correct: true, at: now)

        let text = archive.revisionSheet(endingOn: now)

        #expect(text.contains("Prompt q1?"))
        #expect(text.contains("→ B"))
        #expect(text.contains("Why q1."))
    }
}
