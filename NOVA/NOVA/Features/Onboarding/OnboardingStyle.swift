//
//  OnboardingStyle.swift
//  NOVA
//

import SwiftUI

/// The onboarding's visual language: enormous compressed capitals on charcoal, and one
/// white button that means "go" — the (Not Boring) Habits welcome, one statement a page.
///
/// Type carries everything. There are no cards, no bezels and no borders — a headline
/// large enough to fill the width needs no container to give it weight, and every box
/// removed is more air for the water to move through.
enum Onboarding {
    /// Charcoal, the play surface. Onboarding is the first thing NOVA shows, and it opens
    /// in the mode the day ends in, so the round feels like a return rather than a switch.
    /// Not black: the ripple's highlight needs a ground it can lift from.
    static var ground: Color { Nova.charcoal }

    /// The headline size. Big enough that three or four words fill a line, which is what
    /// makes the pages read as statements rather than instructions.
    ///
    /// Compressed capitals fit about twice the characters of the old bold, so the size
    /// goes up to keep the same three-or-four words a line.
    static let displaySize: CGFloat = 54
    /// The manifesto is the only thing on its page and gets a little more.
    static let manifestoSize: CGFloat = 60

    static func display(_ size: CGFloat = displaySize) -> Font {
        .system(size: size, weight: .heavy).width(.compressed)
    }

    /// Compressed capitals are already tight; negative tracking would jam them.
    static let tracking: CGFloat = 0.3
    static let lineSpacing: CGFloat = 0

    static let pagePadding: CGFloat = 24
    static let blockSpacing: CGFloat = 28

    /// A step up from the ground. Unselected tiles are meant to recede almost to nothing,
    /// so that a chosen one reads as the only thing on the page.
    static var surface: Color { Nova.charcoalRaised }

    static let tileRadius: CGFloat = 22
    /// 88, not 112: seven tiles in two columns have to clear the button on a phone.
    static let tileHeight: CGFloat = 88

    static let ctaHeight: CGFloat = 56
}

// MARK: - Headline

/// A headline at the page's scale, with its emphasis carried by colour alone.
struct Headline: View {
    let text: Text
    var size: CGFloat = Onboarding.displaySize

    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    var body: some View {
        text
            .font(Onboarding.display(size * min(scale, 1.4)))
            .textCase(.uppercase)
            .minimumScaleFactor(0.6)
            .tracking(Onboarding.tracking)
            .lineSpacing(Onboarding.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The grey line under a headline. Never competes; always explains.
struct Subhead: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.secondary)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - The button

/// The full-width chevron that carries every page forward, white on charcoal.
///
/// Disabled, it goes quiet and grey — and its label changes to say what is still
/// missing, rather than leaving a dead button with no explanation.
struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .novaMeta(.subheadline, weight: .semibold)
            .foregroundStyle(isEnabled ? AnyShapeStyle(Nova.charcoal) : AnyShapeStyle(.secondary))
            .frame(maxWidth: .infinity)
            .frame(height: Onboarding.ctaHeight)
            .background {
                ChevronCapsule().fill(isEnabled ? AnyShapeStyle(.white) : AnyShapeStyle(Onboarding.surface))
            }
            .contentShape(ChevronCapsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Nova.Motion.press, value: configuration.isPressed)
            .animation(.smooth(duration: 0.3), value: isEnabled)
    }
}

// MARK: - Choice tile

/// A choice on charcoal: a topic, or the news language.
///
/// Chosen inverts to white — the same move as the white chevron and Profile's ink chips —
/// so the selection reads without colour. A category's tint stays only as the 8pt square
/// (the Coloured Square Rule). It used to flood the whole tile, and with two or three
/// chosen the page became a patchwork with a second accent system.
struct ChoiceTile: View {
    let title: String
    let symbol: String?
    let tint: Color?
    let isOn: Bool
    var height: CGFloat = Onboarding.tileHeight

    private var ink: AnyShapeStyle {
        isOn ? AnyShapeStyle(Nova.charcoal) : AnyShapeStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isOn ? AnyShapeStyle(Nova.charcoal) : AnyShapeStyle(.white.opacity(0.55)))

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                if let tint {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(tint)
                        .frame(width: 8, height: 8)
                }
                Text(title)
                    .novaMeta(.subheadline, weight: .bold)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: symbol == nil ? .leading : .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, symbol == nil ? 0 : 14)
        .frame(height: height)
        .background {
            RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                .fill(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(Onboarding.surface))
        }
        .overlay {
            RoundedRectangle(cornerRadius: Onboarding.tileRadius, style: .continuous)
                .strokeBorder(Nova.charcoalLine, lineWidth: isOn ? 0 : 1)
        }
        .overlay(alignment: .topTrailing) {
            if isOn {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Nova.charcoal))
                    .padding(12)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            }
        }
        // The chosen tiles lift off the page on their shadow; the rest stay flat against it.
        // No scale: shrinking the unchosen tiles knocked their edges out of line with a
        // chosen neighbour in the same row.
        .shadow(color: isOn ? .black.opacity(0.35) : .clear, radius: 14, y: 8)
    }
}

// MARK: - Step marker

/// "01 / 05" in the top corner. The only chrome on the page, and small enough to ignore.
struct StepMarker: View {
    let page: OnboardingPage

    var body: some View {
        Text("\(String(format: "%02d", page.number)) / \(String(format: "%02d", OnboardingPage.count))")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .contentTransition(.numericText())
            .animation(.smooth(duration: 0.35), value: page)
            .accessibilityLabel("Step \(page.number) of \(OnboardingPage.count)")
    }
}

// MARK: - Entry

/// Fades an element up out of a soft blur, a beat after the one before it.
///
/// Nothing on these pages appears statically — the page assembles itself. Under Reduce
/// Motion everything is simply there, with no movement and no delay.
private struct StaggeredAppear: ViewModifier {
    let index: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .blur(radius: shown ? 0 : 5)
            .onAppear {
                guard !reduceMotion else {
                    shown = true
                    return
                }
                withAnimation(.smooth(duration: 0.6).delay(Double(index) * 0.075)) {
                    shown = true
                }
            }
    }
}

extension View {
    func onboardingEntry(_ index: Int) -> some View {
        modifier(StaggeredAppear(index: index))
    }
}
