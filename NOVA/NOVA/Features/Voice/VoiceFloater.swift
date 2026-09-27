//
//  VoiceFloater.swift
//  NOVA
//

import SwiftUI

/// The mic that opens the voice briefing.
///
/// Ink on sheet with a hairline, like the other paper controls. No glass, because the
/// tab bar is the one piece of glass the design system allows (DESIGN.md).
struct VoiceFloater: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "mic.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Nova.ink)
                .frame(width: 58, height: 58)
                .background(Nova.sheet, in: Circle())
                .overlay(Circle().strokeBorder(Nova.hairline))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Ask NOVA for a news briefing")
    }
}

#Preview {
    VoiceFloater {}
        .padding(40)
        .background(Nova.paper)
}
