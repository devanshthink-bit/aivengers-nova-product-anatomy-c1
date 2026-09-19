//
//  QuizIntroView.swift
//  NOVA
//

import SwiftUI

struct QuizIntroView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Spacer(minLength: 0)

            // The eyebrow belongs to the headline, so it sits tight against it while the
            // body copy gets real air after the large type.
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Label("Five stories read", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Nova.accent)

                    Text("Now take your five shots.")
                        .font(Nova.display(.largeTitle))
                        .tracking(-0.8)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text("One question per story. Pull the paper ball back like a slingshot, judge the arc, and sink it in the hoop holding your answer.")
                    .font(Nova.reading(.body))
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 18) {
                rule("basketball", "\(session.engine.questionCount) questions, \(session.engine.questionCount) paper balls")
                rule("square.grid.2x2", "Four baskets, one per answer")
                rule("bolt.fill", "\(RoundEngine.pointsPerCorrectAnswer) points for every basket you sink with the right answer")
                rule("arrow.uturn.backward", "Miss, or clip the rim, and you simply shoot again")
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .novaCard()

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Nova.screenPadding)
        .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity)
        .navigationTitle("Quiz")
        .novaInlineTitle()
        .safeAreaBar(edge: .bottom) {
            Button("Take the first shot") {
                router.replace(with: [.quiz])
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Nova.screenPadding)
            .padding(.vertical, 10)
        }
    }

    /// Not a `Label`: symbols vary in width, so a plain label starts each row's text at a
    /// different x and centres the icon against wrapped text. A fixed icon column and a
    /// first-line baseline keep the rows in one rhythm.
    private func rule(_ symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Image(systemName: symbol)
                .font(.subheadline)
                .foregroundStyle(Nova.accent)
                .frame(width: 20, alignment: .center)

            Text(text)
                .font(Nova.reading(.subheadline))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        QuizIntroView()
    }
    .environment(DailySession())
    .environment(AppRouter())
    .tint(Nova.accent)
}
