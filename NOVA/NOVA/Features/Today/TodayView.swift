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
                VStack(alignment: .leading, spacing: 26) {
                    roundHeader
                    storyList
                    demoNotice
                }
                .padding(.horizontal, Nova.screenPadding)
                .padding(.top, 4)
                .frame(maxWidth: Nova.readingMaxWidth, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
            .novaPaperSurface()
            .navigationTitle("Today")
            .novaInlineTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Header

    /// The mosaic beside the promise, so the index shows what the reading is building.
    private var roundHeader: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .novaMeta(.caption2)
                    .foregroundStyle(.secondary)

                Text("Read five stories, then earn your five shots.")
                    .font(Nova.display(.title3))
                    .tracking(-0.3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(session.storiesReadCount) / \(session.stories.count) read")
                    .font(Nova.meta(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

            Spacer(minLength: 0)

            MosaicView(
                mosaic: session.mosaic,
                tints: session.stories.map(\.category.tint),
                cell: 10,
                gap: 2
            )
        }
        .padding(.top, 8)
    }

    // MARK: - Stories

    private var storyList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(session.stories.enumerated()), id: \.element.id) { index, story in
                if index > 0 { Divider().overlay(Nova.hairline) }
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

    /// Stories are real now, but the summaries and questions are machine-written from the
    /// feed's own blurb and nobody has checked them. The old copy here claimed the
    /// stories themselves were invented, which stopped being true when the feeds landed.
    private var demoNotice: some View {
        Text("Summaries and questions are generated automatically and aren't editorially checked.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }
}

#Preview {
    TodayView { _ in }
        .environment(DailySession())
}
