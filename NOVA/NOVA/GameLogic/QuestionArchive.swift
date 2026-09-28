//
//  QuestionArchive.swift
//  NOVA
//

import Foundation
import Observation

/// One answered question, kept for revision.
struct ArchivedAnswer: Codable, Identifiable, Hashable, Sendable {
    let id: QuestionID
    let question: Question
    let storyTitle: String
    let source: String
    let category: StoryCategory
    /// The reader's calendar day, "2026-09-28" — the same key `PlayHistory` uses.
    let day: String
    let answeredAt: Date
    /// The daily round's result. Accuracy is measured on this, so revising can't
    /// retroactively improve a score the reader didn't earn on the day.
    let firstAttemptCorrect: Bool
    var lastCorrect: Bool
    var revisionCount: Int
    var lastRevisedAt: Date?
}

/// Every question the reader has answered, newest first, saved as JSON on the device.
///
/// No account and no sync on purpose: the branch that added it had to stay free, and a
/// file in Application Support is the one store that costs nothing and asks for nothing.
/// Revision is recorded here and nowhere else — it never touches `PlayHistory`, because a
/// streak counts days the reader did the daily round, and revising isn't that.
@Observable
final class QuestionArchive {
    static let capacity = 1000

    static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("NOVA", isDirectory: true)
            .appendingPathComponent("question-archive.json")
    }

    private(set) var entries: [ArchivedAnswer] = []

    private let fileURL: URL
    private let calendar: Calendar

    init(fileURL: URL = QuestionArchive.defaultURL, calendar: Calendar = .current) {
        self.fileURL = fileURL
        self.calendar = calendar
        load()
    }

    // MARK: - Recording

    /// Keeps the first attempt only. The round isn't persisted, so after a relaunch the
    /// same questions come back — re-answering one must not overwrite how it went the
    /// first time.
    func record(_ question: Question, story: Story, correct: Bool, at date: Date = .now) {
        guard !entries.contains(where: { $0.id == question.id }) else { return }

        entries.insert(
            ArchivedAnswer(
                id: question.id,
                question: question,
                storyTitle: story.title,
                source: story.source,
                category: story.category,
                day: dayKey(for: date),
                answeredAt: date,
                firstAttemptCorrect: correct,
                lastCorrect: correct,
                revisionCount: 0,
                lastRevisedAt: nil
            ),
            at: 0
        )
        if entries.count > Self.capacity {
            entries.removeLast(entries.count - Self.capacity)
        }
        save()
    }

    func recordRevision(_ id: QuestionID, correct: Bool, at date: Date = .now) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].lastCorrect = correct
        entries[index].revisionCount += 1
        entries[index].lastRevisedAt = date
        save()
    }

    // MARK: - Reading

    /// Share of first attempts that were right. Nil before anything is answered, so the
    /// Prep header shows a dash instead of a discouraging 0 %.
    var accuracy: Double? {
        guard !entries.isEmpty else { return nil }
        return Double(entries.filter(\.firstAttemptCorrect).count) / Double(entries.count)
    }

    /// How many questions still stand wrong, the last time they were answered.
    var dueCount: Int { entries.filter { !$0.lastCorrect }.count }

    var accuracyByCategory: [(category: StoryCategory, correct: Int, total: Int)] {
        StoryCategory.allCases.compactMap { category in
            let inCategory = entries.filter { $0.category == category }
            guard !inCategory.isEmpty else { return nil }
            return (category, inCategory.filter(\.firstAttemptCorrect).count, inCategory.count)
        }
    }

    /// The days of the week ending today that have answers, newest first.
    func week(endingOn today: Date = .now) -> [(day: Date, entries: [ArchivedAnswer])] {
        let start = calendar.startOfDay(for: today)
        return (0..<7).compactMap { back in
            guard let date = calendar.date(byAdding: .day, value: -back, to: start) else { return nil }
            let key = dayKey(for: date)
            let answers = entries.filter { $0.day == key }
            return answers.isEmpty ? nil : (date, answers)
        }
    }

    /// The week as plain text, the way exam aspirants pass notes around: question, answer,
    /// context. Labelled as machine-written, because it travels without the app around it.
    func revisionSheet(endingOn today: Date = .now) -> String {
        var lines = [String(localized: "NOVA · this week's questions")]
        for (date, answers) in week(endingOn: today) {
            lines.append("")
            lines.append(date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
            for answer in answers {
                lines.append("• \(answer.question.prompt)")
                lines.append("  → \(answer.question.correctAnswer)")
                if let why = answer.question.explanation {
                    lines.append("  \(why)")
                }
            }
        }
        lines.append("")
        lines.append(String(localized: "Machine-written from news feeds and not checked."))
        return lines.joined(separator: "\n")
    }

    // MARK: - Storage

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            entries = try JSONDecoder().decode([ArchivedAnswer].self, from: data)
        } catch {
            // Set the bad file aside rather than let the next save overwrite it: losing a
            // reader's revision history silently is worse than losing it loudly.
            let aside = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: fileURL, to: aside)
            entries = []
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            // Best effort, like SoundPlayer: a failed save costs revision history, never
            // the round in front of the reader.
        }
    }

    private func dayKey(for date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
