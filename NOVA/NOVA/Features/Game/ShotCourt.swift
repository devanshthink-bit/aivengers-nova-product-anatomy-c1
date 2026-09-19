//
//  ShotCourt.swift
//  NOVA
//

import CoreGraphics
import Foundation

/// The court and the physics of one shot.
///
/// The player pulls the ball back like a slingshot and lets go: the pull sets the launch
/// speed, the opposite direction sets the aim, and gravity does the rest. They are shown
/// the start of the arc and the beginning of the drop, not the landing, so the shot has
/// to be judged rather than pointed.
///
/// Pull-back only works because the drag sets *velocity*. An earlier version mapped drag
/// straight to a landing point, which meant the far hoops needed a pull longer than the
/// screen had room for.
///
/// All of it is plain math kept out of the view, so the feel can be tuned and tested.
/// Coordinates are in the court's own space, with the origin at its top-left.
struct ShotCourt: Equatable {

    // MARK: - Hoop

    struct Hoop: Equatable {
        /// The lane this hoop stays inside while it patrols.
        let cell: CGRect
        /// Panel carrying the answer text.
        let backboard: CGRect
        /// Centre of the rim opening.
        let rimCentre: CGPoint
        let rimHalfWidth: CGFloat
        let netDepth: CGFloat

        var rimHalfHeight: CGFloat { rimHalfWidth * 0.26 }

        /// Where the rim and net are drawn, with the rim sitting on the top edge.
        var drawingFrame: CGRect {
            CGRect(
                x: rimCentre.x - rimHalfWidth,
                y: rimCentre.y - rimHalfHeight,
                width: rimHalfWidth * 2,
                height: rimHalfHeight * 2 + netDepth
            )
        }

        func shifted(by dx: CGFloat) -> Hoop {
            guard dx != 0 else { return self }
            return Hoop(
                cell: cell,
                backboard: backboard.offsetBy(dx: dx, dy: 0),
                rimCentre: CGPoint(x: rimCentre.x + dx, y: rimCentre.y),
                rimHalfWidth: rimHalfWidth,
                netDepth: netDepth
            )
        }
    }

    // MARK: - Shot result

    enum Outcome: Equatable {
        /// Dropped cleanly through this hoop.
        case scored(basket: Int)
        /// Caught the rim and bounced out. Costs nothing but another shot.
        case rim(basket: Int)
        /// Nowhere near.
        case missed

        var basket: Int? {
            switch self {
            case .scored(let basket), .rim(let basket): basket
            case .missed: nil
            }
        }
    }

    /// A simulated shot: the path the ball takes and what it hit.
    struct Trajectory: Equatable {
        let points: [CGPoint]
        let duration: Double
        let outcome: Outcome
        /// Highest the ball got above where it was released.
        let maxRise: CGFloat
        /// Y of the farthest hoop. The ball shrinks as it travels toward this line.
        let horizonY: CGFloat

        var scoredBasket: Int? {
            if case .scored(let basket) = outcome { return basket }
            return nil
        }

        /// Position along the path. Progress is linear in time, because the physics
        /// already decides how the ball is spaced out.
        func point(atProgress progress: CGFloat) -> CGPoint {
            guard let first = points.first else { return .zero }
            guard points.count > 1 else { return first }

            let position = min(max(progress, 0), 1) * CGFloat(points.count - 1)
            let index = Int(position)
            guard index < points.count - 1 else { return points[points.count - 1] }

            let fraction = position - CGFloat(index)
            let from = points[index]
            let to = points[index + 1]
            return CGPoint(
                x: from.x + (to.x - from.x) * fraction,
                y: from.y + (to.y - from.y) * fraction
            )
        }
    }

    // MARK: - Stored

    let bounds: CGRect
    /// Where the ball rests. Pulling drags it back from here.
    let launchPoint: CGPoint
    let hoops: [Hoop]
    /// Downward acceleration, points per second squared.
    let gravity: CGFloat
    /// Launch speed in points per second, per point of pull.
    let speedScale: CGFloat
    /// Pulls shorter than this are a fumble, not a shot.
    let minimumDrag: CGFloat
    /// Power cap. Pulling further than this doesn't throw any harder.
    let maxPull: CGFloat
    let ballRadius: CGFloat

    init(
        bounds: CGRect,
        launchPoint: CGPoint,
        hoops: [Hoop],
        gravity: CGFloat = 1450,
        speedScale: CGFloat = 14,
        minimumDrag: CGFloat = 28,
        maxPull: CGFloat = 170,
        ballRadius: CGFloat = 22
    ) {
        self.bounds = bounds
        self.launchPoint = launchPoint
        self.hoops = hoops
        self.gravity = gravity
        self.speedScale = speedScale
        self.minimumDrag = minimumDrag
        self.maxPull = maxPull
        self.ballRadius = ballRadius
    }

