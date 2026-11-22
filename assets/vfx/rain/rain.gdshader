// Настраиваемый 2D шейдер дождя для Godot 4
// Повесьте на ColorRect (или другой CanvasItem), перекрывающий нужную область
// Поддерживает анимацию направления дождя (порывы ветра), которую можно отключить
shader_type canvas_item;
render_mode blend_mix, unshaded;

const int MAX_LAYERS = 8; // Максимальное число слоёв дождя
const int MAX_TAP_RADIUS = 4; // Максимум соседних колонок, проверяемых для наклонённых капель

group_uniforms rain_look;
uniform vec4 rain_color : source_color = vec4(0.75, 0.82, 1.0, 0.7); // Цвет капель (альфа - макс. непрозрачность)
uniform float intensity : hint_range(0.0, 2.0) = 1.0; // Общая яркость дождя
uniform float density : hint_range(0.0, 1.0) = 0.6; // Шанс появления капли в колонке
uniform int layers : hint_range(1, 8) = 4; // Число слоёв (глубина и параллакс)
uniform float drop_length : hint_range(0.05, 0.95) = 0.4; // Длина капли в долях периода
uniform float drop_thickness : hint_range(0.5, 6.0) = 1.5; // Толщина капли в пикселях
uniform float tail_falloff : hint_range(0.5, 4.0) = 1.6; // Резкость затухания хвоста
uniform float brightness_variation : hint_range(0.0, 1.0) = 0.5; // Разброс яркости между каплями
group_uniforms;

group_uniforms rain_motion;
uniform float fall_speed : hint_range(0.0, 4000.0) = 1400.0; // Скорость падения в пикселях в секунду
uniform float speed_variation : hint_range(0.0, 1.0) = 0.25; // Разброс скорости между колонками
uniform float angle_degrees : hint_range(-60.0, 60.0) = 12.0; // Базовый наклон дождя (ветер), в градусах
group_uniforms;

group_uniforms rain_wind_animation;
uniform bool animate_direction = true; // Включает анимацию направления дождя
uniform float sway_amplitude : hint_range(0.0, 45.0) = 15.0; // Максимальное отклонение от базового угла, в градусах
uniform float sway_speed : hint_range(0.0, 3.0) = 0.3; // Скорость качания в циклах в секунду
uniform float sway_irregularity : hint_range(0.0, 1.0) = 0.5; // 0 - ровное качание, 1 - рваные порывы
uniform float sway_layer_lag : hint_range(0.0, 3.0) = 0.5; // Запаздывание дальних слоёв в секундах
group_uniforms;

group_uniforms rain_layout;
uniform float column_spacing : hint_range(4.0, 80.0) = 22.0; // Ширина колонки в пикселях
uniform float vertical_period : hint_range(40.0, 600.0) = 220.0; // Вертикальный шаг повтора в пикселях
uniform float far_scale : hint_range(0.2, 1.0) = 0.45; // Масштаб самого дальнего слоя
uniform float far_opacity : hint_range(0.0, 1.0) = 0.45; // Прозрачность самого дальнего слоя
uniform float random_seed : hint_range(0.0, 100.0) = 0.0; // Зерно случайности
group_uniforms;

group_uniforms atmosphere;
uniform vec4 overlay_color : source_color = vec4(0.05, 0.08, 0.14, 0.2); // Затемнение всей области
uniform float overlay_amount : hint_range(0.0, 1.0) = 1.0; // Сила затемнения
uniform vec4 fog_color : source_color = vec4(0.7, 0.78, 0.9, 0.25); // Цвет тумана (альфа - макс. плотность)
uniform float fog_amount : hint_range(0.0, 1.0) = 0.3; // Количество тумана
uniform float fog_scale : hint_range(50.0, 1000.0) = 300.0; // Размер клубов тумана в пикселях
uniform float fog_speed : hint_range(0.0, 200.0) = 15.0; // Скорость дрейфа тумана
group_uniforms;

varying vec2 local_position; // Локальная позиция фрагмента в пикселях узла

void vertex() {
	local_position = VERTEX;
}

// Дешёвый хеш двух чисел в диапазон 0..1
float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Value noise для тумана
float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	vec2 smooth_local = local * local * (3.0 - 2.0 * local);
	return mix(mix(a, b, smooth_local.x), mix(c, d, smooth_local.x), smooth_local.y);
}

// Наложение top поверх bottom с учётом альфы
vec4 blend_over(vec4 top, vec4 bottom) {
	float out_alpha = top.a + bottom.a * (1.0 - top.a);
	vec3 out_rgb = (top.rgb * top.a + bottom.rgb * bottom.a * (1.0 - top.a)) / max(out_alpha, 0.0001);
	return vec4(out_rgb, out_alpha);
}

// Веса трёх гармоник ветра (в сумме дают 1, поэтому волна не выходит за -1..1)
vec3 sway_weights() {
	return vec3(1.0 - 0.45 * sway_irregularity, 0.3 * sway_irregularity, 0.15 * sway_irregularity);
}

// Мгновенная форма ветра в диапазоне -1..1 (смесь трёх несоизмеримых гармоник)
float sway_wave(float time_value) {
	float omega = TAU * max(sway_speed, 0.001);
	vec3 weights = sway_weights();
	return weights.x * sin(omega * time_value)
			+ weights.y * sin(omega * 1.618 * time_value + 1.3)
			+ weights.z * sin(omega * 2.718 * time_value + 2.1);
}

// Интеграл sway_wave по времени от 0 - это боковой снос капель, согласованный с их наклоном
float sway_wave_integral(float time_value) {
	float omega = TAU * max(sway_speed, 0.001);
	vec3 weights = sway_weights();
	return weights.x * (1.0 - cos(omega * time_value)) / omega
			+ weights.y * (cos(1.3) - cos(omega * 1.618 * time_value + 1.3)) / (omega * 1.618)
			+ weights.z * (cos(2.1) - cos(omega * 2.718 * time_value + 2.1)) / (omega * 2.718);
}

