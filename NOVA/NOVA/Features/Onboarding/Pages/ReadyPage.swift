//
//  ReadyPage.swift
//  NOVA
//

import SwiftUI

/// The handover. Short, because everything has already been said.
struct ReadyPage: View {
    let name: String
    let selection: TopicSelection

    var body: some View {
        VStack(alignment: .leading, spacing: Onboarding.blockSpacing) {
            Spacer(minLength: 0)

            Headline(text: headline)
                .onboardingEntry(0)

            if !chosen.isEmpty {
                HStack(spacing: 8) {
                    ForEach(chosen, id: \.self) { category in
                        CategoryBadge(category: category)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Onboarding.surface, in: .rect(cornerRadius: 8, style: .continuous))
                    }
                }
                .onboardingEntry(1)
            }

            Spacer(minLength: 0)
        }
    }

    /// Kept in the app's own category order rather than the order they were tapped, so
    /// the row reads the same way the reader will.
    private var chosen: [StoryCategory] {
        StoryCategory.allCases.filter { selection.contains($0) }
    }

    private var headline: Text {
        let greeting = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return Text("Your first five\n").foregroundStyle(.primary)
            + Text("are waiting").foregroundStyle(.secondary)
            + (greeting.isEmpty
                ? Text(".").foregroundStyle(.secondary)
                : Text(",\n\(greeting).").foregroundStyle(.primary))
    }
}

#Preview {
    ReadyPage(name: "Prakash", selection: TopicSelection(categories: [.india, .technology]))
        .padding(.horizontal, Onboarding.pagePadding)
        .frame(maxHeight: .infinity)
        .background(Onboarding.ground)
}
