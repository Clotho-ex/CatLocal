#include <metal_stdlib>
using namespace metal;

struct DustRevealUniforms {
    float4 imageRect;
    float2 drawableSize;
    float progress;
    float particleSize;
    float2 subjectProtectionRange;
    float4 particleMotion;
    float4 particleDepth;
    float4 particleFade;
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

float dustValueNoise(float2 value) {
    float2 cell = floor(value);
    float2 fraction = fract(value);
    float2 blend = fraction * fraction * (3.0 - 2.0 * fraction);
    float bottom = mix(dustHash(cell), dustHash(cell + float2(1.0, 0.0)), blend.x);
    float top = mix(
        dustHash(cell + float2(0.0, 1.0)),
        dustHash(cell + float2(1.0, 1.0)),
        blend.x
    );
    return mix(bottom, top, blend.y);
}

float dustFlowNoise(float2 textureCoordinate) {
    float broad = dustValueNoise(textureCoordinate * float2(5.0, 7.0));
    float detail = dustValueNoise(textureCoordinate * float2(17.0, 23.0) + 11.7);
    return broad * 0.72 + detail * 0.28;
}

float dustErosionThreshold(float2 textureCoordinate, float noise) {
    return clamp(
        0.04
            + saturate(textureCoordinate.x) * 0.68
            + (1.0 - saturate(textureCoordinate.y)) * 0.18
            + (saturate(noise) - 0.5) * 0.14,
        0.02,
        0.94
    );
}

float dustSurvival(float progress, float threshold) {
    if (progress <= 0.0) {
        return 1.0;
    }
    if (progress >= 1.0) {
        return 0.0;
    }
    return 1.0 - smoothstep(threshold - 0.025, threshold + 0.025, progress);
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
    texture2d<float> backgroundTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::linear);
    float4 source = backgroundTexture.sample(textureSampler, in.textureCoordinate);
    float noise = dustFlowNoise(in.textureCoordinate);
    float threshold = dustErosionThreshold(in.textureCoordinate, noise);
    float survival = dustSurvival(uniforms.progress, threshold);
    return half4(source * survival);
}

vertex DustParticleOut dustParticleVertex(
    uint vertexID [[vertex_id]],
    constant DustRevealUniforms& uniforms [[buffer(0)]],
    texture2d<float> backgroundTexture [[texture(0)]],
    texture2d<float> subjectProtectionTexture [[texture(1)]]
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

    float4 background = backgroundTexture.sample(textureSampler, textureCoordinate);
    float protectionMask = subjectProtectionTexture.sample(
        textureSampler,
        textureCoordinate
    ).r;
    float subjectProtection = smoothstep(
        uniforms.subjectProtectionRange.x,
        uniforms.subjectProtectionRange.y,
        protectionMask
    );
    float emissionNoise = dustFlowNoise(textureCoordinate);
    float emissionThreshold = clamp(
        dustErosionThreshold(textureCoordinate, emissionNoise)
            - 0.018
            + (seed - 0.5) * 0.012,
        0.0,
        0.94
    );
    float particleLifetime = max(1.0 - emissionThreshold, 0.06);
    float age = saturate((uniforms.progress - emissionThreshold) / particleLifetime);
    bool hasBackgroundAlpha = background.a > (1.0 / 255.0);
    bool hasBackgroundColor = dot(background.rgb, float3(1.0)) > (1.0 / 1024.0);
    float protectionContribution = 1.0 - subjectProtection;
    bool isFullyProtected = protectionContribution <= 0.001;

    if (!hasBackgroundAlpha || !hasBackgroundColor || isFullyProtected
        || uniforms.progress < emissionThreshold) {
        out.position = float4(2.0, 2.0, 0.0, 1.0);
        out.pointSize = 1.0;
        out.color = float3(0.0);
        out.opacity = 0.0;
        return out;
    }

    if (age >= uniforms.particleFade.z) {
        out.position = float4(2.0, 2.0, 0.0, 1.0);
        out.pointSize = 1.0;
        out.color = float3(0.0);
        out.opacity = 0.0;
        return out;
    }

    float depthProgress = smoothstep(0.0, 1.0, age);
    float depthVariation = mix(
        uniforms.particleDepth.z,
        uniforms.particleDepth.w,
        secondarySeed
    );
    float forwardProgress = saturate(
        pow(depthProgress, uniforms.particleFade.w) * depthVariation
    );
    float imageAspectRatio = max(uniforms.particleMotion.w, 0.01);
    float2 centered = textureCoordinate * 2.0 - 1.0;
    centered.x *= imageAspectRatio;
    centered *= 1.0 + uniforms.particleMotion.y * forwardProgress;
    centered.x /= imageAspectRatio;
    float2 perspectiveCoordinate = (centered + 1.0) * 0.5;

    float directionSeed = dustHash(float2(column + 97u, row + 41u));
    float directionAngle = directionSeed * 6.28318530718;
    float2 randomDirection = float2(cos(directionAngle), sin(directionAngle));
    randomDirection.x /= imageAspectRatio;
    float2 animatedCoordinate = perspectiveCoordinate
        + randomDirection * uniforms.particleMotion.z * forwardProgress;
    float birth = smoothstep(0.0, uniforms.particleFade.x, age);
    float fade = 1.0 - smoothstep(
        uniforms.particleFade.y,
        uniforms.particleFade.z,
        age
    );
    float3 straightSourceColor = background.rgb / max(background.a, 1.0 / 255.0);
    float basePointSize = uniforms.particleSize * (0.82 + seed * 0.42);
    float depthScale = mix(
        uniforms.particleDepth.x,
        uniforms.particleDepth.y,
        forwardProgress
    );

    out.position = dustPosition(animatedCoordinate, uniforms);
    out.pointSize = clamp(
        basePointSize * depthScale,
        1.0,
        uniforms.particleMotion.x
    );
    out.color = straightSourceColor;
    out.opacity = background.a
        * protectionContribution
        * birth
        * fade
        * (0.82 + secondarySeed * 0.18);
    return out;
}

fragment half4 dustParticleFragment(
    DustParticleOut in [[stage_in]],
    float2 pointCoordinate [[point_coord]],
    constant DustRevealUniforms& uniforms [[buffer(0)]]
) {
    float2 pixel = in.position.xy;
    bool isInsideImage = pixel.x >= uniforms.imageRect.x
        && pixel.x <= uniforms.imageRect.x + uniforms.imageRect.z
        && pixel.y >= uniforms.imageRect.y
        && pixel.y <= uniforms.imageRect.y + uniforms.imageRect.w;
    float2 centered = pointCoordinate - 0.5;
    float distanceFromCenter = length(centered) * 2.0;
    if (!isInsideImage || distanceFromCenter > 1.0 || in.opacity <= 0.0) {
        discard_fragment();
    }
    float softEdge = 1.0 - smoothstep(0.62, 1.0, distanceFromCenter);
    float alpha = in.opacity * softEdge;
    return half4(half3(in.color * alpha), half(alpha));
}
