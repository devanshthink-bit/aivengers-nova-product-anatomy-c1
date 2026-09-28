//
//  StatTile.swift
//  NOVA
//

import SwiftUI

/// A measurement and its label on a paper sheet: "3/5 · Stories read". Shared by Profile
/// and Prep, so the two screens count things the same way.
struct StatTile: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Nova.meta(.title2, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Nova.sheet, in: .rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Nova.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
