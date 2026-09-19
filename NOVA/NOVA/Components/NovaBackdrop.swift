//
//  NovaBackdrop.swift
//  NOVA
//

import SwiftUI

/// The soft two-light gradient behind the reader and the game.
///
/// Deliberately low contrast and slow moving: it gives the glass surfaces something to
/// refract and ties a question back to the story it came from, without competing with the
/// text sitting on top of it. Lower the intensity where clarity matters more than mood.
struct NovaBackdrop: View {
    let tint: Color
    var intensity: Double = 1

    var body: some View {
        ZStack {
            Rectangle()
                .fill(tint.opacity(0.2 * intensity))
                .background(.background)

            RadialGradient(
                colors: [
                    tint.opacity(0.78 * intensity),
                    tint.opacity(0.28 * intensity),
                    .clear
                ],
                center: UnitPoint(x: 0.16, y: 0.0),
                startRadius: 8,
                endRadius: 720
            )

            RadialGradient(
                colors: [Nova.accent.opacity(0.55 * intensity), .clear],
                center: UnitPoint(x: 0.96, y: 1.0),
                startRadius: 8,
                endRadius: 560
            )

            RadialGradient(
                colors: [tint.opacity(0.32 * intensity), .clear],
                center: UnitPoint(x: 0.72, y: 0.42),
                startRadius: 16,
                endRadius: 380
            )
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        NovaBackdrop(tint: .teal)
        NovaBackdrop(tint: .teal, intensity: 0.6)
    }
    .ignoresSafeArea()
}
