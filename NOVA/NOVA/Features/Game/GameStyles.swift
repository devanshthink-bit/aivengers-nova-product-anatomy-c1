//
//  GameStyles.swift
//  NOVA
//

import SwiftUI

/// How one ball looks. Each shot in a round gets a different one, so five shots feel like
/// five turns rather than five repeats of the same action.
struct BallStyle: Equatable {
    let name: String
    let light: Color
    let mid: Color
    let dark: Color
    let markings: Color
    let pattern: Pattern

    enum Pattern: Equatable {
        case swirl
        case stripes
        case marble
        case orbit
        case speckle
    }

    static let all: [BallStyle] = [
        BallStyle(
            name: "Sunburst",
            light: Color(red: 1.00, green: 0.78, blue: 0.32),
            mid: Color(red: 0.96, green: 0.48, blue: 0.06),
            dark: Color(red: 0.52, green: 0.18, blue: 0.00),
            markings: Color(red: 1.00, green: 0.92, blue: 0.55),
            pattern: .swirl
        ),
        BallStyle(
            name: "Cobalt",
            light: Color(red: 0.45, green: 0.72, blue: 1.00),
            mid: Color(red: 0.08, green: 0.32, blue: 0.82),
            dark: Color(red: 0.02, green: 0.08, blue: 0.38),
            markings: Color(red: 0.78, green: 0.92, blue: 1.00),
            pattern: .stripes
        ),
        BallStyle(
            name: "Violet",
            light: Color(red: 0.82, green: 0.62, blue: 1.00),
            mid: Color(red: 0.46, green: 0.16, blue: 0.78),
            dark: Color(red: 0.18, green: 0.04, blue: 0.38),
            markings: Color(red: 0.94, green: 0.82, blue: 1.00),
            pattern: .marble
        ),
        BallStyle(
            name: "Emerald",
            light: Color(red: 0.42, green: 0.95, blue: 0.62),
            mid: Color(red: 0.04, green: 0.58, blue: 0.32),
            dark: Color(red: 0.00, green: 0.24, blue: 0.14),
            markings: Color(red: 0.78, green: 1.00, blue: 0.86),
            pattern: .orbit
        ),
        BallStyle(
            name: "Crimson",
            light: Color(red: 1.00, green: 0.52, blue: 0.48),
            mid: Color(red: 0.78, green: 0.08, blue: 0.14),
            dark: Color(red: 0.32, green: 0.00, blue: 0.04),
            markings: Color(red: 1.00, green: 0.82, blue: 0.72),
            pattern: .speckle
        )
    ]

    /// Cycles, so a longer round never runs out of balls.
    static func forShot(_ number: Int) -> BallStyle {
        all[((number % all.count) + all.count) % all.count]
    }
}

/// How one basket looks. Four different rims and nets so the targets read as four hoops,
/// not one hoop copied. The answer letter still carries the meaning, so colour is extra
/// and not the only cue for colour-blind players.
struct BasketStyle: Equatable {
    let name: String
    let rim: Color
    let rimHighlight: Color
    let net: Color
    let board: Color

    static let all: [BasketStyle] = [
        BasketStyle(
            name: "Amber",
            rim: Color(red: 1.00, green: 0.52, blue: 0.08),
            rimHighlight: Color(red: 1.00, green: 0.82, blue: 0.38),
            net: Color(red: 1.00, green: 0.94, blue: 0.82),
            board: Color(red: 1.00, green: 0.55, blue: 0.12)
        ),
        BasketStyle(
            name: "Sky",
            rim: Color(red: 0.12, green: 0.52, blue: 0.98),
            rimHighlight: Color(red: 0.62, green: 0.84, blue: 1.00),
            net: Color(red: 0.86, green: 0.94, blue: 1.00),
            board: Color(red: 0.18, green: 0.55, blue: 1.00)
        ),
        BasketStyle(
            name: "Orchid",
            rim: Color(red: 0.62, green: 0.28, blue: 0.98),
            rimHighlight: Color(red: 0.88, green: 0.72, blue: 1.00),
            net: Color(red: 0.94, green: 0.88, blue: 1.00),
            board: Color(red: 0.62, green: 0.32, blue: 0.98)
        ),
        BasketStyle(
            name: "Jade",
            rim: Color(red: 0.04, green: 0.68, blue: 0.52),
            rimHighlight: Color(red: 0.52, green: 0.96, blue: 0.78),
            net: Color(red: 0.86, green: 1.00, blue: 0.92),
            board: Color(red: 0.06, green: 0.72, blue: 0.56)
        )
    ]

    static func forBasket(_ index: Int) -> BasketStyle {
        all[((index % all.count) + all.count) % all.count]
    }
}
