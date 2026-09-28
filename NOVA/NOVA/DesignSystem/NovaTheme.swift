//
//  NovaTheme.swift
//  NOVA
//

import Foundation
import SwiftUI

/// Two surfaces and one motif.
///
/// **Paper** is where you read: a warm off-white ground, near-black ink, hairlines instead of
/// cards, a serif for body copy and a publisher line above every headline (Artifact).
/// **Charcoal** is where you play: one focal object per screen, condensed capitals, mono for
/// every label and a single marigold accent that means "you earned this" ((Not Boring) Habits).
/// The **pixel mosaic** runs through both, and is what a day of reading builds.
///
/// Marigold is never text on paper — it fails contrast there — and never decoration on
/// charcoal. If it is on screen, the reader did something to put it there.
enum Nova {
    // MARK: - Paper

    /// The reading ground. Deliberately not white: the white of the story sheet has to have
    /// something to lift off.
    static let paper = Color.dynamic(light: 0xF6F4EE, dark: 0x121212)
    /// The story sheet itself, and anything that sits one step above the ground.
    static let sheet = Color.dynamic(light: 0xFFFFFF, dark: 0x1D1D1F)
    static let ink = Color.dynamic(light: 0x17160F, dark: 0xF2F0EA)
    static let hairline = Color.dynamic(light: 0x17160F, dark: 0xF2F0EA).opacity(0.1)

    // MARK: - Charcoal

    static let charcoal = Color(hex: 0x1C1C1E)
    /// Boards, tiles and fields on the charcoal ground.
    static let charcoalRaised = Color(hex: 0x2A2A2D)
    static let charcoalLine = Color.white.opacity(0.12)

    // MARK: - Accent

    /// The achievement colour. Floods, ribbons, the score, today's marker.
    static let marigold = Color(hex: 0xF5B53A)
    /// What sits *on* marigold. The Habits flood turns dark parts brown rather than black.
    static let marigoldInk = Color(hex: 0x3A2204)

    /// Kept for the app-wide `.tint`: the paper surfaces are ink-tinted like Artifact's,
    /// so interactive text stays legible without needing a colour to say "tap me".
    static let accent = ink

    // MARK: - Mosaic

    /// Squares that belong to no story: the decorative mosaic on the welcome and empty
    /// states. Story squares take their category's tint instead.
    static let mosaicSky = Color(hex: 0xA9D3F5)
    static let mosaicVermilion = Color(hex: 0xE0592A)
    static let mosaicNavy = Color(hex: 0x23208F)

    // MARK: - Metrics

    static let cardCornerRadius: CGFloat = 20
    static let basketCornerRadius: CGFloat = 18
    static let storyCardCornerRadius: CGFloat = 28
    static let screenPadding: CGFloat = 20
    /// Keeps story text from stretching into unreadable line lengths on iPad.
    static let readingMaxWidth: CGFloat = 620
    static let controlHeight: CGFloat = 56

    // MARK: - Type

    /// Headlines on paper. San Francisco bold, so titles stay sharp against the serif body.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .default).weight(.bold)
    }

    /// Body copy. New York is the reading face.
    static func reading(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }

    /// The charcoal voice: heavy, compressed capitals. SF's own compressed width rather than
    /// a licensed face, so it follows Dynamic Type and ships no font files.
    static func poster(_ style: Font.TextStyle) -> Font {
        .system(style, design: .default).weight(.heavy).width(.compressed)
    }

    /// Labels, counts and dates. Mono because these are measurements — "3 / 5", "2H AGO" —
    /// and digits that don't shift width are what make a counter feel like one.
    static func meta(_ style: Font.TextStyle = .caption, weight: Font.Weight = .medium) -> Font {
        .system(style, design: .monospaced).weight(weight)
    }
}

// MARK: - Motion

extension Nova {
    /// Every duration is chosen by how often the reader sees it: presses are nearly
    /// instant, the flood and the mosaic are rare enough to be allowed a moment.
    enum Motion {
        /// Press feedback. Short, ease-out, and no bounce: it confirms, it doesn't perform.
        static let press = Animation.easeOut(duration: 0.14)
        /// Things settling into place after the reader moved them.
        static let settle = Animation.spring(duration: 0.45, bounce: 0.18)
        /// Entrances. A strong ease-out, so movement starts the moment the eye arrives.
        static let enter = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.55)
        /// A mosaic square landing. A little bounce, because it is a reward.
        static let pop = Animation.spring(duration: 0.38, bounce: 0.34)
        /// Gap between staggered items. Past ~80 ms a list starts to feel slow.
        static let stagger: Double = 0.045
    }
}