    // MARK: - Layout

    /// Height reserved under each backboard for its rim and net.
    private static let hoopReserve: CGFloat = 54
    /// How far each basket can slide inside its cell.
    private static let patrolTravel: CGFloat = 28
    /// The ball rests this far up from the court's bottom edge, leaving room to pull back.
    private static let launchInset: CGFloat = 92

    static func layout(in size: CGSize, basketCount: Int) -> ShotCourt {
        let bounds = CGRect(origin: .zero, size: size)
        let launchPoint = CGPoint(x: size.width / 2, y: size.height - launchInset)
        guard basketCount > 0 else {
            return ShotCourt(bounds: bounds, launchPoint: launchPoint, hoops: [])
        }

        let columns = min(basketCount, 2)
        let rows = Int((Double(basketCount) / Double(columns)).rounded(.up))
        let gap: CGFloat = 12
        let topInset: CGFloat = 4

        let cellWidth = (size.width - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let availableHeight = size.height * 0.62
        let cellHeight = min(160, (availableHeight - gap * CGFloat(rows - 1)) / CGFloat(rows))
        let travel = min(patrolTravel, cellWidth * 0.18)
        let basketWidth = cellWidth - travel
        let basketHeight = max(cellHeight - hoopReserve, 40)

        let hoops = (0..<basketCount).map { index -> Hoop in
            let column = index % columns
            let row = index / columns
            let cell = CGRect(
                x: CGFloat(column) * (cellWidth + gap),
                y: topInset + CGFloat(row) * (cellHeight + gap),
                width: cellWidth,
                height: cellHeight
            )
            // Same-size baskets on opposite sides of the cell so a far rim is not
            // sitting on a near one. Each still patrols the leftover travel.
            let restX = row.isMultiple(of: 2) ? cell.minX : cell.maxX - basketWidth
            let backboard = CGRect(
                x: restX,
                y: cell.minY,
                width: basketWidth,
                height: basketHeight
            )

            return Hoop(
                cell: cell,
                backboard: backboard,
                rimCentre: CGPoint(x: backboard.midX, y: backboard.maxY + 5),
                rimHalfWidth: backboard.width / 2,
                netDepth: 28
            )
        }

        return ShotCourt(bounds: bounds, launchPoint: launchPoint, hoops: hoops)
    }

    /// Same court with each hoop slid sideways. Used so a shot is judged against
    /// where the baskets actually are, not where they rest.
    func withHoopOffsets(_ offsets: [CGFloat]) -> ShotCourt {
        ShotCourt(
            bounds: bounds,
            launchPoint: launchPoint,
            hoops: hoops.enumerated().map { index, hoop in
                hoop.shifted(by: offsets.indices.contains(index) ? offsets[index] : 0)
            },
            gravity: gravity,
            speedScale: speedScale,
            minimumDrag: minimumDrag,
            maxPull: maxPull,
            ballRadius: ballRadius
        )
    }

    /// Smaller Y is farther up the court, so this is the hoop that sits deepest.
    var horizonY: CGFloat {
        hoops.map(\.rimCentre.y).min() ?? launchPoint.y
    }

    // MARK: - Pulling back

    /// Was the pull long enough to count as a shot?
    func isShot(_ drag: CGSize) -> Bool {
        hypot(drag.width, drag.height) >= minimumDrag
    }

    /// The pull, capped at `maxPull`. Everything downstream works from this, so the cap
    /// applies to the physics and not just the picture.
    func effectivePull(_ drag: CGSize) -> CGSize {
        let distance = hypot(drag.width, drag.height)
        guard distance > maxPull, distance > 0 else { return drag }
        let scale = maxPull / distance
        return CGSize(width: drag.width * scale, height: drag.height * scale)
    }

    /// Where the ball is released from: pulled back from its resting place.
    func shotOrigin(for drag: CGSize) -> CGPoint {
        let pull = effectivePull(drag)
        return CGPoint(x: launchPoint.x + pull.width, y: launchPoint.y + pull.height)
    }

    /// The ball as drawn while aiming, kept inside the court. At the very longest pulls
    /// this sits slightly above the true release point; the sling line and the arc
    /// preview are what the player actually reads.
    func ballPosition(for drag: CGSize) -> CGPoint {
        let origin = shotOrigin(for: drag)
        return CGPoint(
            x: min(max(origin.x, bounds.minX + ballRadius), bounds.maxX - ballRadius),
            y: min(max(origin.y, bounds.minY + ballRadius), bounds.maxY - ballRadius)
        )
    }

    /// Launch velocity: opposite the pull, scaled up.
    func launchVelocity(for drag: CGSize) -> CGSize {
        let pull = effectivePull(drag)
        return CGSize(width: -pull.width * speedScale, height: -pull.height * speedScale)
    }

    /// The pull that would sink a given hoop in `flightTime` seconds.
    ///
    /// Used by tests, and the honest definition of "this hoop is reachable". Both the
    /// release point and the velocity depend on the pull, which is why the solve divides
    /// by `1 - speedScale * flightTime`.
    func pull(toReach hoop: Hoop, flightTime: Double) -> CGSize {
        let time = CGFloat(flightTime)
        let denominator = 1 - speedScale * time
        guard abs(denominator) > 0.0001 else { return .zero }

        return CGSize(
            width: (hoop.rimCentre.x - launchPoint.x) / denominator,
            height: (hoop.rimCentre.y - launchPoint.y - 0.5 * gravity * time * time) / denominator
        )
    }

    // MARK: - Simulation

    private static let step = 1.0 / 240.0
    private static let maxFlightTime = 2.6
    /// How far below the court a finger may reasonably travel while pulling back. There
    /// is screen there — the bottom bar — and a drag keeps tracking outside the view.
    static let pullRoomBelowCourt: CGFloat = 80

    /// Flies the ball and reports where it ended up.
    ///
    /// A hoop only scores on the way *down*, so passing over a near hoop en route to a
    /// far one is not a basket. Clipping the rim reflects the ball and it drops away.
    func trajectory(for drag: CGSize) -> Trajectory {
        var position = shotOrigin(for: drag)
        let origin = position
        // Velocity as a vector: width is horizontal, height is vertical (down positive).
        var velocity = launchVelocity(for: drag)
        var points = [position]
        var elapsed = 0.0
        var outcome = Outcome.missed
        /// Set once the ball has hit something, to let the follow-through play out.
        var stopAt: Double?

        let dt = CGFloat(Self.step)

        while elapsed < Self.maxFlightTime {
            let previous = position
            velocity.height += gravity * dt
            position.x += velocity.width * dt
            position.y += velocity.height * dt
            elapsed += Self.step
            points.append(position)

            // Hoops only catch the ball on the way down, so passing over a near hoop en
            // route to a far one is not a basket.
            if stopAt == nil, velocity.height > 0 {
                for (index, hoop) in hoops.enumerated()
                where previous.y <= hoop.rimCentre.y && position.y >= hoop.rimCentre.y {
                    let offset = abs(position.x - hoop.rimCentre.x)
                    // A clean drop needs the ball's middle inside the opening.
                    if offset <= hoop.rimHalfWidth - ballRadius * 0.12 {
                        outcome = .scored(basket: index)
                        velocity.width *= 0.3
                        stopAt = elapsed + 0.14
                    } else if offset <= hoop.rimHalfWidth + ballRadius * 0.7 {
                        outcome = .rim(basket: index)
                        // Clank: bounce back up and off to the side, then let it fall.
                        velocity.height *= -0.4
                        velocity.width = velocity.width * 0.5
                            + (position.x < hoop.rimCentre.x ? -150 : 150)
                        stopAt = elapsed + 0.45
                    }
                    if stopAt != nil { break }
                }
            }

            if let stopAt, elapsed >= stopAt { break }

            let escaped = position.y > bounds.maxY + 80
                || position.x < bounds.minX - 120
                || position.x > bounds.maxX + 120
            if escaped { break }
        }

        let highest = points.map(\.y).min() ?? origin.y
        return Trajectory(
            points: points,
            duration: elapsed,
            outcome: outcome,
            maxRise: max(origin.y - highest, 1),
            horizonY: horizonY
        )
    }

    /// The path a tapped basket follows. Tapping is the no-drag path for VoiceOver and
    /// Switch Control, so it always goes in.
    func guaranteedTrajectory(intoBasketAt index: Int, flightTime: Double = 1.05) -> Trajectory {
        guard hoops.indices.contains(index) else {
            return Trajectory(points: [launchPoint], duration: 0, outcome: .missed, maxRise: 1, horizonY: horizonY)
        }

        // Reuse the parabola the physics would produce for a perfect pull.
        let hoop = hoops[index]
        let drag = pull(toReach: hoop, flightTime: flightTime)
        let origin = shotOrigin(for: drag)
        let velocity = launchVelocity(for: drag)

        let steps = 90
        let points = (0...steps).map { step -> CGPoint in
            let time = CGFloat(flightTime) * CGFloat(step) / CGFloat(steps)
            return CGPoint(
                x: origin.x + velocity.width * time,
                y: origin.y + velocity.height * time + 0.5 * gravity * time * time
            )
        }

        let highest = points.map(\.y).min() ?? origin.y
        return Trajectory(
            points: points,
            duration: flightTime,
            outcome: .scored(basket: index),
            maxRise: max(origin.y - highest, 1),
            horizonY: horizonY
        )
    }
}

extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}
