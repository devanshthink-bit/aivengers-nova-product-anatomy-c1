//
//  RibbonBadge.swift
//  NOVA
//

import SwiftUI

/// The folded ribbon the Habits app hangs over a finished stage — "MASTER".
///
/// Two notched tails sit behind the band, a shade darker, which is all it takes for a flat
/// label to read as a thing that was awarded.
struct RibbonBadge: View {
    let title: String
    var fill: Color = Nova.marigold
    var ink: Color = Nova.marigoldInk

    var body: some View {
        Text(title)
            .novaMeta(.footnote, weight: .bold)
            .foregroundStyle(ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .background { Rectangle().fill(fill) }
            .background {
                GeometryReader { proxy in
                    let size = proxy.size
                    RibbonTails(tail: size.height * 0.75, drop: size.height * 0.28)
                        .fill(fill.mix(with: .black, by: 0.28))
                        .frame(width: size.width, height: size.height)
                }
            }
            .accessibilityLabel("Badge, \(title)")
    }
}

/// The two tails, each a strip with a V cut out of its outer end.
private struct RibbonTails: Shape {
    let tail: CGFloat
    let drop: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let top = rect.minY + drop
        let bottom = rect.maxY + drop
        let notch = tail * 0.4

        // Left tail, tucked a little under the band.
        path.move(to: CGPoint(x: rect.minX + 10, y: top))
        path.addLine(to: CGPoint(x: rect.minX - tail, y: top))
        path.addLine(to: CGPoint(x: rect.minX - tail + notch, y: (top + bottom) / 2))
        path.addLine(to: CGPoint(x: rect.minX - tail, y: bottom))
        path.addLine(to: CGPoint(x: rect.minX + 10, y: bottom))
        path.closeSubpath()

        path.move(to: CGPoint(x: rect.maxX - 10, y: top))
        path.addLine(to: CGPoint(x: rect.maxX + tail, y: top))
        path.addLine(to: CGPoint(x: rect.maxX + tail - notch, y: (top + bottom) / 2))
        path.addLine(to: CGPoint(x: rect.maxX + tail, y: bottom))
        path.addLine(to: CGPoint(x: rect.maxX - 10, y: bottom))
        path.closeSubpath()

        return path
    }
}

#Preview {
    VStack(spacing: 40) {
        RibbonBadge(title: "Sharpshooter")
        RibbonBadge(title: "Master", fill: Nova.charcoal, ink: .white)
    }
    .padding(60)
    .background(Nova.marigold.opacity(0.4))
}
