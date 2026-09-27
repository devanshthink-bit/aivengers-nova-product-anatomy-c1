//
//  NovaButtons.swift
//  NOVA
//

import SwiftUI

/// The pointed-end outline the Habits buttons use — "CONTINUE", "SHARE".
///
/// The chevron ends are what make a plain outline read as a game control rather than a
/// form button, and they point sideways, which is the direction the next step goes.
struct ChevronCapsule: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let point = min(rect.height * 0.34, rect.width / 4)

        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + point, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - point, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - point, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + point, y: rect.maxY))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ChevronCapsule {
        ChevronCapsule(inset: inset + amount)
    }
}

/// The charcoal surfaces' button.
///
/// Prominent is filled white — one per screen, the way forward. The outline is for
/// everything else. Label in mono capitals, like every label on these screens.
struct ChevronButtonStyle: ButtonStyle {
    var prominent = false
    var fullWidth = false

    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = ChevronCapsule()

        configuration.label
            .novaMeta(.subheadline, weight: .semibold)
            .foregroundStyle(prominent ? Nova.charcoal : .white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 36)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: Nova.controlHeight)
            .background {
                if prominent {
                    shape.fill(.white)
                } else {
                    shape.strokeBorder(.white.opacity(0.9), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Nova.Motion.press, value: configuration.isPressed)
    }
}

/// The paper surfaces' button: Artifact's black slab.
///
/// `ink` rather than literal black, so it inverts to a light slab in Dark Mode instead of
/// vanishing into the dark paper.
struct PaperButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Nova.paper)
            .frame(maxWidth: .infinity, minHeight: Nova.controlHeight)
            .background(Nova.ink.opacity(isEnabled ? 1 : 0.3), in: .rect(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Nova.Motion.press, value: configuration.isPressed)
    }
}

/// For rows and tiles that are buttons: press feedback without any restyling.
///
/// `.plain` gives no response to a press at all, which makes a whole row feel dead under
/// the finger. A 3 % dip is enough to say "heard you".
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(Nova.Motion.press, value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 20) {
        Button("Take the first shot") {}
            .buttonStyle(ChevronButtonStyle(prominent: true))
        Button("Share") {}
            .buttonStyle(ChevronButtonStyle())
        Button("Continue") {}
            .buttonStyle(PaperButtonStyle())
            .environment(\.colorScheme, .light)
    }
    .padding(30)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Nova.charcoal)
}
