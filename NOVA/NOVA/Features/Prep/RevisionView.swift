//
//  RevisionView.swift
//  NOVA
//

import SwiftUI

/// A revision round: up to ten archived questions, wrong ones first, answered by tapping.
///
/// On paper and without the slingshot. Revision is study, and a ball to aim makes a
/// fact slower to check, not easier to keep. The rules are still `RoundEngine`'s — the
/// same two-step answer-then-advance — so the feedback pause and the scoring are the
/// tested ones. Results go to the archive only, never to the streak.
struct RevisionView: View {
    @Environment(QuestionArchive.self) private var archive
    @Environment(\.dismiss) private var dismiss

    @State private var picked: [ArchivedAnswer] = []
    @State private var engine: RoundEngine?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let engine {
                        if let question = engine.currentQuestion {
                            questionBody(question, engine: engine)
                        } else {
                            finished(engine)
                        }
                    }
                }
                .padding(.horizontal, Nova.screenPadding)
                .padding(.vertical, 16)
                .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .novaPaperSurface()
            .navigationTitle("Revise")
            .novaInlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear(perform: start)
    }

    /// Built once, on appear, from the archive as it stands — so answering during the
    /// round doesn't reshuffle the questions still to come.
    private func start() {
        guard engine == nil else { return }
        picked = RevisionPicker.pick(from: archive.entries)
        let questions = picked.map(\.question)
        engine = RoundEngine(
            round: GameRound(
                id: RoundID("revision"),
                storyIDs: questions.map(\.storyID),
                questionIDs: questions.map(\.id)
            ),
            questions: questions
        )
    }

    // MARK: - Question

    @ViewBuilder
    private func questionBody(_ question: Question, engine: RoundEngine) -> some View {
        let result = engine.pendingResult
        let entry = picked.first { $0.id == question.id }

        Text("\(engine.currentQuestionNumber) / \(engine.questionCount)")
            .novaMeta(.caption, weight: .semibold)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Question \(engine.currentQuestionNumber) of \(engine.questionCount)")

        Text(question.prompt)
            .font(Nova.display(.title2))
            .tracking(-0.4)
            .fixedSize(horizontal: false, vertical: true)

        VStack(spacing: 10) {
            ForEach(Array(question.answers.enumerated()), id: \.offset) { index, answer in
                AnswerOption(
                    letter: Self.letter(index),
                    text: answer,
                    state: state(of: index, question: question, result: result)
                ) {
                    choose(index, question: question)
                }
                .disabled(result != nil)
            }
        }

        if result != nil {
            VStack(alignment: .leading, spacing: 8) {
                if let why = question.explanation {
                    Text(why)
                        .font(Nova.reading(.body))
                        .fixedSize(horizontal: false, vertical: true)
                    // The revision sheet covers Prep's footnote, so the label travels with
                    // the sentence it describes.
                    Text("Machine-written, not checked")
                        .novaMeta(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let entry {
                    Text("\(entry.source) · \(entry.storyTitle)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .transition(.opacity)

            HStack(spacing: 8) {
                QuestionShareButton(question: question, source: entry?.source ?? "", ink: Nova.ink)
                Button("Next") {
                    withAnimation(.snappy(duration: 0.25)) { self.engine?.advance() }
                }
                .buttonStyle(PaperButtonStyle())
            }
        }
    }

    private func choose(_ index: Int, question: Question) {
        withAnimation(.snappy(duration: 0.25)) {
            guard let submission = engine?.submitAnswer(at: index) else { return }
            archive.recordRevision(question.id, correct: submission.isCorrect)
        }
    }

    private func state(of index: Int, question: Question, result: AnswerSubmission?) -> AnswerOption.State {
        guard let result else { return .idle }
        if index == question.correctAnswerIndex { return .correct }
        if index == result.chosenAnswerIndex { return .wrong }
        return .dimmed
    }

    // MARK: - Finished

    private func finished(_ engine: RoundEngine) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if engine.questionCount == 0 {
                Text("Nothing to revise yet.")
                    .font(Nova.display(.title2))
            } else {
                Text("\(engine.correctAnswers) of \(engine.questionCount) right.")
                    .font(Nova.display(.title))
                    .tracking(-0.6)
                Text("Wrong ones come back first next time.")
                    .font(Nova.reading(.body))
                    .foregroundStyle(.secondary)
            }
            Button("Done") { dismiss() }
                .buttonStyle(PaperButtonStyle())
                .padding(.top, 8)
        }
    }

    /// "A", "B", "C"… — the letter carries the meaning, so colour is never the only cue.
    static func letter(_ index: Int) -> String {
        UnicodeScalar(65 + index).map { String(Character($0)) } ?? "?"
    }
}

// MARK: - Option

/// One answer as a full-width row on a paper sheet. Once judged, the right answer and the
/// wrong choice each get a border, a symbol and a word — Jade and Vermilion from the
/// category family, since the quiz's feedback colours are tuned for charcoal and fall
/// below 3:1 on paper.
private struct AnswerOption: View {
    enum State { case idle, correct, wrong, dimmed }

    let letter: String
    let text: String
    let state: State
    let action: () -> Void

    private var border: Color {
        switch state {
        case .correct: StoryCategory.business.tint
        case .wrong: StoryCategory.india.tint
        case .idle, .dimmed: Nova.hairline
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(letter)
                    .font(Nova.meta(.subheadline, weight: .bold))
                    .frame(width: 26, height: 26)
                    .background(Nova.paper, in: .rect(cornerRadius: 4))
                    .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Nova.hairline) }

                Text(text)
                    .font(.body.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                switch state {
                case .correct:
                    Label("Right", systemImage: "checkmark.circle.fill").labelStyle(.iconOnly)
                        .accessibilityLabel("Correct answer")
                case .wrong:
                    Label("Your pick", systemImage: "xmark.circle").labelStyle(.iconOnly)
                        .accessibilityLabel("Your answer, incorrect")
                case .idle, .dimmed:
                    EmptyView()
                }
            }
            .foregroundStyle(Nova.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: Nova.controlHeight)
            .background(Nova.sheet, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: state == .correct || state == .wrong ? 2 : 1)
            }
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(PressableStyle())
    }
}

#if DEBUG
#Preview {
    RevisionView()
        .environment(QuestionArchive.preview())
}
#endif
