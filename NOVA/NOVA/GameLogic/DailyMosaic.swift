//
//  DailyMosaic.swift
//  NOVA
//

import Foundation

/// What a day of reading builds: an asterisk drawn in pixels, one colour per story.
///
/// This stands in for the sculpture (Not Boring) Habits grows a piece at a time. A 3D
/// object would need a renderer and an artist for every stage; a pixel glyph is squares,
/// can be tested like the round engine, and already speaks Artifact's visual language.
///
/// Every story owns an equal share of the squares, spread around the glyph rather than
/// clumped in one arm, so one correct answer visibly lights the whole shape a little
/// instead of finishing one corner.
struct DailyMosaic: Equatable {
    /// How far one story has got today.
    enum Progress: Equatable, Sendable {
        case unread
        case read
        case correct
        case missed
    }

    struct Cell: Equatable, Identifiable, Sendable {
        let row: Int
        let column: Int
        /// Which story owns this square, as an index into the day's stories.
        let story: Int
        /// Position in the fill order, centre first. Drives the stagger when squares land.
        let order: Int
        let progress: Progress

        var id: Int { row * 100 + column }
    }

    static let size = 7

    let cells: [Cell]

    /// - Parameter progress: one entry per story, in deck order.
    init(progress: [Progress]) {
        let shape = Self.glyph
        guard !progress.isEmpty else {
            cells = shape.enumerated().map { order, point in
                Cell(row: point.row, column: point.column, story: 0, order: order, progress: .unread)
            }
            return
        }

        cells = shape.enumerated().map { order, point in
            let story = order % progress.count
            return Cell(row: point.row, column: point.column, story: story, order: order, progress: progress[story])
        }
    }

    /// Squares earned by a correct answer.
    var earnedCount: Int { cells.filter { $0.progress == .correct }.count }

    /// True once every story has been answered correctly.
    var isComplete: Bool { !cells.isEmpty && cells.allSatisfy { $0.progress == .correct } }

    // MARK: - Shape

    /// The asterisk's squares, centre first, then ring by ring outward and clockwise within
    /// a ring. Ring order is what spreads each story's share across all four arms.
    static let glyph: [(row: Int, column: Int)] = {
        let middle = size / 2
        var points: [(row: Int, column: Int)] = []
        for row in 0..<size {
            for column in 0..<size {
                let onCross = row == middle || column == middle
                let onDiagonal = row == column || row + column == size - 1
                if onCross || onDiagonal { points.append((row, column)) }
            }
        }

        func ring(_ point: (row: Int, column: Int)) -> Int {
            max(abs(point.row - middle), abs(point.column - middle))
        }

        func angle(_ point: (row: Int, column: Int)) -> Double {
            atan2(Double(point.row - middle), Double(point.column - middle))
        }

        return points.sorted { lhs, rhs in
            ring(lhs) != ring(rhs) ? ring(lhs) < ring(rhs) : angle(lhs) < angle(rhs)
        }
    }()
}

extension DailySession {
    /// Today's mosaic, as far as the reader has got.
    ///
    /// A story only earns its colour through a correct answer. Reading it lays down the
    /// outline, so the glyph visibly fills in as the deck is read and then again, solidly,
    /// as the shots go in.
    var mosaic: DailyMosaic {
        let outcomes = Dictionary(
            engine.submissions.compactMap { submission in
                question(withID: submission.questionID).map { ($0.storyID, submission.isCorrect) }
            },
            uniquingKeysWith: { _, latest in latest }
        )

        return DailyMosaic(progress: stories.map { story in
            if let correct = outcomes[story.id] { return correct ? .correct : .missed }
            return isRead(story) ? .read : .unread
        })
    }
}
