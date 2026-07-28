#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

static float roundedBoxDistance(
    float2 point,
    float2 halfSize,
    float radius
) {
    float2 q = abs(point) - halfSize + radius;
    return length(max(q, float2(0.0)))
        + min(max(q.x, q.y), 0.0)
        - radius;
}

static float2 roundedBoxNormal(
    float2 point,
    float2 halfSize,
    float radius
) {
    constexpr float epsilon = 0.55;
    float dx = roundedBoxDistance(
        point + float2(epsilon, 0.0),
        halfSize,
        radius
    ) - roundedBoxDistance(
        point - float2(epsilon, 0.0),
        halfSize,
        radius
    );
    float dy = roundedBoxDistance(
        point + float2(0.0, epsilon),
        halfSize,
        radius
    ) - roundedBoxDistance(
        point - float2(0.0, epsilon),
        halfSize,
        radius
    );
    return normalize(float2(dx, dy) + 0.0001);
}

/// Rounded-rectangle adaptation of KKarsyline/liquid-glass's orbGlassLens.
/// The same edge-band curve, refraction direction, chromatic split and
/// five-tap edge blur are preserved; only the circle distance is replaced by
/// a continuous rounded-box signed distance.
[[ stitchable ]] half4 roundedRectGlassLens(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float cornerRadius,
    float strength,
    float dispersion,
    float magnify,
    float rimWidth
) {
    float2 halfSize = max(size * 0.5, float2(1.0));
    float radius = clamp(cornerRadius, 0.0, min(halfSize.x, halfSize.y));
    float2 centered = position - halfSize;
    float distance = roundedBoxDistance(centered, halfSize, radius);

    if (distance > 1.0) {
        return half4(0.0);
    }

    float insideDepth = max(-distance, 0.0);
    float rimDepth = max(1.0, rimWidth * min(size.x, size.y) * 0.5);
    float t = 1.0 - smoothstep(0.0, rimDepth, insideDepth);
    float band = pow(t, 2.6);
    float2 normal = roundedBoxNormal(centered, halfSize, radius);

    float minHalf = max(min(halfSize.x, halfSize.y), 1.0);
    float normalizedDepth = clamp(insideDepth / minHalf, 0.0, 1.0);
    float bulge = 1.0 - normalizedDepth * normalizedDepth;
    float magPull = magnify * minHalf * 0.42 * bulge;
    float edgeBend = strength * band;
    float2 baseOffset = -normal * (magPull + edgeBend);

    float chroma = dispersion * strength * 0.16 * band;
    float2 redOffset = baseOffset + normal * chroma;
    float2 blueOffset = baseOffset - normal * chroma;

    float blur = band * 2.0;
    float2 bx = float2(blur, 0.0);
    float2 by = float2(0.0, blur);

    half red = layer.sample(position + redOffset).r * 0.52h
        + layer.sample(position + redOffset + bx).r * 0.12h
        + layer.sample(position + redOffset - bx).r * 0.12h
        + layer.sample(position + redOffset + by).r * 0.12h
        + layer.sample(position + redOffset - by).r * 0.12h;
    half green = layer.sample(position + baseOffset).g * 0.52h
        + layer.sample(position + baseOffset + bx).g * 0.12h
        + layer.sample(position + baseOffset - bx).g * 0.12h
        + layer.sample(position + baseOffset + by).g * 0.12h
        + layer.sample(position + baseOffset - by).g * 0.12h;
    half blue = layer.sample(position + blueOffset).b * 0.52h
        + layer.sample(position + blueOffset + bx).b * 0.12h
        + layer.sample(position + blueOffset - bx).b * 0.12h
        + layer.sample(position + blueOffset + by).b * 0.12h
        + layer.sample(position + blueOffset - by).b * 0.12h;
    half alpha = layer.sample(position + baseOffset).a;
    half4 color = half4(red, green, blue, alpha);

    float thinRim = smoothstep(0.15, 0.55, insideDepth)
        * (1.0 - smoothstep(0.55, 1.35, insideDepth));
    float verticalFacing = smoothstep(0.18, 0.88, abs(normal.y));
    float rimLight = mix(0.22, 1.0, verticalFacing);
    color.rgb += half(thinRim * rimLight) * half3(0.075, 0.075, 0.072);
    return color;
}
