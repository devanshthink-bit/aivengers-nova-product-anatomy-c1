//
//  NovaTheme.swift
//  NOVA
//

import Foundation
import SwiftUI

/// A deliberately small set of shared values. Native type styles, materials and
/// controls do the rest of the work — there is no custom glass or colour system here.
enum Nova {
    static let accent = Color(red: 0.36, green: 0.31, blue: 0.93)

    static let cardCornerRadius: CGFloat = 20
    static let basketCornerRadius: CGFloat = 22
    static let storyCardCornerRadius: CGFloat = 28
    /// Same idea for the answer backboards, kept lighter since they carry less text.
    static let basketScrim: Double = 0.4
    static let screenPadding: CGFloat = 20
    /// Keeps story text from stretching into unreadable line lengths on iPad.
    static let readingMaxWidth: CGFloat = 620

    /// Headlines. San Francisco, so titles stay sharp against the serif body.
    static func display(_ style: Font.TextStyle) -> Font {
        .system(style, design: .default).weight(.bold)
    }

    /// Body copy. New York is the reading face.
    static func reading(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .serif).weight(weight)
    }
}

extension StoryCategory {
    var tint: Color {
        switch self {
        case .india: .orange
        case .technology: .indigo
        case .business: .teal
        case .world: .blue
        case .science: .purple
        }
    }
}

extension Story {
    /// "2 hours ago" — relative time reads faster than a timestamp in a feed.
    var publishedDescription: String {
        publishedAt.formatted(.relative(presentation: .named))
    }
}

extension View {
    /// Grounded content surface. Story and question text sits on this, never on glass.
    ///
    /// Opaque on purpose: `.background.secondary` alone is translucent, so over the
    /// gradient backdrop these cards would tint and body text would lose its floor.
    func novaCard(cornerRadius: CGFloat = Nova.cardCornerRadius) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius)
            ZStack {
                shape.fill(.background)
                shape.fill(.background.secondary)
            }
        }
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

    /// Same story as `novaInlineTitle`: the navigation bar placement is iOS-only.
    func novaHiddenNavigationBar() -> some View {
        #if os(iOS) || os(visionOS)
        toolbar(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }
}
