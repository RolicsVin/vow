shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.8; // Порог яркости (отсекает темные участки)
uniform float intensity : hint_range(0.0, 10.0) = 2.0; // Сила и яркость самого блика
uniform float streak_length : hint_range(0.0, 1.0) = 0.2; // Длина блика (в UV-координатах)
uniform float angle : hint_range(0.0, 360.0) = 0.0; // Направление блика в градусах (0 - горизонтально)
uniform int samples : hint_range(5, 500) = 20; // Качество размытия (количество сэмплов в одну сторону)
uniform float alpha: hint_range(-1.0, 0.0) = 0.0;
uniform bool use_alpha_corrector = false;

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    
    // Переводим угол в радианы и получаем 2D-вектор направления
    float rad = radians(angle);
    vec2 dir = vec2(cos(rad), sin(rad));
    
    vec4 streak_color = vec4(0.0);
    float total_weight = 0.0;
    
    // Проходимся вдоль линии в обе стороны (от -samples до +samples)
    for (int i = -samples; i <= samples; i++) {
        // t меняется от -1.0 до 1.0
        float t = float(i) / float(samples); 
        // Затухание блика к его краям (линейная интерполяция)
        float weight = 1.0 - abs(t); 
        
        vec2 offset = dir * t * streak_length;
        vec4 sample_color = texture(TEXTURE, UV + offset);
        
        // Вычисляем общую яркость пикселя по максимальному цветовому каналу
        float brightness = max(max(sample_color.r, sample_color.g), sample_color.b);
        
        // Если пиксель ярче порога, берем его в расчет блика
        if (brightness > threshold) {
            // Плавное выделение свечения: чем ярче пиксель, тем сильнее он влияет
            float contribution = (brightness - threshold) / (1.0 - threshold);
            streak_color += sample_color * contribution * weight;
        }
        total_weight += weight;
    }
    
    if (total_weight > 0.0) {
        streak_color /= total_weight;
    }
    
    // Складываем оригинальный цвет и блик (Additive blending)
    vec3 final_rgb = tex_color.rgb + (streak_color.rgb * intensity);
    // Делаем так, чтобы блики были видны даже на прозрачных участках текстуры
    float final_alpha = max(tex_color.a, streak_color.a * intensity);
    
    if (use_alpha_corrector) {
        COLOR = vec4(final_rgb, (clamp(final_alpha, 0.0, 1.0)) + alpha);
	} else {
		COLOR = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
	}
}