extension StoryCategory {
    /// One tint per category, drawn from the same family as the mosaic so a story's square
    /// and its label read as the same colour.
    ///
    /// Used for fills and squares only. None of these reach 4.5:1 as small text on paper,
    /// which is why category labels are ink next to a coloured square, never coloured text.
    ///
    /// Teal and Rose joined when sports and entertainment did (2026-09-28), picked to sit
    /// clear of Jade and Sky, and of Vermilion and Plum, as mosaic squares side by side.
    var tint: Color {
        switch self {
        case .india: Color(hex: 0xE0592A)
        case .technology: Color(hex: 0x3550DA)
        case .business: Color(hex: 0x1E9A72)
        case .world: Color(hex: 0x4DA3E8)
        case .science: Color(hex: 0xA64B9C)
        case .sports: Color(hex: 0x138496)
        case .entertainment: Color(hex: 0xD6457A)
        }
    }
}

extension Nova {
    /// Whether an image with this name exists in the asset catalog.
    ///
    /// Lets a view fall back when artwork hasn't been added yet, instead of rendering
    /// SwiftUI's missing-image placeholder. Wrapped here rather than `#if os(iOS)` at the
    /// call site, since macOS is a real destination for this target.
    static func hasAsset(_ name: String) -> Bool {
        #if canImport(UIKit)
        UIImage(named: name) != nil
        #elseif canImport(AppKit)
        NSImage(named: name) != nil
        #else
        false
        #endif
    }
}

extension Story {
    /// "2 hours ago" — relative time reads faster than a timestamp in a feed.
    var publishedDescription: String {
        publishedAt.formatted(.relative(presentation: .named))
    }

    /// "2H AGO" for the mono meta line. Abbreviated, because the line also carries the
    /// publisher and has to fit beside a thumbnail.
    var shortAge: String {
        let seconds = max(Date.now.timeIntervalSince(publishedAt), 0)
        switch seconds {
        case ..<3600: return "\(max(Int(seconds / 60), 1))m"
        case ..<86_400: return "\(Int(seconds / 3600))h"
        default: return "\(Int(seconds / 86_400))d"
        }
    }
}

// MARK: - Colour helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// A colour that follows the appearance. Paper has to go dark in Dark Mode like any
    /// system surface; a fixed hex would leave a white sheet glaring at night.
    static func dynamic(light: UInt32, dark: UInt32) -> Color {
        #if canImport(UIKit)
        Color(uiColor: UIColor { traits in
            UIColor(Color(hex: traits.userInterfaceStyle == .dark ? dark : light))
        })
        #elseif canImport(AppKit)
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? dark : light))
        })
        #else
        Color(hex: light)
        #endif
    }
}

// MARK: - Surfaces

extension View {
    /// The reading ground behind a scrolling paper screen.
    func novaPaperSurface() -> some View {
        background(Nova.paper.ignoresSafeArea())
    }

    /// Everything a charcoal screen needs: the ground, a dark appearance for the controls
    /// inside it, and a navigation bar that matches so the status bar turns white.
    ///
    /// `.environment(\.colorScheme)` rather than `.preferredColorScheme`: the preference
    /// flips the whole window, so the paper reader underneath went dark mid-push.
    func novaCharcoalSurface() -> some View {
        environment(\.colorScheme, .dark)
            .background(Nova.charcoal.ignoresSafeArea())
            .novaCharcoalBar()
    }

    /// `toolbarBackground` and `toolbarColorScheme` for the navigation bar are iOS-only.
    fileprivate func novaCharcoalBar() -> some View {
        #if os(iOS) || os(visionOS)
        toolbarBackground(Nova.charcoal, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        #else
        self
        #endif
    }

    /// Mono capitals with the wide tracking the Habits labels use.
    func novaMeta(_ style: Font.TextStyle = .caption, weight: Font.Weight = .medium) -> some View {
        font(Nova.meta(style, weight: weight))
            .textCase(.uppercase)
            .tracking(1.2)
    }

    /// `navigationBarTitleDisplayMode` doesn't exist on macOS, and the target builds
    /// for Mac as well as iOS. On Mac the title is already compact, so doing nothing
    /// gives the same result.
    func novaInlineTitle() -> some View {
        #if os(iOS) || os(visionOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// The round is the one immersive screen: its flood runs to the top edge, where a
    /// status bar would sit over it. `statusBarHidden` is iOS-only.
    func novaHiddenStatusBar() -> some View {
        #if os(iOS)
        statusBarHidden(true)
        #else
        self
        #endif
    }

    /// Same story as `novaInlineTitle`: the navigation bar placement is iOS-only.
    func novaHiddenNavigationBar() -> some View {
        #if os(iOS) || os(visionOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
