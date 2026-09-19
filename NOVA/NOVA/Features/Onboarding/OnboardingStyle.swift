//
//  OnboardingStyle.swift
//  NOVA
//

import SwiftUI

/// The onboarding's visual language: enormous type on a flat ground, and one black
/// button that means "go".
///
/// Type carries everything. There are no cards, no bezels and no borders — a headline
/// large enough to fill the width needs no container to give it weight, and every box
/// removed is more air for the water to move through.
enum Onboarding {
    /// Flat, slightly warm grey. Deliberately not white: the black type sits on it
    /// without glaring, and the ripple's highlight has somewhere to lift from.
    static var ground: Color { Color(.systemGroupedBackground) }

    /// The headline size. Big enough that three or four words fill a line, which is what
    /// makes the pages read as statements rather than instructions.
    static let displaySize: CGFloat = 36
    /// The opening manifesto gets a little more, because it is the only thing on its
    /// page. Not much more: past this the sentence starts leaving single words
    /// stranded on the last line.
    static let manifestoSize: CGFloat = 36

    static func display(_ size: CGFloat = displaySize) -> Font {
        .system(size: size, weight: .bold)
    }

    /// Large type needs negative tracking or it reads loose and soft.
    static let tracking: CGFloat = -1.1
    static let lineSpacing: CGFloat = 2

    static let pagePadding: CGFloat = 24
    static let blockSpacing: CGFloat = 28

    /// A shade darker than the ground. Unselected tiles are meant to recede almost to
    /// nothing, so that a chosen one reads as the only thing on the page.
    static var surface: Color { Color(.tertiarySystemFill) }

    static let tileRadius: CGFloat = 22
    static let tileHeight: CGFloat = 112

    static let ctaHeight: CGFloat = 56
}

// MARK: - Headline

/// A headline at the page's scale, with its emphasis carried by colour alone.
struct Headline: View {
    let text: Text
    var size: CGFloat = Onboarding.displaySize

    var body: some View {
        text
            .font(Onboarding.display(size))
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

/// The full-width pill that carries every page forward.
///
/// `.primary` rather than literal black, so it inverts to white on a dark ground instead
/// of disappearing into it. Disabled, it goes quiet and grey — and its label changes to
/// say what is still missing, rather than leaving a dead button with no explanation.
struct OnboardingButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isEnabled ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.tertiary))
            .frame(maxWidth: .infinity)
            .frame(height: Onboarding.ctaHeight)
            .background {
                Capsule().fill(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(Color(.tertiarySystemFill)))
            }
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.snappy(duration: 0.22), value: configuration.isPressed)
            .animation(.smooth(duration: 0.3), value: isEnabled)
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
