//
//  TopicChip.swift
//  NOVA
//

import SwiftUI

/// A category's square and its name, as a toggle. Chosen chips go ink, the way Artifact
/// marks a selected topic; the colour stays on the square because the tints fail contrast
/// as text. Shared by Profile's topics and Home's category tabs, so choosing a topic looks
/// the same wherever it happens.
///
/// A locked chip (one of the last two topics in Profile) stays tappable-looking but dims
/// a touch, and VoiceOver says why nothing happens instead of silently ignoring the tap.
struct TopicChip: View {
    let title: String
    /// Nil draws no square — the "All" tab has no colour of its own.
    let tint: Color?
    let isOn: Bool
    var isLocked = false
    var lockedHint: LocalizedStringKey = ""
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let tint {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(tint)
                        .frame(width: 9, height: 9)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if isOn, tint != nil {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                }
            }
            .foregroundStyle(isOn ? Nova.paper : Nova.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 44)
            .background {
                if isOn {
                    Capsule().fill(Nova.ink)
                } else {
                    Capsule().fill(Nova.sheet)
                    Capsule().strokeBorder(Nova.hairline, lineWidth: 1)
                }
            }
            .contentShape(Capsule())
            .opacity(isLocked ? 0.75 : 1)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "Chosen" : "Not chosen")
        .accessibilityHint(isLocked ? lockedHint : "")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}
