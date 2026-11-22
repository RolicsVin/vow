shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float saturation : hint_range(0.0, 2.0) = 1.0;

uniform float noise_intensity : hint_range(0.0, 1.0) = 0.05;

// Размытие
uniform float blur_strength : hint_range(0.0, 10.0) = 0.0;


// Хеш без sin(): не деградирует на больших значениях аргумента
float random(vec2 seed) {
    vec3 p3 = fract(vec3(seed.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
    vec2 uv = SCREEN_UV;

    // Размер одного пикселя экрана
    vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));

    // -------------------------
    // Blur
    // -------------------------
    vec4 color = texture(screen_texture, uv);

    if (blur_strength > 0.0) {
        float b = blur_strength;

        color += texture(screen_texture, uv + vec2( pixel_size.x * b, 0.0));
        color += texture(screen_texture, uv + vec2(-pixel_size.x * b, 0.0));

        color += texture(screen_texture, uv + vec2(0.0,  pixel_size.y * b));
        color += texture(screen_texture, uv + vec2(0.0, -pixel_size.y * b));

        color += texture(screen_texture, uv + vec2( pixel_size.x * b,  pixel_size.y * b));
        color += texture(screen_texture, uv + vec2(-pixel_size.x * b,  pixel_size.y * b));
        color += texture(screen_texture, uv + vec2( pixel_size.x * b, -pixel_size.y * b));
        color += texture(screen_texture, uv + vec2(-pixel_size.x * b, -pixel_size.y * b));

        color /= 9.0;
    }

    // -------------------------
    // Noise
    // -------------------------
    // Координаты в пикселях экрана и ограниченное время, чтобы значения не росли бесконечно
    float time_offset = mod(TIME, 10.0);
    vec2 noise_seed = floor(FRAGCOORD.xy) + time_offset * vec2(113.0, 71.0);
    float noise = random(noise_seed) * 2.0 - 1.0;

    color.rgb += noise * noise_intensity;

    // -------------------------
    // Brightness
    // -------------------------
    color.rgb += brightness;

    // -------------------------
    // Contrast
    // -------------------------
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    // -------------------------
    // Saturation
    // -------------------------
    float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
    color.rgb = mix(vec3(gray), color.rgb, saturation);

    COLOR = color;
}
