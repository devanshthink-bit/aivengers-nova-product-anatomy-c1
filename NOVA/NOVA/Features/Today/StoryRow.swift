//
//  StoryRow.swift
//  NOVA
//

import SwiftUI

struct StoryRow: View {
    let position: Int
    let story: Story
    let isRead: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Text("\(position)")
                    .font(.footnote.weight(.bold).monospacedDigit())
                    .foregroundStyle(isRead ? Color.white : Nova.accent)
                    .frame(width: 26, height: 26)
                    .background(isRead ? AnyShapeStyle(Nova.accent) : AnyShapeStyle(Nova.accent.opacity(0.15)),
                                in: .circle)

                VStack(alignment: .leading, spacing: 8) {
                    CategoryBadge(category: story.category)

                    Text(story.title)
                        .font(Nova.display(.headline))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(story.source) · \(story.publishedDescription)")
                        .font(Nova.reading(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(systemName: isRead ? "checkmark.circle.fill" : "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isRead ? Color.green : Color.secondary)
                    .padding(.top, 4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .novaCard()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Story \(position), \(story.category.title). \(story.title)")
        .accessibilityValue(isRead ? "Read" : "Not read yet")
        .accessibilityHint("Opens the story")
    }
}

#Preview {
    StoryRow(position: 1, story: MockNewsService.todayStories[0], isRead: false) {}
        .padding()
}
