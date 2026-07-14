#include <metal_stdlib>
using namespace metal;

struct DustRevealUniforms {
    float4 imageRect;
    float2 drawableSize;
    float progress;
    float particleSize;
    float backgroundAlphaThreshold;
    uint4 particleInfo;
};

struct DustBackgroundOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct DustParticleOut {
    float4 position [[position]];
    float pointSize [[point_size]];
    float3 color;
    float opacity;
};

constant float2 dustQuadPositions[6] = {
    float2(0.0, 0.0),
    float2(1.0, 0.0),
    float2(0.0, 1.0),
    float2(1.0, 0.0),
    float2(1.0, 1.0),
    float2(0.0, 1.0)
};

float dustHash(float2 value) {
    return fract(sin(dot(value, float2(127.1, 311.7))) * 43758.5453);
}

float dustStaggeredProgress(float progress, float stagger) {
    float clampedStagger = clamp(stagger, 0.0, 0.999);
    return saturate((saturate(progress) - clampedStagger) / (1.0 - clampedStagger));
}

float dustTerminalSourceFade(float progress) {
    return 1.0 - smoothstep(0.82, 1.0, progress);
}

float4 dustPosition(float2 textureCoordinate, constant DustRevealUniforms& uniforms) {
    float2 pixel = uniforms.imageRect.xy + textureCoordinate * uniforms.imageRect.zw;
    float2 normalized = float2(
        pixel.x / max(uniforms.drawableSize.x, 1.0) * 2.0 - 1.0,
        1.0 - pixel.y / max(uniforms.drawableSize.y, 1.0) * 2.0
    );
    return float4(normalized, 0.0, 1.0);
}

vertex DustBackgroundOut dustBackgroundVertex(
    uint vertexID [[vertex_id]],
    constant DustRevealUniforms& uniforms [[buffer(0)]]
) {
    DustBackgroundOut out;
    float2 textureCoordinate = dustQuadPositions[vertexID];
    out.position = dustPosition(textureCoordinate, uniforms);
    out.textureCoordinate = textureCoordinate;
    return out;
}

fragment half4 dustBackgroundFragment(
    DustBackgroundOut in [[stage_in]],
    constant DustRevealUniforms& uniforms [[buffer(0)]],
    texture2d<float> sourceTexture [[texture(0)]],
    texture2d<float> cutoutTexture [[texture(1)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float4 source = sourceTexture.sample(textureSampler, in.textureCoordinate);
    float cutoutAlpha = cutoutTexture.sample(textureSampler, in.textureCoordinate).a;
    float inverseAlpha = 1.0 - cutoutAlpha;
    float stagger = dustHash(floor(in.textureCoordinate * 41.0)) * 0.18;
    float localProgress = dustStaggeredProgress(uniforms.progress, stagger);
    float backgroundSurvival = 1.0 - localProgress * inverseAlpha;
    float opacity = backgroundSurvival * dustTerminalSourceFade(uniforms.progress);
    return half4(half3(source.rgb), half(source.a * opacity));
}

vertex DustParticleOut dustParticleVertex(
    uint vertexID [[vertex_id]],
    constant DustRevealUniforms& uniforms [[buffer(0)]],
    texture2d<float> sourceTexture [[texture(0)]],
    texture2d<float> cutoutTexture [[texture(1)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    DustParticleOut out;
    uint columns = max(uniforms.particleInfo.y, 1u);
    uint rows = max(uniforms.particleInfo.z, 1u);
    uint column = vertexID % columns;
    uint row = vertexID / columns;
    float seed = dustHash(float2(column, row));
    float secondarySeed = dustHash(float2(row + 19u, column + 73u));
    float2 jitter = float2(seed, secondarySeed);
    float2 textureCoordinate = (
        float2(float(column), float(row)) + 0.16 + jitter * 0.68
    ) / float2(float(columns), float(rows));
    textureCoordinate = clamp(textureCoordinate, 0.0, 1.0);

    float cutoutAlpha = cutoutTexture.sample(textureSampler, textureCoordinate).a;
    float delay = seed * 0.22 + textureCoordinate.x * 0.10;
    float localProgress = dustStaggeredProgress(uniforms.progress, delay);
    bool isBackground = cutoutAlpha < uniforms.backgroundAlphaThreshold;

    if (!isBackground || localProgress <= 0.0) {
        out.position = float4(2.0, 2.0, 0.0, 1.0);
        out.pointSize = 1.0;
        out.color = float3(0.0);
        out.opacity = 0.0;
        return out;
    }

    float turbulence = sin(localProgress * 13.0 + seed * 19.0) * (0.009 + secondarySeed * 0.009);
    float2 drift = float2(
        localProgress * (0.08 + seed * 0.09),
        -localProgress * (0.05 + secondarySeed * 0.10)
    );
    float2 animatedCoordinate = textureCoordinate + drift + float2(turbulence, turbulence * -0.55);
    float birth = smoothstep(0.0, 0.055, localProgress);
    float fade = pow(max(1.0 - localProgress, 0.0), 1.45);
    float3 sourceColor = sourceTexture.sample(textureSampler, textureCoordinate).rgb;

    out.position = dustPosition(animatedCoordinate, uniforms);
    out.pointSize = max(
        0.75,
        uniforms.particleSize * (0.70 + seed * 0.65) * (1.0 - localProgress * 0.88)
    );
    out.color = sourceColor;
    out.opacity = birth * fade * (0.48 + secondarySeed * 0.42);
    return out;
}

fragment half4 dustParticleFragment(
    DustParticleOut in [[stage_in]],
    float2 pointCoordinate [[point_coord]]
) {
    float2 centered = pointCoordinate - 0.5;
    float distanceFromCenter = length(centered) * 2.0;
    if (distanceFromCenter > 1.0 || in.opacity <= 0.0) {
        discard_fragment();
    }
    float softEdge = 1.0 - smoothstep(0.62, 1.0, distanceFromCenter);
    return half4(half3(in.color), half(in.opacity * softEdge));
}
