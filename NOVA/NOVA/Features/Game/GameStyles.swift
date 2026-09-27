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

    /// The mosaic's family, so the hoops belong to the same world as the squares they
    /// earn. Marigold is left out on purpose: it is the reward, not a target.
    static let all: [BasketStyle] = [
        BasketStyle(
            name: "Vermilion",
            rim: Color(hex: 0xE0592A),
            rimHighlight: Color(hex: 0xFFA27A),
            net: Color(hex: 0xFFE6DA),
            board: Color(hex: 0xE0592A)
        ),
        BasketStyle(
            name: "Sky",
            rim: Color(hex: 0x4DA3E8),
            rimHighlight: Color(hex: 0xA9D3F5),
            net: Color(hex: 0xE2F1FD),
            board: Color(hex: 0x4DA3E8)
        ),
        BasketStyle(
            name: "Cobalt",
            rim: Color(hex: 0x5A72F0),
            rimHighlight: Color(hex: 0xA8B6FF),
            net: Color(hex: 0xE3E8FF),
            board: Color(hex: 0x3550DA)
        ),
        BasketStyle(
            name: "Jade",
            rim: Color(hex: 0x24B585),
            rimHighlight: Color(hex: 0x86E6C3),
            net: Color(hex: 0xDDF8EE),
            board: Color(hex: 0x1E9A72)
        )
    ]

    static func forBasket(_ index: Int) -> BasketStyle {
        all[((index % all.count) + all.count) % all.count]
    }
}
