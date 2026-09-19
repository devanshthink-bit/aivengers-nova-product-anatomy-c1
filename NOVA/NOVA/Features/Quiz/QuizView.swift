//
//  QuizView.swift
//  NOVA
//

import SwiftUI

struct QuizView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        ZStack {
            backdrop.ignoresSafeArea()

            if let question = session.engine.currentQuestion {
                court(for: question)
            } else {
                Color.clear
                    .task { router.replace(with: [.results]) }
            }
        }
        .navigationTitle("Question \(session.engine.currentQuestionNumber) of \(session.engine.questionCount)")
        .novaInlineTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text("\(session.engine.score) pts")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
                    .animation(.snappy, value: session.engine.score)
                    .accessibilityLabel("Score, \(session.engine.score) points")
            }
        }
        .safeAreaBar(edge: .bottom) { bottomBar }
        .sensoryFeedback(trigger: session.engine.pendingResult) { _, result in
            guard let result else { return nil }
            return result.isCorrect ? .success : .error
        }
    }

    // MARK: - Content

    /// Tinted by the story this question came from, which quietly links the two. Held
    /// back from the reader's intensity because the game needs clarity more than mood.
    private var backdrop: some View {
        let story = session.engine.currentQuestion.flatMap { session.story(for: $0) }
        return NovaBackdrop(tint: story?.category.tint ?? Nova.accent, intensity: 0.6)
            .animation(.smooth(duration: 0.45), value: story?.id)
    }

    private func court(for question: Question) -> some View {
        VStack(spacing: 16) {
            questionCard(for: question)

            ShotCourtView(
                question: question,
                shotNumber: session.engine.currentQuestionNumber,
                result: session.engine.pendingResult
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let story = session.story(for: question), let number = session.storyNumber(for: question) {
                    Text("Story \(number)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    CategoryBadge(category: story.category)
                }
                Spacer(minLength: 0)
                ProgressPips(
                    completed: session.engine.answeredCount,
                    total: session.engine.questionCount,
                    label: "questions answered"
                )
            }

            Text(question.prompt)
                .font(Nova.display(.title3))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .novaCard()
    }

    // MARK: - Bottom bar

    @ViewBuilder
    private var bottomBar: some View {
        if let result = session.engine.pendingResult {
            feedbackBar(for: result)
        } else {
            Label("Pull the ball back, aim the arc, and let go.", systemImage: "hand.draw")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, Nova.screenPadding)
                .padding(.vertical, 10)
        }
    }

    private func feedbackBar(for result: AnswerSubmission) -> some View {
        HStack(spacing: 12) {
            Image(systemName: result.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(result.isCorrect ? .green : .red)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.isCorrect ? "Correct" : "Not quite")
                    .font(.subheadline.weight(.semibold))
                Text(detail(for: result))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Button(isLastQuestion ? "See results" : "Next") { advance() }
                .buttonStyle(.glassProminent)
        }
        .padding(.horizontal, Nova.screenPadding)
        .padding(.vertical, 10)
        .accessibilityElement(children: .contain)
        .task(id: result) { await autoAdvance() }
    }

    private func detail(for result: AnswerSubmission) -> String {
        if result.isCorrect {
            return "+\(result.pointsAwarded) points"
        }
        let answer = session.question(withID: result.questionID)?.correctAnswer ?? ""
        return "The answer was \(answer)."
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

#Preview {
    NavigationStack {
        QuizView()
    }
    .environment(DailySession())
    .environment(AppRouter())
    .environment(SoundPlayer())
    .tint(Nova.accent)
}
