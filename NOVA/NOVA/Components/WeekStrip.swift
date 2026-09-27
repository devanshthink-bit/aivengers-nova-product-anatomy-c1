//
//  WeekStrip.swift
//  NOVA
//

import SwiftUI

/// The last seven days as a row of dots, today underlined — the Habits bottom rail.
///
/// Uses `.primary` throughout, so it reads as ink on paper and white on charcoal without
/// a second variant. The underline under today is the one marigold mark, because today is
/// the day still to be earned.
struct WeekStrip: View {
    let days: [PlayHistory.Day]
    var dot: CGFloat = 30

    var body: some View {
        HStack(spacing: 0) {
            ForEach(days) { day in
                VStack(spacing: 7) {
                    marker(for: day)

                    Text(day.date, format: .dateTime.weekday(.abbreviated))
                        .novaMeta(.caption2, weight: day.isToday ? .bold : .medium)
                        .foregroundStyle(day.isToday ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                        .lineLimit(1)
                        .fixedSize()

                    Capsule()
                        .fill(day.isToday ? Nova.marigold : .clear)
                        .frame(width: 16, height: 2.5)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("This week")
        .accessibilityValue(summary)
    }

    @ViewBuilder
    private func marker(for day: PlayHistory.Day) -> some View {
        if day.played {
            Circle()
                .fill(.primary)
                .frame(width: dot, height: dot)
                .overlay {
                    Image(systemName: "checkmark")
                        .font(.system(size: dot * 0.4, weight: .heavy))
                        .foregroundStyle(.background)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        } else {
            Circle()
                .strokeBorder(.primary.opacity(day.isToday ? 0.9 : 0.18), lineWidth: day.isToday ? 1.5 : 1)
                .frame(width: dot, height: dot)
        }
    }

    private var summary: String {
        let played = days.filter(\.played).count
        return "Played \(played) of the last \(days.count) days"
    }
}

#Preview {
    let history = PlayHistory(defaults: UserDefaults(suiteName: "preview")!)
    VStack(spacing: 40) {
        WeekStrip(days: history.week())
            .padding()
            .background(Nova.paper)
        WeekStrip(days: history.week())
            .padding()
            .background(Nova.charcoal)
            .environment(\.colorScheme, .dark)
    }
}
