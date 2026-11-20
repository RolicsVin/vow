## Общие данные проекта
extends Node

## Параметры шейдера пост-обработки
var post_processing_parameters: Dictionary = {
	'brightness': 0.0,
	'contrast': 1.0,
	'saturation': 1.0,
	'noise_intensity': 0.01200000057,
	'blur_strength': 0.0
}


## Возвращает сохранённые данные синглтона
func get_save() -> Dictionary:
	_print_log()
	print('Собирается сохранение...')

	var save: Dictionary = {
		'post_processing_parameters': post_processing_parameters.duplicate(true)
	}

	_print_save(save)
	_end_log()
	return save


## Загружает данные синглтона из сохранения
func load_save(save: Dictionary) -> void:
	_print_log()
	print('Загрузка данных...')

	var parameters: Variant = save.get('post_processing_parameters', {})
	if parameters is Dictionary:
		# Обновляем только известные параметры и сохраняем значения по умолчанию
		for parameter_name: String in post_processing_parameters:
			var value: Variant = parameters.get(parameter_name)
			if value is int or value is float:
				post_processing_parameters[parameter_name] = float(value)
			elif parameters.has(parameter_name):
				push_warning(
					'[Data] Параметр «%s» должен иметь числовое значение' % parameter_name
				)
	else:
		push_warning('[Data] post_processing_parameters должен быть Dictionary')

	print('Данные загружены:')
	_print_save(save)
	_end_log()


## Выводит заголовок лога синглтона
func _print_log() -> void:
	print('Печатает синглтон Data. (data.gd)--------------------------------------------------------')


## Завершает блок лога синглтона
func _end_log() -> void:
	print('------------------------------------------------------------------------------------------')
	print()


## Выводит словарь через PythonBridge
func _print_save(save: Dictionary) -> void:
	var response: Dictionary = PythonBridge.call_function('stdout', 'pretty_print', [save])
	if response.get('ok', false):
		print(response.get('result', ''))
	else:
		push_error(
			'[Data] Не удалось вывести данные через PythonBridge: %s'
			% response.get('error', 'unknown error')
		)
