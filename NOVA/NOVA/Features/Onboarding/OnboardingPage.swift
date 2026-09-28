//
//  OnboardingPage.swift
//  NOVA
//

import Foundation

/// The six pages between first launch and the reader, in order.
///
/// The loop is sold before anything else is asked: the manifesto and the ritual come
/// before the name and the topics. The one exception is the language, which comes first
/// of all — a Hindi reader shouldn't have to get through two English pages to find it.
enum OnboardingPage: Int, CaseIterable, Hashable, Sendable {
    case language
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
