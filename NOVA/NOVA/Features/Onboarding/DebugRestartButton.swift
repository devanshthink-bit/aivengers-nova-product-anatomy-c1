//
//  DebugRestartButton.swift
//  NOVA
//

import SwiftUI

#if DEBUG
/// Clears everything onboarding remembers and sends the flow back to page one.
///
/// It sits bottom-left of the whole app, above the onboarding overlay as well as the
/// reader, so the journey can be run start to finish as many times as it takes. It is
/// wrapped in `#if DEBUG`, so it cannot reach a shipping build.
///
/// This replaces the `-hasSeenWelcome NO` launch argument. That argument lands in
/// `NSArgumentDomain`, which outranks the app's own defaults for the whole life of the
/// process — so the flow's write of `true` was real but every read after it still came
/// back `false`, and the hand-off looked broken when it wasn't. A button writing to the
/// same domain the app reads from has no such problem.
struct DebugRestartButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("Restart", systemImage: "arrow.counterclockwise")
                .font(.system(size: 12, weight: .semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
        .padding(.leading, 20)
        .padding(.top, 6)
        .accessibilityLabel("Restart onboarding")
        .accessibilityHint("Debug only. Clears your name and topics and returns to the first page.")
    }
}
#endif
