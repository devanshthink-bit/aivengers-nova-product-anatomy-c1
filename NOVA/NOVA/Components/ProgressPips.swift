//
//  ProgressPips.swift
//  NOVA
//

import SwiftUI

/// Compact "3 of 5 done" indicator used for both reading and quiz progress.
struct ProgressPips: View {
    let completed: Int
    let total: Int
    var label: String

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(total, 0), id: \.self) { index in
                Capsule()
                    .fill(index < completed ? AnyShapeStyle(Nova.accent) : AnyShapeStyle(.quaternary))
                    .frame(width: index < completed ? 20 : 8, height: 6)
            }
        }
        .animation(.snappy, value: completed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(completed) of \(total) \(label)")
    }
}

#Preview {
    ProgressPips(completed: 2, total: 5, label: "stories read")
        .padding()
}
