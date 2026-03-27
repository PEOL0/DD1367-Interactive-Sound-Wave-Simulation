#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer CurrentPressure {float p_current[];};
layout(set = 0, binding = 1, std430) restrict buffer PreviousPressure {float p_previous[];};
layout(set = 0, binding = 2, std430) restrict buffer NextPressure {float p_next[];};
layout(set = 0, binding = 3, std430) restrict buffer Obstacles {uint obstacle[];};

layout(push_constant, std430) uniform Params {
    int width;
    int height;
    float r2;
    float damping;
    int mode;
    int imp_x;
    int imp_y;
    float imp_amp;
    float imp_sigma;
    float _pad0;
    float _pad1;
    float _pad2;
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    if (x >= width || y >= height) return;

    int i = y * width + x;

    if (mode == 0) {
        if (obstacle[i] != 0u) {
            p_next[i] = 0.0;
            return;
        }
        if (x < 1 || x >= width - 1 || y < 1 || y >= height - 1) {
            p_next[i] = 0.0;
            return;
        }
        float lap = p_current[i + 1] + p_current[i - 1] + p_current[i + width] + p_current[i - width] - 4.0 * p_current[i];
        p_next[i] = (2.0 * p_current[i] - p_previous[i] + r2 * lap) * damping;
    } else {
        float dx = float(x - imp_x);
        float dy = float(y - imp_y);
        float dist_sq = dx * dx + dy * dy;
        float cutoff = 4.0 * imp_sigma;
        if (dist_sq <= cutoff * cutoff) {
            p_current[i] += imp_amp * exp(-dist_sq / (2.0 * imp_sigma * imp_sigma));
        }
    }
}
