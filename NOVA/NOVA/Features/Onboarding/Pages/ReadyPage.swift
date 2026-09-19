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
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "All set")
                    .onboardingEntry(0)

                headline
                    .font(Onboarding.headline())
                    .tracking(-0.8)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingEntry(1)
            }

            if !chosen.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Leading with")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 7) {
                        ForEach(chosen, id: \.self) { category in
                            Label(category.title, systemImage: category.symbolName)
                                .font(.system(.caption, weight: .semibold))
                                .foregroundStyle(category.tint)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 7)
                                .background {
                                    Capsule().fill(category.tint.opacity(0.13))
                                }
                        }
                    }
                }
                .onboardingEntry(2)
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
                : Text(", \(greeting).").foregroundStyle(.primary))
    }
}

#Preview {
    ReadyPage(name: "Prakash", selection: TopicSelection(categories: [.india, .technology]))
        .padding(.horizontal, Nova.screenPadding)
}
