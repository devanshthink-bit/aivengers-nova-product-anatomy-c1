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
    let artwork: Artwork
}

/// Where a card's picture comes from.
///
/// Two cases rather than one URL because the two sources are genuinely different: the
/// demo content ships images in the asset catalog, while feeds give remote URLs that may
/// be slow or absent. Plenty of real items carry no image at all — Economic Times and PIB
/// return none, and even BBC drops it on some items — so `.none` is a normal state to
/// render, not an error.
enum Artwork: Codable, Hashable, Sendable {
    case asset(String)
    case remote(URL)
    case none

    init(url: URL?) {
        self = url.map(Artwork.remote) ?? .none
    }
}

enum StoryCategory: String, Codable, CaseIterable, Sendable {
    case india
    case technology
    case business
    case world
    case science
    case sports
    case entertainment

    var title: String {
        switch self {
        case .india: String(localized: "India")
        case .technology: String(localized: "Technology")
        case .business: String(localized: "Business")
        case .world: String(localized: "World")
        case .science: String(localized: "Science")
        case .sports: String(localized: "Sports")
        case .entertainment: String(localized: "Entertainment")
        }
    }

    var symbolName: String {
        switch self {
        case .india: "map"
        case .technology: "cpu"
        case .business: "chart.line.uptrend.xyaxis"
        case .world: "globe"
        case .science: "atom"
        case .sports: "cricket.ball"
        case .entertainment: "film"
        }
    }
}
