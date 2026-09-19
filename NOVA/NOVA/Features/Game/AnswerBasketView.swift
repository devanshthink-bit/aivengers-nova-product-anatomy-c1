//
//  AnswerBasketView.swift
//  NOVA
//

import SwiftUI

/// One answer: a backboard carrying the text, with a hoop and net hanging below it.
///
/// Also a button, so the shot can be taken without a drag — which is what VoiceOver and
/// Switch Control users get.
struct AnswerBasketView: View {
    enum Appearance: Equatable {
        case idle
        /// The player shot here and it was right.
        case correct
        /// The player shot here and it was wrong.
        case incorrect
        /// The answer they should have picked.
        case revealedAnswer
        case dimmed
    }

    let letter: String
    let answer: String
    let style: BasketStyle
    let appearance: Appearance
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            backboard
                .contentShape(.rect(cornerRadius: Nova.basketCornerRadius))
        }
        .buttonStyle(.plain)
        .opacity(appearance == .dimmed ? 0.45 : 1)
        .animation(.snappy(duration: 0.2), value: appearance)
        .accessibilityLabel("Basket \(letter). \(answer)")
        .accessibilityValue(status?.text ?? "")
        .accessibilityHint("Shoots the paper ball into this basket")
    }

    // MARK: - Backboard

    private var backboard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Text(letter)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(style.rim, in: .circle)

                Text(answer)
                    .font(Nova.reading(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            if let status {
                Label(status.text, systemImage: status.symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(status.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Keeps the answer legible once the gradient backdrop is showing through.
        .background {
            RoundedRectangle(cornerRadius: Nova.basketCornerRadius)
                .fill(.background.opacity(Nova.basketScrim))
        }
        .glassEffect(glass, in: .rect(cornerRadius: Nova.basketCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Nova.basketCornerRadius)
                .strokeBorder(borderStyle, lineWidth: borderWidth)
        }
    }

    // MARK: - Styling

    private struct Status {
        let text: String
        let symbol: String
        let tint: Color
    }

    private var status: Status? {
        switch appearance {
        case .correct: Status(text: "Correct", symbol: "checkmark.circle.fill", tint: .green)
        case .incorrect: Status(text: "Not this one", symbol: "xmark.circle.fill", tint: .red)
        case .revealedAnswer: Status(text: "Correct answer", symbol: "checkmark.circle", tint: .green)
        case .idle, .dimmed: nil
        }
    }

    private var glass: Glass {
        switch appearance {
        case .correct, .revealedAnswer: .regular.tint(.green.opacity(0.3))
        case .incorrect: .regular.tint(.red.opacity(0.3))
        case .idle, .dimmed: .regular.tint(style.board.opacity(0.22)).interactive()
        }
    }

    private var borderStyle: AnyShapeStyle {
        switch appearance {
        case .correct, .revealedAnswer: AnyShapeStyle(Color.green)
        case .incorrect: AnyShapeStyle(Color.red)
        case .idle, .dimmed: AnyShapeStyle(.clear)
        }
    }

    private var borderWidth: CGFloat {
        appearance == .idle || appearance == .dimmed ? 0 : 2
    }
}

#Preview {
    VStack(spacing: 14) {
        AnswerBasketView(letter: "A", answer: "Under 200 milliseconds",
                         style: .forBasket(0), appearance: .idle) {}
        AnswerBasketView(letter: "C", answer: "Under 5 seconds",
                         style: .forBasket(2), appearance: .incorrect) {}
        AnswerBasketView(letter: "D", answer: "Under 30 milliseconds",
                         style: .forBasket(3), appearance: .revealedAnswer) {}
    }
    .frame(height: 320)
    .padding()
}
