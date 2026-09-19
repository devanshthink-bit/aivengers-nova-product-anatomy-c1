//
//  RippleWave+Shader.swift
//  NOVA
//

import SwiftUI

extension RippleWave {
    /// The `ripple` layer effect for this moment of the ring.
    func shader(at progress: Double) -> Shader {
        ShaderLibrary.ripple(
            .float2(origin),
            .float(radius(at: progress)),
            .float(tuning.bandWidth),
            .float(amplitude(at: progress)),
            .float(tuning.highlight)
        )
    }

    /// The shader pulls samples up to `amplitude` points toward the origin, so the
    /// layer has to be rendered with at least that much slack on every side.
    var maxSampleOffset: CGSize {
        CGSize(width: tuning.amplitude, height: tuning.amplitude)
    }
}
