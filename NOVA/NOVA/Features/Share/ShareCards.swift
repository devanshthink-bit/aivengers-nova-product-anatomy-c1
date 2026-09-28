//
//  ShareCards.swift
//  NOVA
//

import SwiftUI

/// Renders a view to a shareable image at a fixed size, whatever screen it was shared from.
/// Nil when rendering fails; callers then share text alone.
enum ShareRenderer {
    /// 360 × 450 pt at 3× is 1080 × 1350 px — the 4:5 portrait chat apps show uncropped.
    static let cardSize = CGSize(width: 360, height: 450)

    static func image(of view: some View, size: CGSize, scale: CGFloat = 3) -> Image? {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = scale
        guard let cgImage = renderer.cgImage else { return nil }
        return Image(decorative: cgImage, scale: scale)
    }
}

/// The round as a picture: the mosaic, the score, the date and the streak.
///
/// Marigold only when the round earned the flood, the same rule as the results screen —
/// a card that glows for zero hits would make the glow mean nothing.
struct ScorecardCard: View {
    let mosaic: DailyMosaic
    let tints: [Color]
    let correct: Int
    let total: Int
    let streak: Int
    let date: Date

    private var earned: Bool { correct > 0 }
    private var ink: Color { earned ? Nova.marigoldInk : .white }

    var body: some View {
        VStack(spacing: 20) {
            HStack(alignment: .center, spacing: 6) {
                Text("NOVA")
                    .font(Nova.poster(.title2))
                AsteriskMark()
                    .fill(ink)
                    .frame(width: 12, height: 12)
                Spacer()
                Text(date, format: .dateTime.day().month(.abbreviated))
                    .font(Nova.meta(.caption, weight: .semibold))
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)

            MosaicView(mosaic: mosaic, tints: tints, cell: 22, gap: 4)

            Text("\(correct) / \(total)")
                .font(.system(size: 88, weight: .heavy).width(.compressed))

            if streak > 0 {
                Text("\(streak)-day streak")
                    .font(Nova.meta(.subheadline, weight: .bold))
                    .textCase(.uppercase)
            }

            Spacer(minLength: 0)

            Text("Read five. Answer five.")
                .font(Nova.meta(.caption2, weight: .semibold))
                .textCase(.uppercase)
                .opacity(0.7)
        }
        .foregroundStyle(ink)
        .padding(28)
        .background(earned ? Nova.marigold : Nova.charcoal)
        .environment(\.colorScheme, earned ? .light : .dark)
    }
}

/// One question as a dare: the prompt, lettered options and the source — and no answer.
/// Leaving the answer off is the whole point; the reply in the group chat is the game.
struct QuestionShareCard: View {
    let question: Question
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("NOVA")
                    .font(Nova.poster(.title3))
                Spacer()
                Text("Can you answer this?")
                    .font(Nova.meta(.caption2, weight: .bold))
                    .textCase(.uppercase)
            }

            Text(question.prompt)
                .font(Nova.display(.title2))
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(question.answers.enumerated()), id: \.offset) { index, answer in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(RevisionView.letter(index))
                            .font(Nova.meta(.subheadline, weight: .bold))
                            .frame(width: 26, height: 26)
                            .background(Nova.charcoalRaised, in: .rect(cornerRadius: 4))
                        Text(answer)
                            .font(.subheadline.weight(.semibold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Spacer(minLength: 0)

            if !source.isEmpty {
                Text(source)
                    .font(.footnote.weight(.semibold))
                    .opacity(0.8)
            }
            Text("Answer in NOVA · machine-written question")
                .font(Nova.meta(.caption2))
                .opacity(0.6)
        }
        .foregroundStyle(.white)
        .padding(28)
        .background(Nova.charcoal)
        .environment(\.colorScheme, .dark)
    }
}

/// A share button for one question, rendered as its dare card. Icon-only with a 44 pt
/// target, so it can sit at the end of a review row.
///
/// The card is rendered once, when the button appears, and kept. Rendering inside `body`
/// would redo it on every re-evaluation, and the results screen re-evaluates on each
/// geometry change while its flood and mosaic animate.
struct QuestionShareButton: View {
    let question: Question
    let source: String
    var ink: Color = .primary

    @State private var card: Image?

    private var message: String { String(localized: "Can you answer this? — NOVA") }

    var body: some View {
        Group {
            if let card {
                ShareLink(item: card, message: Text(message), preview: SharePreview(question.prompt, image: card)) {
                    icon
                }
            } else {
                ShareLink(item: "\(question.prompt)\n\n\(message)") { icon }
            }
        }
        .accessibilityLabel("Share this question")
        .task(id: question.id) {
            card = ShareRenderer.image(
                of: QuestionShareCard(question: question, source: source),
                size: ShareRenderer.cardSize
            )
        }
    }

    private var icon: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ink)
            .frame(width: 44, height: 44)
            .contentShape(.rect)
    }
}

#Preview("Scorecard") {
    ScorecardCard(
        mosaic: DailyMosaic(progress: [.correct, .correct, .missed, .correct, .read]),
        tints: StoryCategory.allCases.prefix(5).map(\.tint),
        correct: 3, total: 5, streak: 6, date: .now
    )
    .frame(width: ShareRenderer.cardSize.width, height: ShareRenderer.cardSize.height)
}

#Preview("Question card") {
    QuestionShareCard(question: MockNewsService.todayQuestions[0], source: "The Hindu")
        .frame(width: ShareRenderer.cardSize.width, height: ShareRenderer.cardSize.height)
}
