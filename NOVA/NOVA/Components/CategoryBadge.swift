//
//  CategoryBadge.swift
//  NOVA
//

import SwiftUI

struct CategoryBadge: View {
    let category: StoryCategory

    var body: some View {
        Label(category.title, systemImage: category.symbolName)
            .font(.caption.weight(.semibold))
            .foregroundStyle(category.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(category.tint.opacity(0.15), in: .capsule)
            .accessibilityLabel("Category, \(category.title)")
    }
}

#Preview {
    HStack {
        ForEach(StoryCategory.allCases, id: \.self) { CategoryBadge(category: $0) }
    }
    .padding()
}
