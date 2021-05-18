#version 450 core

#include "common.h"

layout (local_size_x = 16, local_size_y = 16) in;

layout (binding = 0, rgba32f) uniform image2D color;
layout (binding = 1, rgba32f) uniform image2D even;

// ---------------------------------------------------
// path tracing

uniform int current_sample;
uniform int bounces;
uniform int show_environment;

vec3 trace_path(in vec3 pos, in vec3 dir, inout uint seed) {
    // trace path
    vec3 radiance = vec3(0), throughput = vec3(1);
    int n_paths = 0;
    bool free_path = true;
    float t, f_p; // t: end of ray segment (i.e. sampled position or out of volume), f_p: last phase function sample for MIS
    while (sample_volume(pos, dir, t, throughput, seed)) {
        // advance ray
        pos = pos + t * dir;

        // sample light source (environment)
        vec3 w_i;
        const vec4 Li_pdf = sample_environment(rng2(seed), w_i);
        if (Li_pdf.w > 0) {
            f_p = phase_henyey_greenstein(dot(-dir, w_i), vol_phase_g);
            const float weight = power_heuristic(Li_pdf.w, f_p);
            const float Tr = transmittance(pos, w_i, seed);
            radiance += throughput * weight * f_p * Tr * Li_pdf.rgb / Li_pdf.w;
        }

        // early out?
        if (++n_paths >= bounces) { free_path = false; break; }
        // russian roulette
        const float rr_val = luma(throughput);
        if (rr_val < .1f) {
            const float prob = 1 - rr_val;
            if (rng(seed) < prob) { free_path = false; break; }
            throughput /= 1 - prob;
        }

        // scatter ray
        const vec3 scatter_dir = sample_phase_henyey_greenstein(dir, vol_phase_g, rng2(seed));
        f_p = phase_henyey_greenstein(dot(-dir, scatter_dir), vol_phase_g);
        dir = scatter_dir;
    }

    // free path? -> add envmap contribution
    if (free_path && n_paths >= show_environment) {
        const vec3 Le = lookup_environment(dir);
        const float weight = n_paths > 0 ? power_heuristic(f_p, pdf_environment(dir)) : 1.f;
        radiance += throughput * weight * Le;
    }

    return radiance;
}

// ---------------------------------------------------
// main

void main() {
	const ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
    const ivec2 size = imageSize(color);
	if (any(greaterThanEqual(pixel, size))) return;

    // setup random seed and camera ray (in model space!)
    uint seed = tea(pixel.y * size.x + pixel.x, current_sample, 8);
    const vec3 pos = cam_pos;
    const vec3 dir = view_dir(pixel, size, rng2(seed));

    // trace ray
    //const float Tr = transmittance(pos, dir, seed);
    //const float Tr_DDA = transmittanceDDA(pos, dir, seed);
    //const vec3 radiance = vec3(Tr_DDA);
    const vec3 radiance = trace_path(pos, dir, seed);

    // write output
    if (any(isnan(radiance)) || any(isinf(radiance))) return;
    imageStore(color, pixel, vec4(mix(imageLoad(color, pixel).rgb, radiance, 1.f / current_sample), 1));
    if (current_sample % 2 == 1)
        imageStore(even, pixel, vec4(mix(imageLoad(even, pixel).rgb, radiance, 1.f / ((current_sample+ 1) / 2)), 1));
}
