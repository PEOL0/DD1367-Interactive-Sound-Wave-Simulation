shader_type canvas_item;

uniform sampler2D pressure_field : filter_linear;
uniform float gain = 5.0;

// Samples the FDTD pressure field and maps it to colour.
// Positive pressure is rendered as warm (red/orange), negative
// pressure as cool (blue), and zero pressure as black.
void fragment() {
    float p = texture(pressure_field, UV).r;
    float scaled = p * gain;

    vec3 pos_color = vec3(1.0, 0.3, 0.0);
    vec3 neg_color = vec3(0.0, 0.3, 1.0);

    float intensity = clamp(abs(scaled), 0.0, 1.0);
    vec3 color = (scaled >= 0.0) ? pos_color * intensity : neg_color * intensity;

    COLOR = vec4(color, intensity);
}