//
//  ProfileView.swift
//  NOVA
//

import SwiftUI

/// Who the reader is and how today is going.
///
/// Everything here edits what onboarding already stored — the same `@AppStorage` keys —
/// so there is still exactly one place each answer lives. The "Today" numbers are read
/// straight off the session and reset on relaunch like the rest of the game; nothing is
/// saved across days yet, so the page doesn't pretend to have a history.
struct ProfileView: View {
    @Environment(DailySession.self) private var session
    @Environment(AppRouter.self) private var router

    @AppStorage("readerName") private var readerName = ""
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProfileHeader(name: readerName)
                nameSection
                topicsSection
                todaySection
                #if DEBUG
                debugSection
                #endif
            }
            .padding(.horizontal, Nova.screenPadding)
            .padding(.vertical, 16)
            .frame(maxWidth: Nova.readingMaxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(NovaBackdrop(tint: Nova.accent, intensity: 0.35).ignoresSafeArea())
        .navigationTitle("Profile")
        .novaInlineTitle()
    }

    // MARK: - Name

    private var nameSection: some View {
        ProfileSection(title: "Name") {
            TextField("Your name", text: $readerName)
                .font(.body)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .padding(16)
                .novaCard()
                // Trimmed only when the reader is done, so a space typed between two
                // names isn't eaten mid-word.
                .onSubmit { readerName = readerName.trimmingCharacters(in: .whitespaces) }
        }
    }

    // MARK: - Topics

    private var topics: TopicSelection { TopicSelection(rawValue: pickedTopicsRaw) }

    private var topicsSection: some View {
        ProfileSection(
            title: "Topics",
            footnote: "Chosen topics lead the deck. You'll still see everything, and at least \(TopicSelection.minimum) stay on."
        ) {
            FlowChips(spacing: 8) {
                ForEach(StoryCategory.allCases, id: \.self) { category in
                    TopicChip(
                        category: category,
                        isOn: topics.contains(category),
                        isLocked: !topics.canToggle(category)
                    ) {
                        toggle(category)
                    }
                }
            }
        }
    }

    private func toggle(_ category: StoryCategory) {
        var selection = topics
        guard selection.toggleKeepingMinimum(category) else { return }
        withAnimation(.snappy(duration: 0.25)) {
            pickedTopicsRaw = selection.rawValue
        }
        // Same call RootView makes on launch, so the deck reorders now rather than on
        // the next one.
        session.applyTopics(selection)
    }

    // MARK: - Today

    private var todaySection: some View {
        let engine = session.engine
        return ProfileSection(title: "Today") {
            HStack(spacing: 12) {
                StatTile(
                    value: "\(session.storiesReadCount)/\(session.stories.count)",
                    label: "Stories read"
                )
                StatTile(value: "\(engine.score)", label: "Score")
                StatTile(
                    // A dash, not "0%", before anything is answered: nothing has been
                    // got wrong yet.
                    value: engine.answeredCount > 0
                        ? engine.accuracy.formatted(.percent.precision(.fractionLength(0)))
                        : "–",
                    label: "Accuracy"
                )
            }
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugSection: some View {
        ProfileSection(title: "Debug") {
            Button(role: .destructive) {
                OnboardingReset.run(session: session, router: router)
            } label: {
                Label("Restart onboarding", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .novaCard()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityHint("Clears your name and topics and returns to the first page.")
        }
    }
    #endif
}

// MARK: - Pieces

/// The initial in an accent disc, and the name under it.
///
/// Falls back to "Reader" rather than an empty line: onboarding lets the name be skipped,
/// and a blank header reads like a loading failure.
private struct ProfileHeader: View {
    let name: String

    private var trimmed: String { name.trimmingCharacters(in: .whitespaces) }
    private var displayName: String { trimmed.isEmpty ? "Reader" : trimmed }

    var body: some View {
        VStack(spacing: 12) {
            Group {
                if let initial = trimmed.first {
                    Text(String(initial).uppercased())
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 36, weight: .semibold))
                }
            }
            .foregroundStyle(.white)
            .frame(width: 88, height: 88)
            .background(Circle().fill(Nova.accent.gradient))
            .shadow(color: Nova.accent.opacity(0.3), radius: 16, y: 8)
            .accessibilityHidden(true)

            Text(displayName)
                .font(Nova.display(.title2))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct ProfileSection<Content: View>: View {
    let title: String
    var footnote: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            content

            if let footnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Same look as `CategoryBadge`, flooded with the tint when chosen.
///
/// A locked chip is one of the last two chosen: it stays tappable-looking but dims a
/// touch, and VoiceOver says why nothing happens instead of silently ignoring the tap.
private struct TopicChip: View {
    let category: StoryCategory
    let isOn: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(category.title, systemImage: isOn ? "checkmark" : category.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isOn ? AnyShapeStyle(.white) : AnyShapeStyle(category.tint))
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    isOn ? AnyShapeStyle(category.tint.gradient) : AnyShapeStyle(category.tint.opacity(0.15)),
                    in: .capsule
                )
                .opacity(isLocked ? 0.75 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.title)
        .accessibilityValue(isOn ? "Chosen" : "Not chosen")
        .accessibilityHint(isLocked ? "At least \(TopicSelection.minimum) topics stay chosen." : "")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(Nova.display(.title2))
                .monospacedDigit()
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
        .novaCard()
        .accessibilityElement(children: .combine)
    }
}

/// Wraps chips onto as many lines as they need. Five categories don't fit one line on a
/// phone, and a fixed grid would leave uneven gaps between short and long names.
private struct FlowChips: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : size.width + spacing
            if rows[rows.count - 1].width + needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            let isFirst = rows[rows.count - 1].indices.isEmpty
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += isFirst ? size.width : size.width + spacing
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(DailySession())
    .environment(AppRouter())
}
