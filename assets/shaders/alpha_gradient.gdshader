shader_type canvas_item;

uniform int direction = 0;
// 0 = X →
// 1 = X ←
// 2 = Y ↓
// 3 = Y ↑

uniform float gradient_start : hint_range(0.0, 1.0) = 0.0;
uniform float gradient_end : hint_range(0.0, 1.0) = 1.0;

void fragment() {
    vec4 color = COLOR;

    float value;

    if (direction == 0)
        value = UV.x;
    else if (direction == 1)
        value = 1.0 - UV.x;
    else if (direction == 2)
        value = UV.y;
    else
        value = 1.0 - UV.y;

    float gradient = smoothstep(gradient_start, gradient_end, value);

    color.a *= gradient;

    COLOR = color;
}