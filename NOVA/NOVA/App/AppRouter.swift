//
//  AppRouter.swift
//  NOVA
//

import Foundation
import Observation

/// The reader is the root of the app, so it isn't a route. Today's list is a sheet
/// presented over it rather than a screen you navigate to.
enum Route: Hashable {
    case quizIntro
    case quiz
    case results
}

/// Navigation state, kept out of the views and out of the game logic.
@Observable
final class AppRouter {
    var path: [Route] = []

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
}
