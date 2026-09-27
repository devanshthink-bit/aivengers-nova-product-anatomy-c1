//
//  DailyMosaicTests.swift
//  NOVATests
//

import Foundation
import Testing
@testable import NOVA

@Suite("Daily mosaic")
struct DailyMosaicTests {
    private static let five = Array(repeating: DailyMosaic.Progress.unread, count: 5)

    @Test("The glyph is a symmetric asterisk of 25 squares")
    func glyphShape() {
        let points = DailyMosaic.glyph
        #expect(points.count == 25)

        let set = Set(points.map { $0.row * 10 + $0.column })
        #expect(set.count == points.count, "no square appears twice")

        let last = DailyMosaic.size - 1
        for point in points {
            // Mirrored in both axes, so it reads as the same mark from any side.
            #expect(set.contains(point.row * 10 + (last - point.column)))
            #expect(set.contains((last - point.row) * 10 + point.column))
        }
    }

    @Test("The centre square fills first")
    func centreFirst() {
        let middle = DailyMosaic.size / 2
        #expect(DailyMosaic.glyph.first?.row == middle)
        #expect(DailyMosaic.glyph.first?.column == middle)
    }

    @Test("Five stories own five squares each")
    func equalShares() {
        let mosaic = DailyMosaic(progress: Self.five)
        for story in 0..<5 {
            #expect(mosaic.cells.filter { $0.story == story }.count == 5)
        }
    }

    @Test("Each story's share reaches every arm, not one corner")
    func sharesAreSpread() {
        let mosaic = DailyMosaic(progress: Self.five)
        let middle = DailyMosaic.size / 2
        for story in 1..<5 {
            let rings = Set(mosaic.cells.filter { $0.story == story }.map {
                max(abs($0.row - middle), abs($0.column - middle))
            })
            #expect(rings.count >= 2, "story \(story) sits in a single ring")
        }
    }

    @Test("Only a correct answer earns squares")
    func earning() {
        let mosaic = DailyMosaic(progress: [.correct, .missed, .read, .unread, .correct])
        #expect(mosaic.earnedCount == 10)
        #expect(!mosaic.isComplete)

        let perfect = DailyMosaic(progress: Array(repeating: .correct, count: 5))
        #expect(perfect.earnedCount == 25)
        #expect(perfect.isComplete)
    }

    @Test("An empty day still draws the outline")
    func noStories() {
        let mosaic = DailyMosaic(progress: [])
        #expect(mosaic.cells.count == 25)
        #expect(mosaic.cells.allSatisfy { $0.progress == .unread })
        #expect(!mosaic.isComplete)
    }

    @Test("A short deck still shares out every square")
    func fewerStories() {
        let mosaic = DailyMosaic(progress: [.correct, .unread, .unread])
        #expect(Set(mosaic.cells.map(\.story)) == [0, 1, 2])
        #expect(mosaic.earnedCount == 9)
    }

    @Test("A day with no questions has no round, rather than a finished one")
    func noRound() {
        let empty = DailySession(questions: [])
        #expect(!empty.hasRound)
        #expect(empty.engine.isComplete, "the engine alone would call this finished")
        #expect(DailySession().hasRound)
    }

    @Test("The session's mosaic follows reading and answers")
    func sessionMosaic() {
        let session = DailySession()
        #expect(session.mosaic.cells.allSatisfy { $0.progress == .unread })

        let first = session.stories[0]
        session.markRead(first)
        #expect(session.mosaic.cells.filter { $0.story == 0 }.allSatisfy { $0.progress == .read })

        let question = session.engine.currentQuestion!
        let story = session.stories.firstIndex { $0.id == question.storyID }!
        session.submitAnswer(at: question.correctAnswerIndex)
        #expect(session.mosaic.cells.filter { $0.story == story }.allSatisfy { $0.progress == .correct })
    }
}

@Suite("Play history")
struct PlayHistoryTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return calendar
    }

    private static func freshDefaults() -> UserDefaults {
        let name = "PlayHistoryTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private static func day(_ offset: Int, from date: Date = Date(timeIntervalSince1970: 1_790_000_000)) -> Date {
        calendar.date(byAdding: .day, value: offset, to: date)!
    }

    @Test("A recorded day survives a relaunch")
    func persists() {
        let defaults = Self.freshDefaults()
        PlayHistory(defaults: defaults, calendar: Self.calendar).record(Self.day(0))

        let reopened = PlayHistory(defaults: defaults, calendar: Self.calendar)
        #expect(reopened.hasPlayed(on: Self.day(0)))
        #expect(!reopened.hasPlayed(on: Self.day(-1)))
    }

    @Test("The week is seven days ending today")
    func week() {
        let history = PlayHistory(defaults: Self.freshDefaults(), calendar: Self.calendar)
        history.record(Self.day(-2))

        let week = history.week(endingOn: Self.day(0))
        #expect(week.count == 7)
        #expect(week.last?.isToday == true)
        #expect(week.filter(\.isToday).count == 1)
        #expect(week.map(\.played) == [false, false, false, false, true, false, false])
    }

    @Test("A streak counts back from yesterday until today is played")
    func streak() {
        let history = PlayHistory(defaults: Self.freshDefaults(), calendar: Self.calendar)
        history.record(Self.day(-1))
        history.record(Self.day(-2))
        history.record(Self.day(-4))

        #expect(history.streak(endingOn: Self.day(0)) == 2, "today not played yet: still a 2-day streak")

        history.record(Self.day(0))
        #expect(history.streak(endingOn: Self.day(0)) == 3)
    }

    @Test("No history means no streak")
    func emptyStreak() {
        let history = PlayHistory(defaults: Self.freshDefaults(), calendar: Self.calendar)
        #expect(history.streak(endingOn: Self.day(0)) == 0)
    }

    @Test("Recording the same day twice counts once")
    func idempotent() {
        let history = PlayHistory(defaults: Self.freshDefaults(), calendar: Self.calendar)
        history.record(Self.day(0))
        history.record(Self.day(0).addingTimeInterval(60))
        #expect(history.playedDays.count == 1)
    }
}
