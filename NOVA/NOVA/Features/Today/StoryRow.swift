//
//  StoryRow.swift
//  NOVA
//

import SwiftUI

/// One of today's five in the index sheet.
///
/// The position sits in a pixel square: outlined while unread, filled with the story's
/// colour once read — the same two states the story's squares have in the mosaic.
struct StoryRow: View {
    let position: Int
    let story: Story
    let isRead: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                marker

                VStack(alignment: .leading, spacing: 7) {
                    MetaLine(story: story)

                    Text(story.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                StoryThumbnail(story: story, size: 60)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Story \(position), \(story.category.title). \(story.title)")
        .accessibilityValue(isRead ? "Read" : "Not read yet")
        .accessibilityHint("Opens the story")
        .accessibilityAddTraits(.isButton)
    }

    private var marker: some View {
        let shape = RoundedRectangle(cornerRadius: 5, style: .continuous)

        return Text("\(position)")
            .font(Nova.meta(.footnote, weight: .bold))
            .foregroundStyle(isRead ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .frame(width: 28, height: 28)
            .background {
                if isRead {
                    shape.fill(story.category.tint)
                } else {
                    shape.strokeBorder(.primary.opacity(0.25), lineWidth: 1.5)
                }
            }
            .animation(Nova.Motion.pop, value: isRead)
    }
}

#Preview {
    VStack(spacing: 0) {
        StoryRow(position: 1, story: MockNewsService.todayStories[0], isRead: true) {}
        Divider()
        StoryRow(position: 2, story: MockNewsService.todayStories[1], isRead: false) {}
    }
    .padding()
    .novaPaperSurface()
}
