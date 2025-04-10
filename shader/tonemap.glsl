#version 450 core

layout (local_size_x = 16, local_size_y = 16) in;

layout (binding = 0, rgba32f) uniform image2D color;

uniform float exposure;
uniform float gamma;
uniform ivec2 resolution;

float luma(const vec3 col) { return dot(col, vec3(0.212671f, 0.715160f, 0.072169f)); }

vec3 hable(in vec3 rgb) {
    const float A = 0.15f;
    const float B = 0.50f;
    const float C = 0.10f;
    const float D = 0.20f;
    const float E = 0.02f;
    const float F = 0.30f;
    return ((rgb * (A * rgb + C * B) + D * E) / (rgb * (A * rgb + B) + D * F)) - E / F;
}
vec3 hable_tonemap(in vec3 rgb, in float exposure) {
    const float W = 11.2f;
    return hable(exposure * rgb) / hable(vec3(W));
}

vec4 sanitize(const vec4 x) { return mix(x, vec4(0), isnan(x) || isinf(x)); }

void main() {
	const ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (any(greaterThanEqual(pixel, resolution))) return;
    // tonemap
    vec4 out_col = imageLoad(color, pixel);
    out_col.rgb = pow(hable_tonemap(out_col.rgb, exposure), vec3(1.f / gamma));
    imageStore(color, pixel, sanitize(out_col));
}
