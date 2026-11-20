## Управляет экранным шейдером пост-обработки и синхронизирует его параметры с Data
extends ColorRect

## Список параметров, поддерживаемых шейдером пост-обработки
const PARAMETER_NAMES: Array[String] = [
	'brightness',
	'contrast',
	'saturation',
	'noise_intensity',
	'blur_strength'
]

## Материал экранного шейдера
@onready var _shader_material: ShaderMaterial = material as ShaderMaterial


## Загружает параметры из Data после создания узла
func _ready() -> void:
	show()
	update_parameters(Data.post_processing_parameters)


## Обновляет параметры шейдера и сохраняет их в Data
func update_parameters(parameters: Dictionary) -> void:
	for parameter_name: String in PARAMETER_NAMES:
		if not parameters.has(parameter_name):
			continue

		var parameter_value: Variant = parameters[parameter_name]
		if not parameter_value is int and not parameter_value is float:
			push_warning(
				'[PostProcessing] Параметр «%s» должен иметь числовое значение' % parameter_name
			)
			continue

		# Сначала сохраняем значение, чтобы Data оставался источником истины
		var value: float = float(parameter_value)
		Data.post_processing_parameters[parameter_name] = value

		if _shader_material == null:
			push_warning('[PostProcessing] Материал ShaderMaterial не назначен')
			continue

		_shader_material.set_shader_parameter(StringName(parameter_name), value)
