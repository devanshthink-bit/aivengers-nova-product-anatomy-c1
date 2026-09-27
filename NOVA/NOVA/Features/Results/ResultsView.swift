//
//  ResultsView.swift
//  NOVA
//

import SwiftUI

/// The end of the round: the mosaic as it was earned, a ribbon, and the week.
///
/// Any correct answer floods the screen marigold on arrival, from the mosaic outward — the
/// Habits "you completed the base" moment. A round with nothing sunk stays charcoal: a
/// flood you didn't earn would make the flood mean nothing.
///
/// Finishing a round is also what records the day for the streak, and nothing else does.
struct ResultsView: View {
    @Environment(DailySession.self) private var session
    @Environment(PlayHistory.self) private var history
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var flooded = false
    /// Global, so it has to be brought into the flood's own space with `frame`.
    @State private var mosaicCentre: CGPoint = .zero
    @State private var frame: CGRect = .zero
    @State private var shown = false

    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 96

    private var engine: RoundEngine { session.engine }
    private var earnsFlood: Bool { engine.correctAnswers > 0 }
    private var ink: Color { flooded ? Nova.marigoldInk : .white }

    var body: some View {
        ZStack {
            Nova.charcoal.ignoresSafeArea()

            ColorFlood(
                isActive: flooded,
                color: Nova.marigold,
                origin: CGPoint(x: mosaicCentre.x - frame.minX, y: mosaicCentre.y - frame.minY)
            )
            .ignoresSafeArea()
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }

            ScrollView {
                VStack(spacing: 30) {
                    hero
                    WeekStrip(days: history.week(), dot: 28)
                        .padding(.horizontal, 4)
                    review
                    nextRound
                }
                .padding(.horizontal, Nova.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .frame(maxWidth: Nova.readingMaxWidth)
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(ink)
        .animation(.easeOut(duration: 0.35), value: flooded)
        .novaHiddenNavigationBar()
        .novaHiddenStatusBar()
        .navigationBarBackButtonHidden()
        .safeAreaBar(edge: .bottom) { actions }
        // Last, so the bar above picks it up too.
        .environment(\.colorScheme, flooded ? .light : .dark)
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Nova.Motion.enter.delay(0.1)) { shown = true }
        }
        // Keyed on the outcome rather than run once on appear: the screen can be up before
        // the round it reports on has finished loading, and a one-shot check decided "no
        // flood" from an empty round and never looked again.
        .task(id: earnsFlood) {
            guard earnsFlood, !flooded else { return }
            // Let the mosaic land first, so the flood reads as coming *out of* it.
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 450))
            flooded = true
        }
        .onChange(of: engine.isComplete, initial: true) {
            if session.hasRound, engine.isComplete { history.record() }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 22) {
            MosaicView(
                mosaic: session.mosaic,
                tints: session.stories.map(\.category.tint),
                cell: 24,
                gap: 5
            )
            .scaleEffect(shown || reduceMotion ? 1 : 0.9)
            .onGeometryChange(for: CGPoint.self) { proxy in
                let frame = proxy.frame(in: .global)
                return CGPoint(x: frame.midX, y: frame.midY)
            } action: { mosaicCentre = $0 }

            RibbonBadge(
                title: badge,
                fill: flooded ? Nova.charcoal : Nova.charcoalRaised,
                ink: flooded ? Nova.marigold : .white
            )
            .scaleEffect(shown || reduceMotion ? 1 : 0.8)
            .opacity(shown ? 1 : 0)

            VStack(spacing: 6) {
                Text("\(engine.correctAnswers) / \(engine.questionCount)")
                    .font(.system(size: scoreSize, weight: .heavy).width(.compressed))
                    .contentTransition(.numericText())
                    .accessibilityLabel("\(engine.correctAnswers) of \(engine.questionCount) correct")

                Text("\(engine.score) points · \(accuracyText) accuracy")
                    .novaMeta(.caption, weight: .semibold)
                    .opacity(0.75)

                Text(headline)
                    .font(Nova.display(.title3))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
            }
            .opacity(shown ? 1 : 0)
            .offset(y: shown || reduceMotion ? 0 : 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var badge: String {
        let total = max(engine.questionCount, 1)
        switch engine.correctAnswers {
        case total: return "Sharpshooter"
        case 0: return "Warm-up"
        case let hits where Double(hits) / Double(total) >= 0.6: return "Sharp eye"
        default: return "On the board"
        }
    }

    private var accuracyText: String {
        engine.accuracy.formatted(.percent.precision(.fractionLength(0)))
    }

    private var headline: String {
        guard session.hasRound else { return "No questions could be written today." }
        return switch engine.correctAnswers {
        case engine.questionCount: "Perfect round. You read properly."
        case 0: "Tough round. The stories are still there to re-read."
        default: "You held on to \(engine.correctAnswers) of \(engine.questionCount) stories."
        }
    }

    // MARK: - Review

    private var review: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your shots")
                .novaMeta(.caption, weight: .bold)
                .padding(.bottom, 10)
                .accessibilityAddTraits(.isHeader)

            ForEach(Array(engine.submissions.enumerated()), id: \.offset) { index, submission in
                reviewRow(number: index + 1, submission: submission)
                    .overlay(alignment: .top) {
                        Rectangle().fill(ink.opacity(0.14)).frame(height: 1)
                    }
            }
        }
    }

    private func reviewRow(number: Int, submission: AnswerSubmission) -> some View {
        let question = session.question(withID: submission.questionID)
        let tint = question.flatMap { session.story(for: $0) }?.category.tint ?? ink
        let shape = RoundedRectangle(cornerRadius: 3, style: .continuous)

        return HStack(alignment: .top, spacing: 14) {
            Group {
                if submission.isCorrect {
                    shape.fill(tint)
                } else {
                    shape.strokeBorder(ink.opacity(0.4), lineWidth: 1.5)
                }
            }
            .frame(width: 14, height: 14)
            .padding(.top, 3)

            VStack(alignment: .leading, spacing: 5) {
                Text(question?.prompt ?? "Question \(number)")
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(submission.isCorrect ? "Sunk" : "Answer: \(question?.correctAnswer ?? "")")
                    .novaMeta(.caption2)
                    .opacity(0.7)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Question \(number), \(submission.isCorrect ? "correct" : "incorrect"). \(question?.prompt ?? "")")
    }

    // MARK: - Next round

    private var nextRound: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("Round 2 · five more stories, five more shots · in a later build")
                .novaMeta(.caption2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .opacity(0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 12) {
            ShareLink(item: shareText) {
                Text("Share")
            }
            .buttonStyle(ResultsOutlineStyle(ink: ink))

            Button("Back to the stories") { router.popToReader() }
                .buttonStyle(ChevronButtonStyle(prominent: true, fullWidth: true))
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 12)
    }

    /// A plain, factual line. No invented rank or percentile: there's no leaderboard.
    private var shareText: String {
        "NOVA, \(Date.now.formatted(date: .abbreviated, time: .omitted)): \(engine.correctAnswers)/\(engine.questionCount) sunk, \(engine.score) points."
    }

}

/// The outlined chevron, in whatever ink the results screen is currently using — white on
/// charcoal, brown once the flood has come through.
private struct ResultsOutlineStyle: ButtonStyle {
    let ink: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .novaMeta(.subheadline, weight: .semibold)
            .foregroundStyle(ink)
            .padding(.horizontal, 28)
            .frame(minHeight: Nova.controlHeight)
            .background {
                ChevronCapsule().strokeBorder(ink.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
            }
            .contentShape(ChevronCapsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Nova.Motion.press, value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        ResultsView()
    }
    .environment(DailySession())
    .environment(PlayHistory())
    .environment(AppRouter())
}
