//
//  ResultsView.swift
//  NOVA
//

import SwiftUI

struct ResultsView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router

    private var engine: RoundEngine { session.engine }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                scoreCard
                review
                nextRoundPlaceholder
            }
            .padding(.horizontal, Nova.screenPadding)
            .padding(.top, 4)
            .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Round 1")
        .novaInlineTitle()
        .navigationBarBackButtonHidden()
        .safeAreaBar(edge: .bottom) {
            Button("Back to the stories") { router.popToReader() }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Nova.screenPadding)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Score

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(headline)
                .font(Nova.display(.title2))
                .tracking(-0.4)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .top, spacing: 0) {
                statistic(value: "\(engine.score)", label: "points")
                Divider().frame(height: 40)
                statistic(value: "\(engine.correctAnswers)/\(engine.questionCount)", label: "correct")
                Divider().frame(height: 40)
                statistic(value: accuracyText, label: "accuracy")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .novaCard()
    }

    private func statistic(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var accuracyText: String {
        engine.accuracy.formatted(.percent.precision(.fractionLength(0)))
    }

    private var headline: String {
        switch engine.correctAnswers {
        case engine.questionCount: "Perfect round. You read properly."
        case 0: "Tough round. The stories are still there to re-read."
        default: "You held on to \(engine.correctAnswers) of \(engine.questionCount) stories."
        }
    }

    // MARK: - Review

    private var review: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your shots")
                .font(Nova.display(.headline))

            ForEach(Array(engine.submissions.enumerated()), id: \.offset) { index, submission in
                reviewRow(number: index + 1, submission: submission)
            }
        }
    }

    private func reviewRow(number: Int, submission: AnswerSubmission) -> some View {
        let question = session.question(withID: submission.questionID)

        return HStack(alignment: .top, spacing: 12) {
            Image(systemName: submission.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(submission.isCorrect ? .green : .red)
                .font(.body)

            VStack(alignment: .leading, spacing: 4) {
                Text(question?.prompt ?? "Question \(number)")
                    .font(Nova.reading(.subheadline, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)

                if !submission.isCorrect, let question {
                    Text("Answer: \(question.correctAnswer)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .novaCard(cornerRadius: 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Question \(number), \(submission.isCorrect ? "correct" : "incorrect"). \(question?.prompt ?? "")")
    }

    // MARK: - Next round

    private var nextRoundPlaceholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Round 2", systemImage: "lock.fill")
                .font(.subheadline.weight(.semibold))
            Text("Five more stories and five more shots. Coming in a later build.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .novaCard(cornerRadius: 16)
        .foregroundStyle(.secondary)
        .padding(.bottom, 8)
    }
}

#Preview {
    NavigationStack {
        ResultsView()
    }
    .environment(DailySession())
    .environment(AppRouter())
    .tint(Nova.accent)
}
