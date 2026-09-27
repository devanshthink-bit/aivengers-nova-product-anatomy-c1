//
//  ColorFlood.swift
//  NOVA
//

import SwiftUI

/// The whole screen turning one colour, spreading from a point — the Habits check-in.
///
/// Spreads from where the thing happened (the hoop the ball dropped through), because a
/// flood from the centre of the screen says "something happened" while a flood from the
/// hoop says "*that* happened".
///
/// Enters slowly enough to be seen and leaves fast: the reveal is the reward, the exit is
/// just getting out of the way. Under Reduce Motion it is a plain crossfade.
struct ColorFlood: View {
    let isActive: Bool
    let color: Color
    /// Where the flood starts, in this view's own coordinate space.
    let origin: CGPoint

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let reach = [
                CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: 0),
                CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)
            ]
            .map { hypot($0.x - origin.x, $0.y - origin.y) }
            .max() ?? 0

            Circle()
                .fill(color)
                .frame(width: reach * 2, height: reach * 2)
                .scaleEffect(isActive || reduceMotion ? 1 : 0.02)
                .position(origin)
                .opacity(isActive ? 1 : 0)
                .animation(animation, value: isActive)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var animation: Animation {
        if reduceMotion { return .easeOut(duration: 0.25) }
        return isActive
            ? .timingCurve(0.23, 1, 0.32, 1, duration: 0.6)
            : .easeOut(duration: 0.28)
    }
}

#Preview {
    @Previewable @State var on = false
    ZStack {
        Nova.charcoal
        ColorFlood(isActive: on, color: Nova.marigold, origin: CGPoint(x: 120, y: 300))
        Button("Flood") { on.toggle() }
            .buttonStyle(ChevronButtonStyle(prominent: true))
    }
    .ignoresSafeArea()
}
