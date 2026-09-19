//
//  Ripple.metal
//  NOVA
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI.h>
using namespace metal;

/// One ring of water passing over the layer.
///
/// Inside a band of `bandWidth` centred on `radius` from `origin`, each pixel samples the
/// layer from a point pulled toward the origin — that is the bend — and is lightened by a
/// glow that peaks on the ring's centre line. Outside the band the layer is untouched, so
/// text ahead of and behind the ring stays crisp.
///
/// `position` and `origin` are in the layer's own points. The caller sets
/// `maxSampleOffset` to at least `amplitude` so the displaced samples are available.
[[ stitchable ]] half4 ripple(float2 position,
                              SwiftUI::Layer layer,
                              float2 origin,
                              float radius,
                              float bandWidth,
                              float amplitude,
                              float highlight) {
    float d = distance(position, origin);
    // -1 at the band's inner edge, 0 on the ring, +1 at the outer edge.
    float x = (d - radius) / bandWidth;

    if (abs(x) >= 1.0 || d < 0.5) {
        return layer.sample(position);
    }

    // Peaks on the ring, zero at both edges, so the band has no hard border.
    float falloff = 1.0 - abs(x);
    float2 towardOrigin = (origin - position) / d;
    float shift = amplitude * sin(x * M_PI_F) * falloff;

    half4 color = layer.sample(position + towardOrigin * shift);

    // The layer is opaque (its background is inside it), so a straight mix toward
    // white reads as a highlight rather than a haze.
    half glow = half(highlight * falloff * falloff);
    color.rgb = mix(color.rgb, half3(1.0h), glow * color.a);
    return color;
}
