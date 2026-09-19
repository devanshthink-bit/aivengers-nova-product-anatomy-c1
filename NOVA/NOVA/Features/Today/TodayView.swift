//
//  TodayView.swift
//  NOVA
//

import SwiftUI

/// Today's five, shown as a sheet over the reader. Reading is the main surface now, so
/// this is an index you pull up to jump around, not the screen you land on.
struct TodayView: View {
    let onSelectStory: (Int) -> Void

    @Environment(DailySession.self) private var session
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    roundHeader
                    storyList
                    demoNotice
                }
                .padding(.horizontal, Nova.screenPadding)
                .padding(.top, 4)
                .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    private var roundHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text("Read five stories, then earn your five shots.")
                .font(Nova.display(.title3))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                ProgressPips(
                    completed: session.storiesReadCount,
                    total: session.stories.count,
                    label: "stories read"
                )
                Text("\(session.storiesReadCount) of \(session.stories.count) read")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Text("Round 1 of 3 · about 5 minutes")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .novaCard()
    }

    // MARK: - Stories

    private var storyList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's five")
                .font(Nova.display(.headline))

            ForEach(Array(session.stories.enumerated()), id: \.element.id) { index, story in
                StoryRow(
                    position: index + 1,
                    story: story,
                    isRead: session.isRead(story)
                ) {
                    onSelectStory(index)
                    dismiss()
                }
            }
        }
    }

    private var demoNotice: some View {
        Text("Demo content. These stories are written for the NOVA prototype and do not report real events.")
            .font(.caption)
            .foregroundStyle(.tertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }
}

#Preview {
    TodayView { _ in }
        .environment(DailySession())
        .tint(Nova.accent)
}