// Прозрачность одного слоя дождя в точке (side_pos - поперёк, fall_pos - вдоль падения)
float rain_layer(float side_pos, float fall_pos, int index, float depth) {
	// Дальние слои мельче, тоньше и слабее
	float layer_scale = mix(1.0, far_scale, depth);
	float layer_opacity = mix(1.0, far_opacity, depth);
	float layer_seed = float(index) * 13.37 + random_seed;

	float cell_width = max(column_spacing, drop_thickness * 2.0) * layer_scale;
	float period = vertical_period * layer_scale;
	float half_width = drop_thickness * layer_scale * 0.5;

	// Анимация направления: наклон капель (slope) и согласованный с ним боковой снос (drift)
	float slope = 0.0;
	float drift = 0.0;
	if (animate_direction) {
		float wave_time = TIME - depth * sway_layer_lag;
		float max_slope = tan(radians(sway_amplitude));
		slope = max_slope * sway_wave(wave_time);
		drift = fall_speed * layer_scale * max_slope * sway_wave_integral(wave_time);
	}

	// Определяем колонку пикселя с учётом сноса
	float shifted_side = side_pos - drift;
	float pixel_column = floor(shifted_side / cell_width);

	// Наклонённая капля может заходить в соседние колонки, поэтому проверяем и их
	int tap_radius = min(int(ceil(abs(slope) * drop_length * period / cell_width)), MAX_TAP_RADIUS);
	float slope_normalizer = inversesqrt(1.0 + slope * slope);

	float layer_alpha = 0.0;
	for (int offset = -MAX_TAP_RADIUS; offset <= MAX_TAP_RADIUS; offset++) {
		if (offset > tap_radius || offset < -tap_radius) {
			continue;
		}
		float column = pixel_column + float(offset);

		// Случайная фаза и скорость конкретной колонки
		float column_phase = hash21(vec2(column, layer_seed));
		float speed_factor = 1.0 + (hash21(vec2(column, layer_seed + 5.1)) * 2.0 - 1.0) * speed_variation;

		// Координата вдоль падения со сдвигом по времени
		float w = (fall_pos - fall_speed * layer_scale * speed_factor * TIME) / period + column_phase;
		float period_index = mod(floor(w), 1024.0);
		float y_fraction = fract(w);

		// Случайные величины конкретной капли
		vec2 drop_id = vec2(column + period_index * 31.7, layer_seed);
		float random_exists = hash21(drop_id + 11.0);
		float random_head = hash21(drop_id + 23.0);
		float random_x = hash21(drop_id + 37.0);
		float random_brightness = hash21(drop_id + 47.0);

		float exists = step(random_exists, density);

		// Продольный профиль: яркая голова и затухающий хвост
		float head = mix(drop_length, 1.0, random_head);
		float tail = (y_fraction - (head - drop_length)) / drop_length;
		float vertical = pow(clamp(tail, 0.0, 1.0), tail_falloff) * (1.0 - smoothstep(0.9, 1.0, tail));

		// Поперечный профиль: линия проходит через голову и наклонена на slope
		float margin = half_width / cell_width;
		float center_x = mix(margin, 1.0 - margin, random_x);
		float line_position = (column + center_x) * cell_width + slope * (y_fraction - head) * period;
		float distance_px = abs(shifted_side - line_position) * slope_normalizer;
		float horizontal = clamp(half_width - distance_px + 0.5, 0.0, 1.0);

		float brightness = 1.0 - brightness_variation * random_brightness;
		float drop_alpha = exists * horizontal * vertical * brightness;
		layer_alpha = 1.0 - (1.0 - layer_alpha) * (1.0 - drop_alpha);
	}
	return layer_alpha * layer_opacity;
}

void fragment() {
	// Раскладываем позицию на поперечную и продольную оси с учётом базового наклона
	float angle = radians(angle_degrees);
	vec2 fall_direction = vec2(sin(angle), cos(angle));
	vec2 side_direction = vec2(cos(angle), -sin(angle));
	float side_pos = dot(local_position, side_direction);
	float fall_pos = dot(local_position, fall_direction);

	// Складываем все слои дождя
	float rain_alpha = 0.0;
	for (int i = 0; i < MAX_LAYERS; i++) {
		if (i >= layers) {
			break;
		}
		float depth = layers > 1 ? float(i) / float(layers - 1) : 0.0;
		float layer_alpha = rain_layer(side_pos, fall_pos, i, depth);
		rain_alpha = 1.0 - (1.0 - rain_alpha) * (1.0 - layer_alpha);
	}
	rain_alpha = clamp(rain_alpha * intensity, 0.0, 1.0) * rain_color.a;

	// Туман из двух октав шума
	vec2 fog_position = (local_position + vec2(TIME, TIME * 0.35) * fog_speed) / fog_scale;
	float fog_noise = value_noise(fog_position) * 0.65 + value_noise(fog_position * 2.3 + 7.0) * 0.35;
	float fog_alpha = smoothstep(0.25, 0.85, fog_noise) * fog_amount * fog_color.a;

	// Собираем итог: дождь поверх тумана поверх затемнения
	vec4 rain = vec4(rain_color.rgb, rain_alpha);
	vec4 fog = vec4(fog_color.rgb, fog_alpha);
	vec4 overlay = vec4(overlay_color.rgb, overlay_color.a * overlay_amount);
	vec4 result = blend_over(rain, blend_over(fog, overlay));

	// Учитываем альфу узла (например, из modulate)
	result.a *= COLOR.a;
	COLOR = result;
}