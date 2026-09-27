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

    /// A flat charcoal board with the letter in a pixel of the hoop's colour. No glass:
    /// the answer is the thing being read here, and it reads best on a solid ground.
    private var backboard: some View {
        let shape = RoundedRectangle(cornerRadius: Nova.basketCornerRadius, style: .continuous)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 9) {
                Text(letter)
                    .font(Nova.meta(.caption2, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(style.rim, in: .rect(cornerRadius: 4, style: .continuous))

                Text(answer)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)

            if let status {
                Label(status.text, systemImage: status.symbol)
                    .novaMeta(.caption2, weight: .bold)
                    .foregroundStyle(status.tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(fill, in: shape)
        .overlay { shape.strokeBorder(borderStyle, lineWidth: borderWidth) }
    }

    // MARK: - Styling

    /// Brighter than system green and red, which go muddy on charcoal. The text label is
    /// always there too, so colour is never the only way to tell.
    static let right = Color(hex: 0x3DDC97)
    static let wrong = Color(hex: 0xFF6B5E)

    private struct Status {
        let text: String
        let symbol: String
        let tint: Color
    }

    private var status: Status? {
        switch appearance {
        case .correct: Status(text: "Correct", symbol: "checkmark", tint: Self.right)
        case .incorrect: Status(text: "Not this one", symbol: "xmark", tint: Self.wrong)
        case .revealedAnswer: Status(text: "The answer", symbol: "checkmark", tint: Self.right)
        case .idle, .dimmed: nil
        }
    }

    private var fill: Color {
        switch appearance {
        case .correct, .revealedAnswer: Self.right.opacity(0.14).mix(with: Nova.charcoalRaised, by: 0.5)
        case .incorrect: Self.wrong.opacity(0.14).mix(with: Nova.charcoalRaised, by: 0.5)
        case .idle, .dimmed: Nova.charcoalRaised
        }
    }

    private var borderStyle: Color {
        switch appearance {
        case .correct, .revealedAnswer: Self.right
        case .incorrect: Self.wrong
        case .idle, .dimmed: Nova.charcoalLine
        }
    }

    private var borderWidth: CGFloat {
        appearance == .idle || appearance == .dimmed ? 1 : 2
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
    .novaCharcoalSurface()
}
