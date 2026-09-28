//
//  PrepView.swift
//  NOVA
//

import SwiftUI

/// Every question the reader has answered, for revising — the exam-prep half of NOVA.
///
/// On paper, because this is study, not play: the charcoal round is the daily game, and
/// revision deliberately has no slingshot, score flood or streak. What it keeps from the
/// game is the honesty — accuracy is measured on the first attempt, so revising can't
/// polish a number the reader didn't earn on the day.
struct PrepView: View {
    @Environment(QuestionArchive.self) private var archive
    @Environment(AppRouter.self) private var router

    @State private var showsRevision = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                header

                if archive.entries.isEmpty {
                    emptyState
                } else {
                    reviseButton
                    categories
                    thisWeek
                }

                Text("Questions are machine-written from news feeds and not checked. Verify before relying on them for an exam.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Nova.screenPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: Nova.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .novaPaperSurface()
        .navigationTitle("Prep")
        .novaInlineTitle()
        .sheet(isPresented: $showsRevision) {
            RevisionView()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Revise what you read.")
                .font(Nova.display(.title))
                .tracking(-0.6)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 12) {
                StatTile(value: "\(archive.entries.count)", label: "Questions kept")
                StatTile(
                    value: archive.accuracy.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "–",
                    label: "First-try right"
                )
                StatTile(value: "\(archive.dueCount)", label: "To revise")
            }
        }
    }

    // MARK: - Revise

    private var reviseButton: some View {
        let count = min(RevisionPicker.size, archive.entries.count)
        return Button {
            showsRevision = true
        } label: {
            Text("Revise \(count) questions")
        }
        .buttonStyle(PaperButtonStyle())
        .accessibilityHint("Wrong answers come first.")
    }

    // MARK: - By category

    private var categories: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("By topic")
                .padding(.bottom, 10)

            ForEach(archive.accuracyByCategory, id: \.category) { row in
                CategoryAccuracyRow(category: row.category, correct: row.correct, total: row.total)
                    .overlay(alignment: .top) {
                        Rectangle().fill(Nova.hairline).frame(height: 1)
                    }
            }
        }
    }

    // MARK: - This week

    private var thisWeek: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("This week")
                .padding(.bottom, 10)

            ForEach(archive.week(), id: \.day) { day in
                Text(day.day, format: .dateTime.weekday(.wide).day().month(.abbreviated))
                    .novaMeta(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                ForEach(day.entries) { entry in
                    SheetRow(entry: entry)
                        .overlay(alignment: .top) {
                            Rectangle().fill(Nova.hairline).frame(height: 1)
                        }
                }
            }

            // How aspirants actually revise together: a list passed round a WhatsApp group.
            ShareLink(item: archive.revisionSheet()) {
                Label("Share this week", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
            }
            .padding(.top, 14)
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Every question you answer lands here, ready to revise.")
                .font(Nova.reading(.body))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Go to today's stories") { router.tab = .scroll }
                .buttonStyle(PaperButtonStyle())
        }
    }

    private func sectionTitle(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(Nova.display(.title2))
            .tracking(-0.4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Rows

/// The category's square, its name, and how often the first try was right — as a count and
/// a thin ink bar. The bar is ink, never the tint: the tints are for squares.
private struct CategoryAccuracyRow: View {
    let category: StoryCategory
    let correct: Int
    let total: Int

    private var share: Double { total > 0 ? Double(correct) / Double(total) : 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(category.tint)
                    .frame(width: 9, height: 9)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(correct)/\(total)")
                    .novaMeta(.caption, weight: .semibold)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                Capsule().fill(Nova.hairline)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Nova.ink).frame(width: proxy.size.width * share)
                    }
            }
            .frame(height: 4)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(category.title): \(correct) of \(total) right first time")
    }
}

/// One line of the revision sheet: the question, its answer, and why it mattered.
private struct SheetRow: View {
    let entry: ArchivedAnswer

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(entry.question.prompt)
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)

            Text("→ \(entry.question.correctAnswer)")
                .font(Nova.reading(.subheadline, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let why = entry.question.explanation {
                Text(why)
                    .font(Nova.reading(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(entry.source)
                .novaMeta(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Seeded") {
    let archive = QuestionArchive.preview()
    return NavigationStack { PrepView() }
        .environment(archive)
        .environment(AppRouter())
}

#Preview("Empty") {
    NavigationStack { PrepView() }
        .environment(QuestionArchive(fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("empty-\(UUID()).json")))
        .environment(AppRouter())
}

#if DEBUG
extension QuestionArchive {
    /// An archive filled from the hand-written deck, at a throwaway file, for previews.
    static func preview() -> QuestionArchive {
        let archive = QuestionArchive(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview-\(UUID()).json")
        )
        for (index, question) in MockNewsService.todayQuestions.enumerated() {
            if let story = MockNewsService.todayStories.first(where: { $0.id == question.storyID }) {
                archive.record(question, story: story, correct: index % 2 == 0)
            }
        }
        return archive
    }
}
#endif
