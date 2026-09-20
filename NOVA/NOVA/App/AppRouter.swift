//
//  AppRouter.swift
//  NOVA
//

import Foundation
import Observation

/// The reader is the root of the Scroll tab, so it isn't a route. The quiz steps are.
enum Route: Hashable {
    case quizIntro
    case quiz
    case results
}

/// Where the Home tab can navigate. A source is identified by its name rather than by the
/// `RSSFeed` value so the path stays cheap to compare and safe to restore.
enum HomeRoute: Hashable {
    case source(String)
    case story(StoryID)
}

/// Which tab is showing.
///
/// Scroll is the default: the swipe deck is what the app was before Home existed, and
/// landing somewhere else would change the app's opening move for existing readers.
enum AppTab: Hashable {
    case home
    case scroll
}

/// Navigation state, kept out of the views and out of the game logic.
@Observable
final class AppRouter {
    var tab: AppTab = AppRouter.initialTab

    /// DEBUG only, and read-only like the onboarding arguments: `-startTab home` opens
    /// straight onto Home. Synthetic taps aren't available from a shell and `simctl` has
    /// no `tap`, so this is the only way to screenshot the other tab.
    ///
    /// Read-only matters — a launch argument lives in `NSArgumentDomain`, which outranks
    /// the app's own defaults for the whole process, so anything that also *writes* the
    /// value would appear not to take. See the `hasSeenWelcome` note in CLAUDE.md.
    private static var initialTab: AppTab {
        #if DEBUG
        if UserDefaults.standard.string(forKey: "startTab") == "home" { return .home }
        #endif
        return .scroll
    }

    /// DEBUG only: `-openSource "BBC News"` pushes that source page on launch, which is
    /// the only way to screenshot it without synthetic taps.
    private static var initialHomePath: [HomeRoute] {
        #if DEBUG
        if let source = UserDefaults.standard.string(forKey: "openSource"), !source.isEmpty {
            return [.source(source)]
        }
        #endif
        return []
    }
    var path: [Route] = []
    /// Home's own stack, kept separate so pushing a source can't disturb a quiz in
    /// progress on the other tab.
    var homePath: [HomeRoute] = AppRouter.initialHomePath

    func push(_ route: Route) {
        path.append(route)
    }

    /// Replaces the stack so finished steps can't be swiped back into.
    /// Going from the quiz to the results should not leave the quiz behind it.
    func replace(with routes: [Route]) {
        path = routes
    }

    func popToReader() {
        path.removeAll()
    }

    func pushHome(_ route: HomeRoute) {
        homePath.append(route)
    }
}
