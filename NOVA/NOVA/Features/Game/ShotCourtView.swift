//
//  ShotCourtView.swift
//  NOVA
//

import SwiftUI

/// The playfield: four hoops and one paper ball.
///
/// The view owns the aim, the flight and the net reaction. It reports the basket the ball
/// dropped into and takes the result back as input — it never decides what is correct.
///
/// The player sees the start of the arc, not the drop or the landing. A live landing
/// preview turned the shot into pointing at the answer.
struct ShotCourtView: View {
    private static let letters = ["A", "B", "C", "D", "E", "F"]
    private static let ballSize: CGFloat = 50

    let question: Question
    /// 1-based, so shot 1 gets the first ball style.
    var shotNumber: Int = 1
    /// Non-nil once the shot has been judged.
    let result: AnswerSubmission?
    let onShoot: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SoundPlayer.self) private var sound

    @State private var drag: CGSize = .zero
    @State private var isAiming = false
    @State private var flight: ShotCourt.Trajectory?
    @State private var flightProgress: CGFloat = 0
    @State private var spin: Double = 0
    @State private var lastMiss: ShotCourt.Outcome?
    @State private var ballOpacity: Double = 1
    /// Per-hoop impact counters, so only the hoop that was hit moves its net.
    @State private var netImpacts: [Int: Int] = [:]

    var body: some View {
        GeometryReader { proxy in
            let court = ShotCourt.layout(in: proxy.size, basketCount: question.answers.count)

            TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                let live = court.withHoopOffsets(hoopOffsets(at: timeline.date, in: court))

                ZStack {
                    backboards(in: live, rest: court)
                    hoops(in: live)
                    slingLine(in: live)
                    aimGuide(in: live)
                    ball(in: live, rest: court)
                    if let lastMiss { missBanner(for: lastMiss, in: live) }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .onChange(of: result) { _, newResult in
            guard let newResult else { return }
            sound.play(newResult.isCorrect ? .score : .miss)
        }
    }

    // MARK: - Pieces

    private func backboards(in court: ShotCourt, rest: ShotCourt) -> some View {
        ForEach(court.hoops.indices, id: \.self) { index in
            let hoop = court.hoops[index]
            AnswerBasketView(
                letter: Self.letters[min(index, Self.letters.count - 1)],
                answer: question.answers[index],
                style: .forBasket(index),
                appearance: appearance(for: index)
            ) {
                shoot(at: index, in: rest)
            }
            .frame(width: hoop.backboard.width, height: hoop.backboard.height)
            .position(hoop.backboard.center)
            .disabled(result != nil || flight != nil)
        }
    }

    private func hoops(in court: ShotCourt) -> some View {
        ForEach(court.hoops.indices, id: \.self) { index in
            let hoop = court.hoops[index]
            BasketHoopView(
                tint: hoopTint(for: index),
                highlight: hoopHighlight(for: index),
                netColor: hoopNet(for: index),
                rimHalfWidth: hoop.rimHalfWidth,
                netDepth: hoop.netDepth,
                impact: netImpacts[index] ?? 0
            )
            .frame(width: hoop.drawingFrame.width, height: hoop.drawingFrame.height)
            .position(hoop.drawingFrame.center)
            .allowsHitTesting(false)
        }
    }

    /// The taut line between the ball's resting place and where it's been pulled to, so
    /// the pull itself is visible and not just implied.
    @ViewBuilder
    private func slingLine(in court: ShotCourt) -> some View {
        if isAiming, flight == nil, result == nil {
            let ball = court.ballPosition(for: drag)
            Path { path in
                path.move(to: court.launchPoint)
                path.addLine(to: ball)
            }
            .stroke(
                Nova.accent.opacity(0.45),
                style: StrokeStyle(lineWidth: 2.5, lineCap: .round, dash: [5, 4])
            )
        }
    }

    /// A short dotted climb from the ball. Stops well before the peak so the drop
    /// still has to be judged.
    @ViewBuilder
    private func aimGuide(in court: ShotCourt) -> some View {
        if isAiming, court.isShot(drag), result == nil {
            let points = guidePoints(in: court)
            if points.count > 1 {
                Path { path in
                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Nova.accent.opacity(0.8), Nova.accent.opacity(0.14)],
                        startPoint: .bottom,
                        endPoint: .top
                    ),
                    style: StrokeStyle(lineWidth: 2.4, lineCap: .round, dash: [5, 5])
                )
            }
        }
    }

    /// Climb only, and not all the way to the top.
    private func guidePoints(in court: ShotCourt) -> [CGPoint] {
        let points = court.trajectory(for: drag).points
        guard points.count > 3 else { return points }
        let peak = points.indices.min(by: { points[$0].y < points[$1].y }) ?? 0
        let shown = max(Int(Double(peak) * 0.55), 8)
        return Array(points.prefix(min(shown, points.count)))
    }

    private func ball(in court: ShotCourt, rest: ShotCourt) -> some View {
        // The ball follows the finger back into the sling, which is the power feedback.
        // This offset stays put during the flight — `TrajectoryMotion` moves the ball
        // relative to the release point, so the two never double up.
        let pulled = court.ballPosition(for: drag)
        let pullOffset = CGSize(
            width: pulled.x - court.launchPoint.x,
            height: pulled.y - court.launchPoint.y
        )

        return GameBallView(style: .forShot(shotNumber))
            .frame(width: Self.ballSize, height: Self.ballSize)
            .rotationEffect(.degrees(spin))
            .opacity(result == nil ? ballOpacity : 0)
            .offset(pullOffset)
            // Padding first so the grab area is bigger than the ball, and the gesture
            // before `position` so it doesn't claim the whole court and swallow taps
            // on the backboards underneath.
            .padding(8)
            .contentShape(.circle)
            .gesture(aimGesture(in: rest))
            .position(court.launchPoint)
            .modifier(
                TrajectoryMotion(
                    progress: flightProgress,
                    trajectory: flight,
                    recede: reduceMotion ? 0 : 0.48
                )
            )
    }

    private func missBanner(for outcome: ShotCourt.Outcome, in court: ShotCourt) -> some View {
        let message: String
        let symbol: String
        switch outcome {
        case .rim:
            message = "Off the rim. So close."
            symbol = "circle.dashed"
        case .missed, .scored:
            message = "Short. Throw it harder."
            symbol = "arrow.up"
        }

        return Label(message, systemImage: symbol)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
            .position(x: court.bounds.midX, y: court.launchPoint.y - 58)
            .transition(.opacity)
            .accessibilityAddTraits(.isStaticText)
    }

    // MARK: - Aiming

    private func aimGesture(in court: ShotCourt) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard result == nil, flight == nil else { return }
                isAiming = true
                lastMiss = nil
                drag = value.translation
            }
            .onEnded { value in
                guard result == nil, flight == nil else { return }
                isAiming = false
                drag = value.translation
                release(in: court)
            }
    }

    private func appearance(for index: Int) -> AnswerBasketView.Appearance {
        guard let result else { return .idle }
        if index == result.chosenAnswerIndex { return result.isCorrect ? .correct : .incorrect }
        if index == result.correctAnswerIndex { return .revealedAnswer }
        return .dimmed
    }

    private func hoopTint(for index: Int) -> Color {
        guard let result else { return BasketStyle.forBasket(index).rim }
        if index == result.chosenAnswerIndex { return result.isCorrect ? .green : .red }
        if index == result.correctAnswerIndex { return .green }
        return BasketStyle.forBasket(index).rim
    }

    private func hoopHighlight(for index: Int) -> Color {
        guard result == nil else { return hoopTint(for: index).opacity(0.85) }
        return BasketStyle.forBasket(index).rimHighlight
    }

    private func hoopNet(for index: Int) -> Color {
        BasketStyle.forBasket(index).net
    }

    /// Each basket patrols its own cell. Periods and phases differ so they don't march
    /// in step.
    private func hoopOffsets(at date: Date, in court: ShotCourt) -> [CGFloat] {
        guard !reduceMotion else { return Array(repeating: 0, count: court.hoops.count) }

        return court.hoops.enumerated().map { index, hoop in
            let maxLeft = max(hoop.backboard.minX - hoop.cell.minX, 0)
            let maxRight = max(hoop.cell.maxX - hoop.backboard.maxX, 0)
            let period = 5.6 + Double(index) * 0.65
            let phase = Double(index) * 1.2
            let wave = (sin(date.timeIntervalSinceReferenceDate * 2 * .pi / period + phase) + 1) / 2
            return -maxLeft + CGFloat(wave) * (maxLeft + maxRight)
        }
    }

    // MARK: - Shooting

    /// Drag release. A drag that's too short is a fumble; anything that doesn't drop
    /// through a hoop costs nothing but another shot.
    private func release(in court: ShotCourt) {
        guard court.isShot(drag) else {
            withAnimation(.bouncy) { drag = .zero }
            return
        }
        let offsets = hoopOffsets(at: Date(), in: court)
        fly(court.withHoopOffsets(offsets).trajectory(for: drag))
    }

    /// Tapping a basket is the no-drag path, and always goes in.
    private func shoot(at index: Int, in court: ShotCourt) {
        guard result == nil, flight == nil else { return }
        drag = .zero
        let offsets = hoopOffsets(at: Date(), in: court)
        fly(court.withHoopOffsets(offsets).guaranteedTrajectory(intoBasketAt: index))
    }

    private func fly(_ trajectory: ShotCourt.Trajectory) {
        flight = trajectory
        sound.play(.shot)

        // Linear time: the simulation already decided how the ball is spaced out.
        let duration = reduceMotion ? 0 : min(max(trajectory.duration, 0.3), 1.6)

        withAnimation(.linear(duration: duration)) {
            flightProgress = 1
            spin = reduceMotion ? 0 : 540
        } completion: {
            land(trajectory)
        }
    }

    private func land(_ trajectory: ShotCourt.Trajectory) {
        switch trajectory.outcome {
        case .scored(let basket):
            netImpacts[basket, default: 0] += 1
            onShoot(basket)
        case .rim(let basket):
            netImpacts[basket, default: 0] += 1
            sound.play(.rim)
            lastMiss = trajectory.outcome
            returnBall()
        case .missed:
            sound.play(.miss)
            lastMiss = trajectory.outcome
            returnBall()
        }
    }

    /// Fades the ball out where it ended up and brings it back at rest.
    ///
    /// Deliberately not an animated reset: retracing the flight while also unwinding the
    /// pull offset animates the same movement twice and the ball takes a nonsense path.
    private func returnBall() {
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 150 : 350))
            withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.18)) { ballOpacity = 0 }

            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 190))
            flight = nil
            flightProgress = 0
            spin = 0
            drag = .zero
            withAnimation(.easeIn(duration: reduceMotion ? 0 : 0.2)) { ballOpacity = 1 }
        }
    }
}

