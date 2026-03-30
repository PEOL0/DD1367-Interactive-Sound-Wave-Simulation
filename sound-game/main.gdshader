shader_type canvas_item;

uniform sampler2D pressure_field : filter_linear;
uniform float gain = 15.0;

uniform vec3 pos_color = vec3(1.0, 0.6, 0.0);
uniform vec3 neg_color = vec3(0.0, 0.7, 1.0);
uniform float use_db = 0.0;
uniform float min_db = -80.0;

// Samples the FDTD pressure field and maps it to colour.
// Two modes are supported: linear (default) and decibel (dB).
// Positive pressure is rendered as warm (orange), negative
// pressure as cool (blu), and zero pressure as black.
void fragment() {
    float p = texture(pressure_field, UV).r;
    float mag = abs(p) * gain;

    float intensity;
    if (use_db < 0.5) {
        intensity = clamp(mag, 0.0, 1.0);
    } else {
        float dB = 20.0 * log(mag) / log(10.0);
        float norm_db = (dB - min_db) / (-min_db);
        intensity = clamp(norm_db, 0.0, 1.0);
    }

    vec3 color = (p >= 0.0) ? pos_color * intensity : neg_color * intensity;
    COLOR = vec4(color, intensity);
}