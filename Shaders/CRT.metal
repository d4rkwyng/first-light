#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// The tube: barrel curvature, scanlines that follow the warped raster,
// corner vignette, and a touch of phosphor bloom. One pass.
[[ stitchable ]] half4 crt(float2 position, SwiftUI::Layer layer,
                           float2 size, float warp, float scan) {
    float2 uv = position / size;
    float2 c = uv - 0.5;
    float r2 = dot(c, c);
    float2 warped = c * (1.0 + warp * r2) + 0.5;
    if (warped.x < 0.001 || warped.x > 0.999 ||
        warped.y < 0.001 || warped.y > 0.999) {
        return half4(0.0, 0.0, 0.0, 1.0);
    }
    float2 sample_at = warped * size;
    half4 color = layer.sample(sample_at);
    // soft bloom: neighbors above/below bleed in slightly
    half4 bloom = layer.sample(sample_at + float2(0.0, 1.4))
                + layer.sample(sample_at - float2(0.0, 1.4));
    color = color + bloom * 0.18;
    // scanlines locked to the warped raster
    float line = 1.0 - scan * (0.5 + 0.5 * sin(warped.y * size.y * 2.05));
    // corner shading
    float vignette = 1.0 - 1.35 * r2;
    color.rgb *= half(line * max(vignette, 0.5));
    color.a = 1.0;
    return color;
}
