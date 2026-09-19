//
//  ShotCourtTests.swift
//  NOVATests
//

import CoreGraphics
import Testing
@testable import NOVA

@Suite("Shot court")
struct ShotCourtTests {

    private static let court = ShotCourt.layout(in: CGSize(width: 390, height: 500), basketCount: 4)

    // MARK: - Layout

    @Test("Four hoops are laid out without their backboards overlapping")
    func backboardsDoNotOverlap() {
        let hoops = Self.court.hoops
        #expect(hoops.count == 4)

        for (index, hoop) in hoops.enumerated() {
            for other in hoops[(index + 1)...] {
                #expect(hoop.backboard.intersects(other.backboard) == false)
            }
        }
    }

    @Test("Hoops sit above the ball")
    func hoopsSitAboveTheLaunchPoint() {
        for hoop in Self.court.hoops {
            #expect(hoop.rimCentre.y < Self.court.launchPoint.y)
        }
    }

    @Test("Every backboard is the same size")
    func backboardsAreUniform() {
        let first = Self.court.hoops[0].backboard
        for hoop in Self.court.hoops {
            #expect(abs(hoop.backboard.width - first.width) < 0.001)
            #expect(abs(hoop.backboard.height - first.height) < 0.001)
        }
    }

    @Test("The hoop is as wide as its backboard")
    func hoopMatchesBackboard() {
        for hoop in Self.court.hoops {
            #expect(abs(hoop.rimHalfWidth * 2 - hoop.backboard.width) < 0.5)
        }
    }

    // MARK: - Aiming

    @Test("A short drag is not a shot")
    func shortDragIsNotAShot() {
        #expect(Self.court.isShot(CGSize(width: 2, height: 4)) == false)
        #expect(Self.court.isShot(CGSize(width: 0, height: 80)) == true)
    }

    @Test("The shot fires opposite the pull")
    func shotFiresOppositeThePull() {
        let court = Self.court
        // Pulling down and right throws up and left.
        let velocity = court.launchVelocity(for: CGSize(width: 40, height: 90))

        #expect(velocity.width < 0)
        #expect(velocity.height < 0)
    }

    @Test("Pulling past the power cap doesn't throw any harder")
    func pullIsCapped() {
        let court = Self.court
        let hard = court.launchVelocity(for: CGSize(width: 0, height: 400))
        let capped = court.launchVelocity(for: CGSize(width: 0, height: court.maxPull))

        #expect(abs(hard.height - capped.height) < 0.001)
    }

    // MARK: - Physics

    @Test("Every hoop can be sunk within the pull the screen allows")
    func everyHoopIsScoreableWithinReach() {
        let court = Self.court

        for (index, hoop) in court.hoops.enumerated() {
            let pull = court.pull(toReach: hoop, flightTime: 1.05)

            #expect(court.trajectory(for: pull).outcome == .scored(basket: index))
            #expect(court.isShot(pull))
            // Within the power cap, or the shot is simply not makeable.
            #expect(hypot(pull.width, pull.height) <= court.maxPull)
            // Pulling back goes downward, off the bottom of the court but not off screen.
            #expect(pull.height > 0)

            let finger = CGPoint(
                x: court.launchPoint.x + pull.width,
                y: court.launchPoint.y + pull.height
            )
            #expect(finger.y <= court.bounds.maxY + ShotCourt.pullRoomBelowCourt)
            #expect(finger.x > court.bounds.minX)
            #expect(finger.x < court.bounds.maxX)
        }
    }

    @Test("Pulling the wrong way misses everything")
    func wrongWayShotMisses() {
        let court = Self.court
        // Pulling upward throws the ball down, away from every hoop.
        #expect(court.trajectory(for: CGSize(width: 0, height: -120)).outcome == .missed)
    }

    @Test("Clipping the edge of a hoop is a rim hit, not a basket")
    func edgeOfTheHoopHitsTheRim() {
        let court = Self.court
        let hoop = court.hoops[0]

        // Aim at a point just outside the opening but still on the rim.
        let offCentre = ShotCourt.Hoop(
            cell: hoop.cell,
            backboard: hoop.backboard,
            rimCentre: CGPoint(x: hoop.rimCentre.x + hoop.rimHalfWidth * 1.08, y: hoop.rimCentre.y),
            rimHalfWidth: hoop.rimHalfWidth,
            netDepth: hoop.netDepth
        )
        let pull = court.pull(toReach: offCentre, flightTime: 1.05)

        #expect(court.trajectory(for: pull).outcome == .rim(basket: 0))
    }

    @Test("A hoop cannot be scored on the way up")
    func passingOverAHoopIsNotABasket() {
        let court = Self.court
        // The far hoop is above the near row, so the ball crosses it climbing.
        let far = court.hoops[0]
        let pull = court.pull(toReach: far, flightTime: 1.05)
        let trajectory = court.trajectory(for: pull)

        #expect(trajectory.outcome == .scored(basket: 0))
        // It really did climb past the near row's rim height first.
        let nearRow = court.hoops[2].rimCentre.y
        #expect(trajectory.points.contains { $0.y < nearRow })
    }

    @Test("Tapping a basket always goes in")
    func tappedBasketAlwaysScores() {
        let court = Self.court

        for index in court.hoops.indices {
            let trajectory = court.guaranteedTrajectory(intoBasketAt: index)
            #expect(trajectory.outcome == .scored(basket: index))
            #expect(trajectory.points.count > 1)
        }
    }

    // MARK: - Path sampling

    @Test("The flight path starts where the ball was released and runs to the end")
    func pathCoversTheWholeFlight() {
        let court = Self.court
        let trajectory = court.guaranteedTrajectory(intoBasketAt: 0)

        #expect(trajectory.point(atProgress: 0) == trajectory.points.first)
        #expect(trajectory.point(atProgress: 1) == trajectory.points.last)
        // Mid-flight the ball is above where it started, because it's an arc.
        #expect(trajectory.point(atProgress: 0.5).y < court.launchPoint.y)
    }
}
