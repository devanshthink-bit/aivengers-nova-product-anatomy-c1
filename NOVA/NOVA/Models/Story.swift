//
//  Story.swift
//  NOVA
//

import Foundation

struct Story: Identifiable, Codable, Hashable, Sendable {
    let id: StoryID
    let title: String
    let summary: String
    let source: String
    let category: StoryCategory
    let publishedAt: Date
    /// Asset catalog name. Mock photos for now; a real feed would supply this later.
    let imageName: String
}

enum StoryCategory: String, Codable, CaseIterable, Sendable {
    case india
    case technology
    case business
    case world
    case science

    var title: String {
        switch self {
        case .india: "India"
        case .technology: "Technology"
        case .business: "Business"
        case .world: "World"
        case .science: "Science"
        }
    }

    var symbolName: String {
        switch self {
        case .india: "map"
        case .technology: "cpu"
        case .business: "chart.line.uptrend.xyaxis"
        case .world: "globe"
        case .science: "atom"
        }
    }
}
