//
//  OnboardingPage.swift
//  NOVA
//

import Foundation

/// The five pages between first launch and the reader, in order.
///
/// The loop is sold before anything is asked: the manifesto and the ritual come first,
/// and only then does the flow ask for a name and some topics.
enum OnboardingPage: Int, CaseIterable, Hashable, Sendable {
    case manifesto
    case ritual
    case name
    case topics
    case ready

    /// The next page, or nil on the last one — which is the signal to hand over.
    var next: OnboardingPage? {
        OnboardingPage(rawValue: rawValue + 1)
    }

    var isLast: Bool { next == nil }

    /// 1-based position, for the progress dots.
    var number: Int { rawValue + 1 }

    static var count: Int { allCases.count }
}
