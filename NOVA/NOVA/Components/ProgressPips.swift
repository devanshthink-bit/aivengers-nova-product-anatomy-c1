//
//  ProgressPips.swift
//  NOVA
//

import SwiftUI

/// "3 of 5 done" as a row of pixels, used for both reading and quiz progress.
///
/// One square per story, filled with that story's tint once it's done, so the row is a
/// small preview of the mosaic the day is building.
struct ProgressPips: View {
    let completed: Int
    let total: Int
    var label: String
    /// Tint per position. Falls back to `.primary` when a caller has no stories to hand.
    var tints: [Color] = []

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                let done = index < completed
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(done ? AnyShapeStyle(tint(at: index)) : AnyShapeStyle(.primary.opacity(0.14)))
                    .frame(width: 9, height: 9)
                    .scaleEffect(done ? 1 : 0.8)
                    .animation(Nova.Motion.pop, value: done)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) \(label)")
    }

    private func tint(at index: Int) -> Color {
        tints.indices.contains(index) ? tints[index] : .primary
    }
}

#Preview {
    ProgressPips(completed: 2, total: 5, label: "stories read", tints: StoryCategory.allCases.map(\.tint))
        .padding()
}
