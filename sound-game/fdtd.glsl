#[compute]
#version 450

layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer CurrentPressure {float p_current[];};
layout(set = 0, binding = 1, std430) restrict buffer PreviousPressure {float p_previous[];};
layout(set = 0, binding = 2, std430) restrict buffer NextPressure {float p_next[];};
layout(set = 0, binding = 3, std430) restrict buffer Obstacles {uint obstacle[];};
layout(set = 0, binding = 4, std430) restrict buffer PsiX {float psi_x[];};
layout(set = 0, binding = 5, std430) restrict buffer PsiY {float psi_y[];};

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
    float pml_subpass;
    float pml_thickness;
    float pml_sigma_dt;
};

void main() {
    int x = int(gl_GlobalInvocationID.x);
    int y = int(gl_GlobalInvocationID.y);

    if (x >= width || y >= height) return;

    int i = y * width + x;

    if (mode == 0) {
        int subpass = int(pml_subpass + 0.5);
        float thickness_f = max(1.0, pml_thickness);
        int thickness = int(thickness_f + 0.5);
        float sigma_dt = pml_sigma_dt;

        int dist_x = min(x, width - 1 - x);
        int dist_y = min(y, height - 1 - y);
        int dist = min(dist_x, dist_y);
        int WH = width * height;

        if (subpass == 1) {
            float sigma_x_dt = 0.0;
            if (dist_x < thickness) {
                float f = float(thickness - dist_x) / float(max(1, thickness));
                sigma_x_dt = sigma_dt * f * f;
            }
            if (x < width - 1) {
                float dpdx = p_current[i + 1] - p_current[i];
                psi_x[i] = psi_x[i] + sigma_x_dt * dpdx;
            }

            float sigma_y_dt = 0.0;
            if (dist_y < thickness) {
                float f = float(thickness - dist_y) / float(max(1, thickness));
                sigma_y_dt = sigma_dt * f * f;
            }
            if (y < height - 1) {
                float dpdy = p_current[i + width] - p_current[i];
                psi_y[i] = psi_y[i] + sigma_y_dt * dpdy;
            }
            return;
        } else if (subpass == 2) {
            if (obstacle[i] != 0u) {
                p_next[i] = 0.0;
                return;
            }
            if (x < 1 || x >= width - 1 || y < 1 || y >= height - 1) {
                p_next[i] = 0.0;
                return;
            }
            float lap = p_current[i + 1] + p_current[i - 1] + p_current[i + width] + p_current[i - width] - 4.0 * p_current[i];

            float psi_div = 0.0;
            float psi_x_i = psi_x[i];
            float psi_x_im1 = (x > 0) ? psi_x[i - 1] : 0.0;
            psi_div += psi_x_i - psi_x_im1;
            float psi_y_i = psi_y[i];
            float psi_y_imw = (y > 0) ? psi_y[i - width] : 0.0;
            psi_div += psi_y_i - psi_y_imw;

            p_next[i] = (2.0 * p_current[i] - p_previous[i] + r2 * (lap + psi_div)) * damping;
            return;
        } else if (subpass == 3) {
            if (obstacle[i] != 0u) {
                p_next[i] = 0.0;
                return;
            }
            if (dist != 0) {
                return;
            }
            float r = sqrt(r2);
            float alpha = (r - 1.0) / (r + 1.0);

            float sum = 0.0;
            float cnt = 0.0;
            if (x == 0) {
                int ni = i + 1;
                if (ni >= 0 && ni < WH) {
                    sum += p_current[ni] + alpha * (p_next[ni] - p_current[i]);
                    cnt += 1.0;
                }
            }
            if (x == width - 1) {
                int ni = i - 1;
                if (ni >= 0 && ni < WH) {
                    sum += p_current[ni] + alpha * (p_next[ni] - p_current[i]);
                    cnt += 1.0;
                }
            }
            if (y == 0) {
                int ni = i + width;
                if (ni >= 0 && ni < WH) {
                    sum += p_current[ni] + alpha * (p_next[ni] - p_current[i]);
                    cnt += 1.0;
                }
            }
            if (y == height - 1) {
                int ni = i - width;
                if (ni >= 0 && ni < WH) {
                    sum += p_current[ni] + alpha * (p_next[ni] - p_current[i]);
                    cnt += 1.0;
                }
            }

            if (cnt > 0.0) {
                p_next[i] = sum / cnt;
            } else {
                p_next[i] = 0.0;
            }
            return;
        }
    } else if (mode == 1) {
        float dx = float(x - imp_x);
        float dy = float(y - imp_y);
        float dist_sq = dx * dx + dy * dy;
        float cutoff = 4.0 * imp_sigma;
        if (dist_sq <= cutoff * cutoff) {
            p_current[i] += imp_amp * exp(-dist_sq / (2.0 * imp_sigma * imp_sigma));
        }
    }
}
