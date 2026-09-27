//
//  QuizView.swift
//  NOVA
//

import SwiftUI

/// The round itself, on charcoal.
///
/// A right answer floods the whole screen marigold from the hoop the ball went through —
/// the Habits check-in, where the screen turning orange *is* the reward. A wrong one gets
/// no flood, just the question giving a small shake and the right answer revealed: the
/// miss is information, not a punishment, so it stays quiet.
struct QuizView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Where the last scoring ball dropped, in global space, and this view's own frame so
    /// the point can be brought into it.
    @State private var scoredAt: CGPoint?
    @State private var frame: CGRect = .zero
    @State private var misses = 0

    @ScaledMetric(relativeTo: .largeTitle) private var rewardSize: CGFloat = 112

    var body: some View {
        ZStack {
            if let question = session.engine.currentQuestion {
                court(for: question)
            } else {
                Color.clear
                    .task { router.replace(with: [.results]) }
            }

            ColorFlood(isActive: isFlooded, color: Nova.marigold, origin: floodOrigin)
                .ignoresSafeArea()

            reward
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
        .novaCharcoalSurface()
        // No navigation bar and no status bar: the flood has to reach the top edge, and a
        // bar sitting over it cut the reward in half. The rail below replaces both.
        .novaHiddenNavigationBar()
        .novaHiddenStatusBar()
        .safeAreaBar(edge: .top) { topRail }
        .safeAreaBar(edge: .bottom) { bottomBar }
        .sensoryFeedback(trigger: session.engine.pendingResult) { _, result in
            guard let result else { return nil }
            return result.isCorrect ? .success : .error
        }
        .onChange(of: session.engine.pendingResult) { _, result in
            if result?.isCorrect == false { misses += 1 }
        }
        // Last, so both bars are inside it. `.secondary` in a bar outside the dark
        // environment resolved to light-mode grey and all but vanished on charcoal.
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Top rail

    /// Close, where you are, and the score — the Habits header, three items and no bar.
    private var topRail: some View {
        HStack {
            Button {
                router.popToReader()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .frame(width: 36, height: 36)
                    .background(isFlooded ? Nova.marigoldInk.opacity(0.12) : Nova.charcoalRaised, in: .circle)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel("Leave the round")
            .accessibilityHint("Your answers so far are kept")

            Spacer(minLength: 8)

            Text("Question \(session.engine.currentQuestionNumber) / \(session.engine.questionCount)")
                .novaMeta(.caption2, weight: .semibold)
                .contentTransition(.numericText())
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            Text("\(session.engine.score) pts")
                .novaMeta(.caption2, weight: .bold)
                .foregroundStyle(isFlooded ? Nova.marigoldInk : (session.engine.score > 0 ? Nova.marigold : .secondary))
                .contentTransition(.numericText())
                .animation(Nova.Motion.settle, value: session.engine.score)
                .frame(minWidth: 44, alignment: .trailing)
                .accessibilityLabel("Score, \(session.engine.score) points")
        }
        .foregroundStyle(isFlooded ? Nova.marigoldInk : .white)
        .animation(.easeOut(duration: 0.2), value: isFlooded)
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }

    // MARK: - Flood

    private var isFlooded: Bool { session.engine.pendingResult?.isCorrect == true }

    private var floodOrigin: CGPoint {
        guard let scoredAt else { return CGPoint(x: frame.width / 2, y: frame.height * 0.4) }
        return CGPoint(x: scoredAt.x - frame.minX, y: scoredAt.y - frame.minY)
    }

    /// The points, huge, on the flood. Brown on marigold, the way the Habits flood turns
    /// its dark parts brown instead of black.
    private var reward: some View {
        Text("+\(RoundEngine.pointsPerCorrectAnswer)")
            .font(.system(size: rewardSize, weight: .heavy).width(.compressed))
            .foregroundStyle(Nova.marigoldInk)
            .scaleEffect(isFlooded || reduceMotion ? 1 : 0.7)
            .opacity(isFlooded ? 1 : 0)
            .animation(
                isFlooded
                    ? (reduceMotion ? .easeOut(duration: 0.2) : Nova.Motion.pop.delay(0.16))
                    : .easeOut(duration: 0.15),
                value: isFlooded
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Content

    private func court(for question: Question) -> some View {
        VStack(spacing: 16) {
            questionCard(for: question)
                .modifier(Shake(travel: reduceMotion ? 0 : 7, shakes: CGFloat(misses)))
                .animation(.linear(duration: 0.36), value: misses)

            ShotCourtView(
                question: question,
                shotNumber: session.engine.currentQuestionNumber,
                result: session.engine.pendingResult,
                onScoredAt: { scoredAt = $0 }
            ) { basketIndex in
                session.submitAnswer(at: basketIndex)
            }
            .id(question.id)
            .frame(minHeight: 300)
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.top, 4)
        .frame(maxWidth: Nova.readingMaxWidth)
        .frame(maxWidth: .infinity)
    }

    private func questionCard(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let story = session.story(for: question), let number = session.storyNumber(for: question) {
                    Text("Story \(number)")
                        .novaMeta(.caption2, weight: .semibold)
                        .foregroundStyle(.secondary)
                    CategoryBadge(category: story.category)
                }
                Spacer(minLength: 0)
                ProgressPips(
                    completed: session.engine.answeredCount,
                    total: session.engine.questionCount,
                    label: "questions answered",
                    tints: answerTints
                )
            }

            Text(question.prompt)
                .font(Nova.display(.title3))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Nova.charcoalRaised, in: .rect(cornerRadius: Nova.cardCornerRadius, style: .continuous))
    }

    /// A sunk answer's pixel takes its story's colour; a miss stays a dim white.
    private var answerTints: [Color] {
        session.engine.submissions.map { submission in
            guard submission.isCorrect,
                  let question = session.question(withID: submission.questionID),
                  let story = session.story(for: question)
            else { return .white.opacity(0.3) }
            return story.category.tint
        }
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let result = session.engine.pendingResult {
            feedbackBar(for: result)
        } else {
            Text("Pull back, aim the arc, let go")
                .novaMeta(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Nova.screenPadding)
                .padding(.vertical, 16)
        }
    }

    private func feedbackBar(for result: AnswerSubmission) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(result.isCorrect ? "Sunk it" : "Not quite")
                    .font(Nova.poster(.title2))
                    .textCase(.uppercase)
                Text(detail(for: result))
                    .novaMeta(.caption2)
                    .opacity(0.8)
                    .lineLimit(2)
            }
            .foregroundStyle(result.isCorrect ? Nova.marigoldInk : .white)

            Spacer(minLength: 0)

            Button(isLastQuestion ? "Results" : "Next") { advance() }
                .buttonStyle(ChevronButtonStyle(prominent: true))
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 12)
        .accessibilityElement(children: .contain)
        .task(id: result) { await autoAdvance() }
    }

    private func detail(for result: AnswerSubmission) -> String {
        if result.isCorrect {
            return "+\(result.pointsAwarded) points"
        }
        let answer = session.question(withID: result.questionID)?.correctAnswer ?? ""
        return "The answer was \(answer)"
    }

    private var isLastQuestion: Bool {
        session.engine.answeredCount >= session.engine.questionCount
    }

    // MARK: - Progression

    /// VoiceOver users advance themselves; everyone else gets a beat of feedback and
    /// then the next question.
    private func autoAdvance() async {
        guard !voiceOverEnabled else { return }
        try? await Task.sleep(for: .milliseconds(1800))
        guard session.engine.pendingResult != nil else { return }
        advance()
    }

    private func advance() {
        session.advanceToNextQuestion()
        if session.engine.isComplete {
            router.replace(with: [.results])
        }
    }
}

/// A short side-to-side shake, one per increment of `shakes`.
///
/// Animatable through `shakes` itself, so bumping it by one plays exactly one shake and
/// the question never ends up off-centre.
private struct Shake: GeometryEffect {
    var travel: CGFloat
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: travel * sin(shakes * .pi * 4), y: 0))
    }
}

#Preview {
    NavigationStack {
        QuizView()
    }
    .environment(DailySession())
    .environment(AppRouter())
    .environment(SoundPlayer())
}
