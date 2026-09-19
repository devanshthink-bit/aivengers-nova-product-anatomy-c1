//
//  RippleWaveTests.swift
//  NOVATests
//

import CoreGraphics
import Testing
@testable import NOVA

@Suite("Ripple wave")
struct RippleWaveTests {

    private static let size = CGSize(width: 400, height: 800)
    /// A drop near the bottom centre, where the CTA sits.
    private static let wave = RippleWave(origin: CGPoint(x: 200, y: 720), in: size)

    @Test("Reach is the distance to the farthest corner")
    func reachIsFarthestCorner() {
        // Farthest corner from (200, 720) in a 400×800 space is a top corner: (0, 0) or (400, 0).
        let expected = hypot(200.0 as CGFloat, 720.0 as CGFloat)
        #expect(abs(Self.wave.reach - expected) < 0.001)
    }

    @Test("Progress is elapsed time over duration, clamped to 0...1")
    func progressClamps() {
        let wave = Self.wave
        #expect(wave.progress(elapsed: -1) == 0)
        #expect(wave.progress(elapsed: 0) == 0)
        #expect(abs(wave.progress(elapsed: 0.45) - 0.5) < 0.001)
        #expect(wave.progress(elapsed: 0.9) == 1)
        #expect(wave.progress(elapsed: 5) == 1)
    }

    @Test("The ring starts at the origin and ends past the farthest corner")
    func radiusSpansTheScreen() {
        let wave = Self.wave
        #expect(wave.radius(at: 0) == 0)
        // At the end the far edge of the band has cleared the farthest corner.
        #expect(wave.radius(at: 1) >= wave.reach + wave.tuning.bandWidth)
    }

    @Test("The ring only ever moves outward")
    func radiusIsMonotonic() {
        let wave = Self.wave
        var last = wave.radius(at: 0)
        for step in 1...50 {
            let r = wave.radius(at: Double(step) / 50)
            #expect(r >= last)
            last = r
        }
    }

    @Test("The ring decelerates: it covers more ground early than late")
    func radiusEasesOut() {
        let wave = Self.wave
        let early = wave.radius(at: 0.25) - wave.radius(at: 0)
        let late = wave.radius(at: 1) - wave.radius(at: 0.75)
        #expect(early > late)
    }

    @Test("Amplitude decays to a fifth and never goes negative")
    func amplitudeDecays() {
        let wave = Self.wave
        #expect(abs(wave.amplitude(at: 0) - wave.tuning.amplitude) < 0.001)
        #expect(abs(wave.amplitude(at: 1) - wave.tuning.amplitude * 0.2) < 0.001)
        for step in 0...20 {
            #expect(wave.amplitude(at: Double(step) / 20) >= 0)
        }
        #expect(wave.amplitude(at: 0.5) < wave.amplitude(at: 0))
    }

    @Test("Completion flips exactly at the end")
    func completion() {
        let wave = Self.wave
        #expect(wave.isComplete(at: 0) == false)
        #expect(wave.isComplete(at: 0.999) == false)
        #expect(wave.isComplete(at: 1) == true)
    }

    @Test("Tuning is carried through")
    func tuningIsStored() {
        let tuning = RippleWave.Tuning(duration: 2, bandWidth: 50, amplitude: 10, highlight: 0.1)
        let wave = RippleWave(origin: .zero, in: Self.size, tuning: tuning)
        #expect(wave.tuning == tuning)
        #expect(abs(wave.progress(elapsed: 1) - 0.5) < 0.001)
    }
}
