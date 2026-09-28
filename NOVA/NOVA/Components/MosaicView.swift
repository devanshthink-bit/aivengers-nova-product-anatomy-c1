//
//  MosaicView.swift
//  NOVA
//

import SwiftUI

/// Draws a `DailyMosaic`: the asterisk the day's reading builds.
///
/// Squares, not rounded tiles — Artifact's mosaic is pixels, and the moment the corners go
/// soft it starts to read as a grid of buttons. Colour follows the surface through
/// `.primary`, so the same view works on paper and on charcoal.
struct MosaicView: View {
    let mosaic: DailyMosaic
    /// One tint per story, in deck order.
    let tints: [Color]
    var cell: CGFloat = 14
    var gap: CGFloat = 3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let span = CGFloat(DailyMosaic.size) * cell + CGFloat(DailyMosaic.size - 1) * gap

        ZStack(alignment: .topLeading) {
            ForEach(mosaic.cells) { square in
                PixelSquare(progress: square.progress, tint: tint(for: square.story), size: cell)
                    .offset(
                        x: CGFloat(square.column) * (cell + gap),
                        y: CGFloat(square.row) * (cell + gap)
                    )
                    // Squares land centre-outward, a beat apart, so a correct answer is
                    // seen spreading through the glyph rather than switching on at once.
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.2) : Nova.Motion.pop.delay(Double(square.order) * 0.018),
                        value: square.progress
                    )
            }
        }
        .frame(width: span, height: span, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Today's mosaic")
        .accessibilityValue(accessibilityValue)
    }

    private func tint(for story: Int) -> Color {
        tints.indices.contains(story) ? tints[story] : .primary
    }

    private var accessibilityValue: String {
        let total = mosaic.cells.count
        return String(localized: "\(mosaic.earnedCount) of \(total) squares earned")
    }
}

/// One square of the mosaic, in each of the four states a story can be in.
private struct PixelSquare: View {
    let progress: DailyMosaic.Progress
    let tint: Color
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)

        ZStack {
            switch progress {
            case .unread:
                shape.fill(.primary.opacity(0.07))
            case .read:
                // An outline only: the story has been read, the square hasn't been won.
                shape.fill(tint.opacity(0.14))
                shape.strokeBorder(tint.opacity(0.7), lineWidth: max(size * 0.1, 1))
            case .missed:
                shape.strokeBorder(.primary.opacity(0.22), lineWidth: max(size * 0.08, 1))
            case .correct:
                shape.fill(tint)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(progress == .correct ? 1 : 0.86)
    }
}

// MARK: - Decorative mosaic

/// The loose pixels Artifact scatters across its welcome screen, in NOVA's own palette.
///
/// Fixed positions, not random: the arrangement is composed, and a random scatter would
/// land squares on top of the headline on some launches.
struct PixelScatter: View {
    var unit: CGFloat = 30

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false

    private struct Square {
        let x: CGFloat
        let y: CGFloat
        let color: Color
    }

    private let squares: [Square] = [
        Square(x: 5.4, y: 0.0, color: Nova.mosaicSky),
        Square(x: 1.4, y: 1.4, color: Nova.mosaicVermilion),
        Square(x: 0.4, y: 2.4, color: Nova.mosaicSky),
        Square(x: 2.4, y: 2.4, color: Nova.mosaicSky),
        Square(x: 3.4, y: 2.4, color: Nova.mosaicSky),
        Square(x: 4.4, y: 2.4, color: Nova.mosaicSky),
        Square(x: 2.4, y: 3.4, color: Nova.mosaicSky),
        Square(x: 5.4, y: 3.4, color: Nova.mosaicNavy),
        Square(x: 7.2, y: 4.6, color: Nova.marigold),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(squares.indices, id: \.self) { index in
                let square = squares[index]
                Rectangle()
                    .fill(square.color)
                    .frame(width: unit, height: unit)
                    // Each square tumbles into its slot, the way the Habits onboarding
                    // objects fall in. Under Reduce Motion they are simply there.
                    // Rotation before offset, so each square turns about its own centre.
                    .rotationEffect(.degrees(landed || reduceMotion ? 0 : Double(index % 2 == 0 ? -24 : 18)))
                    .offset(y: landed || reduceMotion ? 0 : -unit * 2.2)
                    .offset(x: square.x * unit, y: square.y * unit)
                    .opacity(landed ? 1 : 0)
                    .animation(
                        reduceMotion ? .easeOut(duration: 0.3) : Nova.Motion.pop.delay(0.12 + Double(index) * 0.06),
                        value: landed
                    )
            }

            AsteriskMark()
                .fill(.primary)
                .frame(width: unit * 1.5, height: unit * 1.5)
                .rotationEffect(.degrees(landed || reduceMotion ? 0 : -90))
                .offset(x: unit * 5.6, y: unit * 0.9)
                .opacity(landed ? 1 : 0)
                .animation(reduceMotion ? .easeOut(duration: 0.3) : Nova.Motion.settle.delay(0.5), value: landed)
        }
        .frame(width: unit * 8.2, height: unit * 5.6, alignment: .topLeading)
        .accessibilityHidden(true)
        .onAppear { landed = true }
    }
}

/// Artifact's chunky asterisk: three bars crossing at the centre.
///
/// Drawn rather than typed. A text asterisk takes the font's shape and weight, which is
/// never this one, and shifts on the baseline between faces.
struct AsteriskMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let bar = CGRect(x: -side * 0.12, y: -side / 2, width: side * 0.24, height: side)
        let centre = CGAffineTransform(translationX: rect.midX, y: rect.midY)

        var path = Path()
        for degrees in [0.0, 60, 120] {
            let turn = CGAffineTransform(rotationAngle: degrees * .pi / 180).concatenating(centre)
            path.addPath(Path(roundedRect: bar, cornerRadius: side * 0.03).applying(turn))
        }
        return path
    }
}

/// Loading, drawn in the motif: five squares lighting in turn.
///
/// Stands in for a spinner. It is the same five squares a round is made of, so waiting for
/// the deck already looks like the thing it is waiting for.
struct PixelLoader: View {
    var tints: [Color] = StoryCategory.allCases.map(\.tint)
    var size: CGFloat = 14

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let beat = reduceMotion ? -1 : Int(timeline.date.timeIntervalSinceReferenceDate * 7) % (tints.count + 2)

            HStack(spacing: size * 0.3) {
                ForEach(tints.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                        .fill(index <= beat ? tints[index] : Color.primary.opacity(0.1))
                        .frame(width: size, height: size)
                        .scaleEffect(index == beat ? 1.12 : 1)
                        .animation(.easeOut(duration: 0.12), value: beat)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview("Mosaic states") {
    let tints = StoryCategory.allCases.map(\.tint)
    VStack(spacing: 30) {
        HStack(spacing: 30) {
            MosaicView(mosaic: DailyMosaic(progress: [.unread, .unread, .unread, .unread, .unread]), tints: tints)
            MosaicView(mosaic: DailyMosaic(progress: [.read, .read, .read, .unread, .unread]), tints: tints)
        }
        HStack(spacing: 30) {
            MosaicView(mosaic: DailyMosaic(progress: [.correct, .missed, .correct, .correct, .missed]), tints: tints)
            MosaicView(mosaic: DailyMosaic(progress: Array(repeating: .correct, count: 5)), tints: tints)
        }
        PixelLoader()
        PixelScatter()
    }
    .padding()
}
