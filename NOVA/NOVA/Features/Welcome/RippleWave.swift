//
//  RippleWave.swift
//  NOVA
//

import CoreGraphics
import Foundation

/// The geometry and timing of one drop: where it landed, how far the ring has to travel
/// to clear the screen, and how the ring's size and strength change over its life.
///
/// Plain maths with no SwiftUI, so the feel can be tuned and tested. The shader that
/// draws it and the view that drives it both read from here.
struct RippleWave: Equatable, Sendable {

    /// The knobs that decide how the water feels. Defaults were settled in the
    /// tuning preview; change them there first, then here.
    struct Tuning: Equatable, Sendable {
        /// How long the ring takes to clear the screen.
        var duration: Double = 0.9
        /// Thickness of the distorting band, in points.
        var bandWidth: CGFloat = 110
        /// How far a pixel inside the band is pulled toward the drop, in points, at the start.
        var amplitude: CGFloat = 26
        /// Strength of the white glow riding the wavefront, 0 to 1.
        var highlight: Double = 0.35
    }

    /// Where the drop landed, in the rippled layer's coordinate space.
    let origin: CGPoint
    /// Distance from the origin to the farthest corner of the layer.
    let reach: CGFloat
    let tuning: Tuning

    init(origin: CGPoint, in size: CGSize, tuning: Tuning = Tuning()) {
        self.origin = origin
        self.tuning = tuning
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: size.width, y: 0),
            CGPoint(x: 0, y: size.height),
            CGPoint(x: size.width, y: size.height),
        ]
        self.reach = corners.map { hypot($0.x - origin.x, $0.y - origin.y) }.max() ?? 0
    }

    /// Share of the ring's life that has passed, from 0 to 1.
    func progress(elapsed: TimeInterval) -> Double {
        guard tuning.duration > 0 else { return 1 }
        return min(max(elapsed / tuning.duration, 0), 1)
    }

    /// Radius of the ring's centre line. Eases out so the ring leaves the drop fast and
    /// slows as it spreads, the way a real ripple loses pace. Ends with the band's far
    /// edge past the farthest corner, so nothing is left mid-bend when the view moves on.
    func radius(at progress: Double) -> CGFloat {
        let p = min(max(progress, 0), 1)
        let eased = 1 - (1 - p) * (1 - p)
        return (reach + tuning.bandWidth) * CGFloat(eased)
    }

    /// How hard the band bends the picture at this moment. Fades to a fifth of its
    /// starting strength so the ring softens as it grows, rather than snapping off.
    func amplitude(at progress: Double) -> CGFloat {
        let p = min(max(progress, 0), 1)
        return tuning.amplitude * CGFloat(1 - 0.8 * p)
    }

    func isComplete(at progress: Double) -> Bool {
        progress >= 1
    }
}