/// Moves the ball along its path and shrinks it as it travels up the court.
///
/// Up the screen is farther away. The old cue swelled the ball at the apex, which made
/// the shot look like it was coming at you and then dropping in your lap.
private struct TrajectoryMotion: GeometryEffect {
    var progress: CGFloat
    let trajectory: ShotCourt.Trajectory?
    /// How much of the ball's size is lost by the time it reaches the far hoops.
    let recede: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        // Movement is relative to the release point, because the view this is applied to
        // is already sitting there, pulled back.
        guard let trajectory, let origin = trajectory.points.first else {
            return ProjectionTransform(.identity)
        }

        let point = trajectory.point(atProgress: progress)
        let span = max(origin.y - trajectory.horizonY, 1)
        let depth = min(max((origin.y - point.y) / span, 0), 1.15)
        let scale = 1.08 - recede * min(depth, 1)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)

        let transform = CGAffineTransform(translationX: -centre.x, y: -centre.y)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: centre.x, y: centre.y))
            .concatenating(
                CGAffineTransform(
                    translationX: point.x - origin.x,
                    y: point.y - origin.y
                )
            )

        return ProjectionTransform(transform)
    }
}

#Preview {
    ShotCourtView(question: MockNewsService.todayQuestions[1], shotNumber: 2, result: nil) { _ in }
        .frame(height: 460)
        .padding()
        .environment(SoundPlayer())
}
