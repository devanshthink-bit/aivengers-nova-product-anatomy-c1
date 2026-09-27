//
//  CategoryBadge.swift
//  NOVA
//

import SwiftUI

/// A category as a coloured pixel and its name in mono capitals.
///
/// The colour lives on the square, not the text. None of the category tints reach 4.5:1
/// as small type on paper, and the old tinted capsule failed exactly there.
struct CategoryBadge: View {
    let category: StoryCategory

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                .fill(category.tint)
                .frame(width: 8, height: 8)

            Text(category.title)
                .novaMeta(.caption2, weight: .semibold)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Category, \(category.title)")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        ForEach(StoryCategory.allCases, id: \.self) { CategoryBadge(category: $0) }
    }
    .padding()
}
