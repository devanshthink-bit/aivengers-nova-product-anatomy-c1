//
//  ProfileView.swift
//  NOVA
//

import SwiftUI

/// Who the reader is and how today is going.
///
/// Everything here edits what onboarding already stored — the same `@AppStorage` keys —
/// so there is still exactly one place each answer lives. The "Today" numbers are read
/// straight off the session and reset on relaunch like the rest of the game. The week
/// underneath comes from `PlayHistory`, which only records days a round was finished.
struct ProfileView: View {
    @Environment(DailySession.self) private var session
    @Environment(PlayHistory.self) private var history
    @Environment(AppRouter.self) private var router

    @AppStorage("readerName") private var readerName = ""
    @AppStorage("pickedTopics") private var pickedTopicsRaw = ""
    @AppStorage(ContentLanguage.storageKey) private var languageRaw = ContentLanguage.preferred().rawValue

    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ProfileHeader(name: readerName)
                nameSection
                languageSection
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
        .novaPaperSurface()
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
                .profileSurface()
                // Trimmed only when the reader is done, so a space typed between two
                // names isn't eaten mid-word.
                .onSubmit { readerName = readerName.trimmingCharacters(in: .whitespaces) }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            ProfileSection(
                title: "News language",
                footnote: "Changes today's stories. Your answers so far are kept."
            ) {
                Picker("News language", selection: $languageRaw) {
                    ForEach(ContentLanguage.allCases, id: \.self) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            // The app's own words follow iOS's per-app language, which the String Catalog
            // makes appear in Settings. Linking there beats a second in-app switch that
            // would miss every string not rendered through a view.
            ProfileSection(
                title: "App language",
                footnote: "The app's own words follow your iPhone. To see them in Hindi, choose Hindi in Settings → NOVA → Language."
            ) {
                Button {
                    Nova.openAppSettings(using: openURL)
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .profileSurface()
                }
                .buttonStyle(.plain)
            }
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
            VStack(spacing: 12) {
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

                WeekStrip(days: history.week(), dot: 26)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 6)
                    .profileSurface()
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
                    .profileSurface()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityHint("Clears your name and topics and returns to the first page.")
        }
    }
    #endif
}

// MARK: - Pieces

/// The initial in an ink disc, and the name under it.
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
            .foregroundStyle(Nova.paper)
            .frame(width: 88, height: 88)
            .background(Circle().fill(Nova.ink))
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
                .novaMeta(.caption, weight: .semibold)
                .foregroundStyle(.secondary)
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

/// The category's square and its name. Chosen chips go ink, the way Artifact marks a
/// selected topic; the colour stays on the square because the tints fail contrast as text.
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
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(category.tint)
                    .frame(width: 9, height: 9)
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.heavy))
                }
            }
            .foregroundStyle(isOn ? Nova.paper : Nova.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                if isOn {
                    Capsule().fill(Nova.ink)
                } else {
                    Capsule().fill(Nova.sheet)
                    Capsule().strokeBorder(Nova.hairline, lineWidth: 1)
                }
            }
            .opacity(isLocked ? 0.75 : 1)
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(category.title)
        .accessibilityValue(isOn ? "Chosen" : "Not chosen")
        .accessibilityHint(isLocked ? "At least \(TopicSelection.minimum) topics stay chosen." : "")
        .accessibilityAddTraits(isOn ? [.isSelected, .isButton] : .isButton)
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

private extension View {
    /// The paper sheet the profile's fields and tiles sit on: opaque, with a hairline,
    /// in place of the old `novaCard()` the redesign removed.
    func profileSurface() -> some View {
        background(Nova.sheet, in: .rect(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Nova.hairline, lineWidth: 1)
            }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
    }
    .environment(DailySession())
    .environment(PlayHistory())
    .environment(AppRouter())
}
