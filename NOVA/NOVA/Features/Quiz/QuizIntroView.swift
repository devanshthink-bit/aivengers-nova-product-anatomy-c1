//
//  QuizIntroView.swift
//  NOVA
//

import SwiftUI

/// The turn from reading to playing, and the first charcoal screen of the round.
///
/// Built like a Habits stage card: one object in the middle — the mosaic, outlined by the
/// reading just done and waiting to be filled — a title in compressed capitals, and mono
/// lines saying how it works. The screen goes dark here on purpose: it tells the reader,
/// before a word is read, that the mode has changed.
struct QuizIntroView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 76
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var shots: Int { session.engine.questionCount }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 12)

            MosaicView(
                mosaic: session.mosaic,
                tints: session.stories.map(\.category.tint),
                cell: 22,
                gap: 5
            )
            .scaleEffect(shown || reduceMotion ? 1 : 0.92)
            .opacity(shown ? 1 : 0)

            Spacer(minLength: 28)

            VStack(spacing: 14) {
                Text(session.hasRound ? "\(spelled(shots)) \(shots == 1 ? "shot" : "shots")." : "No shots today.")
                    .font(.system(size: titleSize, weight: .heavy).width(.compressed))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityAddTraits(.isHeader)

                Text(session.hasRound
                     ? "One question per story. Pull the paper ball back like a slingshot and sink it in the hoop holding your answer."
                     : "Today's questions couldn't be written. They're generated from the stories automatically, and that service didn't answer. Everything you read is still here.")
                    .novaMeta(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 12)

            Spacer(minLength: 24)

            if session.hasRound {
                rules
                    .opacity(shown ? 1 : 0)
            }

            Spacer(minLength: 12)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 28)
        .frame(maxWidth: Nova.readingMaxWidth)
        .frame(maxWidth: .infinity)
        .novaCharcoalSurface()
        .navigationTitle("Quiz")
        .novaInlineTitle()
        .safeAreaBar(edge: .bottom) {
            Button(session.hasRound ? "Take the first shot" : "Back to the stories") {
                if session.hasRound {
                    router.replace(with: [.quiz])
                } else {
                    router.popToReader()
                }
            }
            .buttonStyle(ChevronButtonStyle(prominent: true))
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(Nova.charcoal)
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Nova.Motion.enter) { shown = true }
        }
        .environment(\.colorScheme, .dark)
    }

    /// The scoring rules as three short mono lines, each marked by a pixel.
    private var rules: some View {
        VStack(alignment: .leading, spacing: 12) {
            rule(shots == 1 ? "1 question, 1 paper ball" : "\(shots) questions, \(shots) paper balls")
            rule("\(RoundEngine.pointsPerCorrectAnswer) points for every right answer sunk")
            rule("Miss, or clip the rim, and you shoot again")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 18)
        .overlay(alignment: .top) { Rectangle().fill(Nova.charcoalLine).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(Nova.charcoalLine).frame(height: 1) }
    }

    private func rule(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(.white.opacity(0.45))
                .frame(width: 7, height: 7)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] }

            Text(text)
                .novaMeta(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// "Five shots", not "5 shots" — a title reads as a statement, a digit as a count.
    private func spelled(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

#Preview {
    NavigationStack {
        QuizIntroView()
    }
    .environment(DailySession())
    .environment(AppRouter())
}
