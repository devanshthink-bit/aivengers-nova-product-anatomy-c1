//
//  OnboardingStyle.swift
//  NOVA
//

import SwiftUI

/// The shared visual language of the onboarding pages.
///
/// One type size at one weight across every page; colour carries the hierarchy, not
/// weight or scale. Surfaces float on diffused shadow rather than sitting inside boxes,
/// and nested surfaces keep their curves concentric. This is the clean system layer,
/// deliberately set against the reader's warm editorial serif.
enum Onboarding {
    /// Outer radius of a nested surface.
    static let shellRadius: CGFloat = 26
    /// Gap between a shell and its core. The core's radius is the difference, which is
    /// what keeps the two curves concentric instead of merely rounded.
    static let shellInset: CGFloat = 6
    static var coreRadius: CGFloat { shellRadius - shellInset }

    static let iconTileRadius: CGFloat = 13
    static let iconTileSize: CGFloat = 42

    /// Air above the headline. The pages are mostly empty on purpose.
    static let headlineTopSpace: CGFloat = 18
    static let blockSpacing: CGFloat = 26

    static func headline(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .default, weight: .semibold)
    }
}

// MARK: - Eyebrow

/// The small tracked label above a headline. It names the step without competing with it.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Surfaces

extension View {
    /// A floating surface: no border, no hard shadow, just a soft ambient one so the card
    /// reads as sitting above the page rather than cut into it.
    func onboardingCore(radius: CGFloat = Onboarding.coreRadius, tint: Color? = nil) -> some View {
        background {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(tint ?? Color(.secondarySystemBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The outer half of the double bezel: a barely-there tray the core sits inside, with
    /// a hairline that catches the edge and a diffused shadow under the whole assembly.
    func onboardingShell(radius: CGFloat = Onboarding.shellRadius) -> some View {
        padding(Onboarding.shellInset)
            .background {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(.background.secondary)
                    .overlay {
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
                    }
            }
            .shadow(color: .black.opacity(0.06), radius: 22, y: 10)
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
            .offset(y: shown ? 0 : 14)
            .blur(radius: shown ? 0 : 4)
            .onAppear {
                guard !reduceMotion else {
                    shown = true
                    return
                }
                withAnimation(.smooth(duration: 0.55).delay(Double(index) * 0.07)) {
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

// MARK: - Progress

/// One dot per page; the current one stretches into a pill. A bar would suggest work
/// being completed — these are places, not progress through a task.
struct OnboardingProgress: View {
    let current: OnboardingPage

    var body: some View {
        HStack(spacing: 5) {
            ForEach(OnboardingPage.allCases, id: \.self) { page in
                let isCurrent = page == current
                Capsule()
                    .fill(isCurrent ? AnyShapeStyle(Nova.accent) : AnyShapeStyle(.tertiary))
                    .frame(width: isCurrent ? 18 : 5, height: 5)
            }
        }
        .animation(.smooth(duration: 0.4), value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current.number) of \(OnboardingPage.count)")
    }
}
