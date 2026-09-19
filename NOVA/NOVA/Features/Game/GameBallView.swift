//
//  GameBallView.swift
//  NOVA
//

import SwiftUI

/// A glossy bowling-style ball. Each shot gets a different colour and marking so the
/// five turns feel like five different balls, not one reused.
struct GameBallView: View {
    let style: BallStyle

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [style.light, style.mid, style.dark],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 1,
                        endRadius: 30
                    )
                )

            Canvas { context, size in
                draw(style.pattern, in: &context, size: size)
            }
            .clipShape(Circle())
            .opacity(0.88)

            // Falloff toward the shaded side, which is what makes it look spherical.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.clear, .clear, .black.opacity(0.48)],
                        center: UnitPoint(x: 0.32, y: 0.26),
                        startRadius: 4,
                        endRadius: 29
                    )
                )

            // Specular highlight sitting on top of the markings.
            Ellipse()
                .fill(.white.opacity(0.78))
                .frame(width: 12, height: 8)
                .blur(radius: 2.2)
                .offset(x: -7, y: -9)

            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 0.8)
        }
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.34), radius: 7, y: 4)
        .accessibilityHidden(true)
    }

    // MARK: - Markings

    private func draw(_ pattern: BallStyle.Pattern, in context: inout GraphicsContext, size: CGSize) {
        let paint = GraphicsContext.Shading.color(style.markings)

        switch pattern {
        case .swirl:
            for index in 0..<2 {
                let inset = 0.16 + Double(index) * 0.2
                var path = Path()
                path.addArc(
                    center: CGPoint(x: size.width * 0.52, y: size.height * 0.5),
                    radius: size.width * (0.42 - inset * 0.4),
                    startAngle: .degrees(20 + Double(index) * 150),
                    endAngle: .degrees(190 + Double(index) * 150),
                    clockwise: false
                )
                context.stroke(path, with: paint, lineWidth: size.width * 0.085)
            }

        case .stripes:
            for index in 0..<3 {
                let x = size.width * (0.16 + Double(index) * 0.27)
                let band = Path(
                    roundedRect: CGRect(x: x, y: -size.height * 0.3,
                                        width: size.width * 0.1, height: size.height * 1.6),
                    cornerRadius: size.width * 0.05
                )
                context.fill(band.applying(.init(rotationAngle: .pi / 9)), with: paint)
            }

        case .marble:
            let blobs = [
                CGRect(x: 0.08, y: 0.12, width: 0.42, height: 0.3),
                CGRect(x: 0.46, y: 0.5, width: 0.46, height: 0.34),
                CGRect(x: 0.2, y: 0.62, width: 0.26, height: 0.22)
            ]
            for blob in blobs {
                let rect = CGRect(
                    x: blob.minX * size.width, y: blob.minY * size.height,
                    width: blob.width * size.width, height: blob.height * size.height
                )
                context.fill(Path(ellipseIn: rect), with: paint)
            }

        case .orbit:
            let ring = CGRect(
                x: -size.width * 0.1, y: size.height * 0.34,
                width: size.width * 1.2, height: size.height * 0.32
            )
            var path = Path(ellipseIn: ring)
            path = path.applying(.init(rotationAngle: -.pi / 9))
            context.stroke(path, with: paint, lineWidth: size.width * 0.075)

        case .speckle:
            let dots: [CGPoint] = [
                .init(x: 0.24, y: 0.2), .init(x: 0.62, y: 0.16), .init(x: 0.8, y: 0.42),
                .init(x: 0.34, y: 0.46), .init(x: 0.55, y: 0.6), .init(x: 0.2, y: 0.68),
                .init(x: 0.72, y: 0.76), .init(x: 0.44, y: 0.85)
            ]
            for dot in dots {
                let radius = size.width * 0.055
                let rect = CGRect(
                    x: dot.x * size.width - radius, y: dot.y * size.height - radius,
                    width: radius * 2, height: radius * 2
                )
                context.fill(Path(ellipseIn: rect), with: paint)
            }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ForEach(Array(BallStyle.all.enumerated()), id: \.offset) { _, style in
            HStack(spacing: 22) {
                GameBallView(style: style).frame(width: 48, height: 48)
                GameBallView(style: style).frame(width: 96, height: 96)
                Text(style.name).font(.caption)
            }
        }
    }
    .padding(30)
    .background(.background.secondary)
}
