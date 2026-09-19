//
//  BasketHoopView.swift
//  NOVA
//

import SwiftUI

/// A basketball hoop: target square, bracket, rim and a net that recoils when the ball
/// drops through.
///
/// Depth comes from drawing the rim in two halves — the back behind the net, the front
/// over it — so the ball visibly falls *through* the hoop rather than across a circle.
struct BasketHoopView: View {
    let tint: Color
    var highlight: Color = .white
    var netColor: Color = .white
    let rimHalfWidth: CGFloat
    let netDepth: CGFloat
    /// Bumped each time the ball reaches this hoop. Any change fires the net.
    let impact: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stretch: CGFloat = 0

    private var rimHeight: CGFloat { rimHalfWidth * 0.52 }

    var body: some View {
        ZStack(alignment: .top) {
            // Back half of the rim, behind the net.
            Ellipse()
                .stroke(tint.opacity(0.45), lineWidth: 3)
                .frame(height: rimHeight)
                .mask(alignment: .top) { Rectangle().frame(height: rimHeight / 2 + 1.5) }

            BasketNetShape(stretch: stretch, rimHeight: rimHeight, columns: 12, rings: 4)
                .stroke(
                    LinearGradient(
                        colors: [netColor.opacity(0.9), netColor.opacity(0.35)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.9
                )
                .shadow(color: .black.opacity(0.25), radius: 1)

            // Front half, over the net, thicker and lit.
            Ellipse()
                .stroke(
                    LinearGradient(
                        colors: [highlight, tint, tint.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 4.5
                )
                .frame(height: rimHeight)
                .mask(alignment: .bottom) { Rectangle().frame(height: rimHeight / 2 + 2) }
                .shadow(color: tint.opacity(0.55), radius: 5, y: 1)
        }
        .frame(width: rimHalfWidth * 2, height: rimHeight + netDepth, alignment: .top)
        // Target square and bracket sit above the rim, over the backboard panel.
        .overlay(alignment: .top) { backboardTarget }
        .accessibilityHidden(true)
        .onChange(of: impact) { recoil() }
    }

    /// The painted square and the bracket holding the rim, which is what makes this read
    /// as a basketball hoop rather than a ring.
    private var backboardTarget: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(tint.opacity(0.75), lineWidth: 2)
                .frame(width: rimHalfWidth * 1.7, height: 22)

            Rectangle()
                .fill(tint.opacity(0.7))
                .frame(width: 5, height: 6)
        }
        .offset(y: -26)
    }

    /// Punch the net down fast, then return it on a loose spring so it overshoots and
    /// settles instead of snapping back.
    private func recoil() {
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) {
            stretch = 20
        } completion: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.26)) {
                stretch = 0
            }
        }
    }
}

/// The net, laced as crossing diagonals so it reads as real mesh. `stretch` lengthens it,
/// which is what makes the recoil visible.
struct BasketNetShape: Shape {
    var stretch: CGFloat
    let rimHeight: CGFloat
    let columns: Int
    let rings: Int

    var animatableData: CGFloat {
        get { stretch }
        set { stretch = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let columns = max(columns, 3)
        let rings = max(rings, 1)
        let radiusX = rect.width / 2
        let radiusY = rimHeight / 2
        let rimY = rect.minY + radiusY
        let depth = max(rect.height - rimHeight, 14) + stretch
        // A stretched net pinches in at the bottom, like a real one being pushed through.
        let taperAtBottom = 0.42 - min(stretch / 220, 0.12)

        func knot(column: Int, ring: Int) -> CGPoint {
            let angle = 2 * .pi * CGFloat(column) / CGFloat(columns)
            let depthFraction = CGFloat(ring) / CGFloat(rings)
            let taper = 1 + (taperAtBottom - 1) * depthFraction
            // Bulge outward in the middle so the net is a pouch, not a straight cone.
            let bulge = 1 + 0.12 * sin(.pi * depthFraction)
            return CGPoint(
                x: rect.midX + cos(angle) * radiusX * taper * bulge,
                y: rimY + sin(angle) * radiusY * taper + depth * depthFraction
            )
        }

        for ring in 0..<rings {
            for column in 0..<columns {
                path.move(to: knot(column: column, ring: ring))
                path.addLine(to: knot(column: column + 1, ring: ring + 1))

                path.move(to: knot(column: column + 1, ring: ring))
                path.addLine(to: knot(column: column, ring: ring + 1))
            }
        }

        // The hem at the bottom, which every net has.
        let hemTaper = taperAtBottom
        path.addEllipse(
            in: CGRect(
                x: rect.midX - radiusX * hemTaper,
                y: rimY + depth - radiusY * hemTaper,
                width: radiusX * 2 * hemTaper,
                height: radiusY * 2 * hemTaper
            )
        )

        return path
    }
}

#Preview {
    struct HoopPreview: View {
        @State private var impact = 0

        var body: some View {
            VStack(spacing: 50) {
                BasketHoopView(tint: .orange, rimHalfWidth: 42, netDepth: 30, impact: impact)
                Button("Drop the ball in") { impact += 1 }
            }
            .padding(60)
            .background(.background.secondary)
        }
    }
    return HoopPreview()
}
