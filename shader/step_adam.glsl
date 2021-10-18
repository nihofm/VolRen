#version 450 core

#extension GL_NV_shader_atomic_float : enable

layout (local_size_x = 8, local_size_y = 8, local_size_z = 8) in;

#include "common.glsl"

uniform float learning_rate;
uniform int reset;
uniform int solve;

const float b1 = 0.9;
const float b2 = 0.999;
const float eps = 1e-8;

// ---------------------------------------------------
// main

void main() {
	const ivec3 gid = ivec3(gl_GlobalInvocationID.xyz);
    if (any(greaterThanEqual(gid, vol_size))) return;
    const uint idx = gid.z * vol_size.x * vol_size.y + gid.y * vol_size.x + gid.x;

    // debug: reset experiment?
    if (reset > 0) {
        parameters[idx] = vec4(0.1, 0.0, 0.0, 1.0);
        return;
    }

    // debug: solve experiment?
    if (solve > 0) {
        parameters[idx] = vec4(lookup_voxel_brick(gid), 0.0, 0.0, 1.0);
        return;
    }

    // load parameters
    const vec4 x_dx_m1_m2 = parameters[idx];

    // update moments
    const float dx = clamp(x_dx_m1_m2.y, -1, 1);
    const float m1 = b1 * x_dx_m1_m2.z + (1.f - b1) * dx;
    const float m2 = b2 * x_dx_m1_m2.w + (1.f - b2) * dx * dx;
    // bias correction
    const float m1_c = m1 / (1.f - b1);
    const float m2_c = m2 / (1.f - b2);
    // update parameter
    const float x = x_dx_m1_m2.x;
    const float y = clamp(x - learning_rate * m1_c / (sqrt(m2_c) + eps), eps, vol_majorant - eps);

    // store updated parameters and zero gradients
    parameters[idx] = vec4(y, 0.f, m1, m2);
}
