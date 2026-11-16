## Оверлей дождя на базе ColorRect. 
## Управляет параметрами шейдера rain.gdshader 
## и умеет плавно менять силу дождя. 
class_name RainOverlay extends ColorRect

@export_range(0.0, 1.0, 0.01) var rain_intensity: float = 0.5: ## Общая сила дождя от 0 до 1
	set(value):
		rain_intensity = clampf(value, 0.0, 1.0)
		_apply_intensity()

var _intensity_tween: Tween ## Текущая анимация смены силы дождя


func _ready() -> void: ## Применяет начальную силу дождя
	_apply_intensity()


## Плавно меняет силу дождя до target_intensity за duration секунд
func fade_to_intensity(target_intensity: float, duration: float = 2.0) -> void:
	if _intensity_tween != null and _intensity_tween.is_valid():
		_intensity_tween.kill() # Останавливаем предыдущую анимацию
	var clamped_target: float = clampf(target_intensity, 0.0, 1.0) ## Допустимая целевая сила
	_intensity_tween = create_tween()
	_intensity_tween.tween_property(self, 'rain_intensity', clamped_target, duration)


## Переносит силу дождя в параметры шейдера
func _apply_intensity() -> void:
	var shader_material: ShaderMaterial = material as ShaderMaterial ## Материал с шейдером дождя
	if shader_material == null: # Материал ещё не назначен
		return
	shader_material.set_shader_parameter('density', lerpf(0.05, 0.9, rain_intensity))
	shader_material.set_shader_parameter('fall_speed', lerpf(900.0, 1800.0, rain_intensity))
	shader_material.set_shader_parameter('drop_length', lerpf(0.25, 0.5, rain_intensity))
	shader_material.set_shader_parameter('overlay_amount', rain_intensity)
	shader_material.set_shader_parameter('fog_amount', lerpf(0.0, 0.6, rain_intensity))
