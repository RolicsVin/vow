## Имитирует этапы загрузки, плавно заполняет HSlider и обновляет необязательный Label
## 
class_name FakeLoading extends Node

## Вызывается один раз после завершения загрузки
signal loading_finished

## Ползунок, отображающий прогресс загрузки
@export var progress_slider: HSlider

## Необязательная подпись текущего этапа загрузки
@export var status_label: Label

## Продолжительность имитации загрузки в секундах
@export_range(0.1, 120.0, 0.1, 'or_greater') var loading_duration: float = 8.0

## Тексты этапов, которые будут последовательно отображаться во время загрузки
@export var loading_texts: Array[String] = [
	'Подготовка ресурсов...',
	'Загрузка игровых данных...',
	'Компиляция шейдеров...',
	'Инициализация текстур...',
	'Подготовка окружения...',
	'Почти готово...'
]

## Текст, отображаемый после завершения загрузки
@export var completion_text: String = 'Загрузка завершена'

## Прошедшее время с момента начала имитации
var _elapsed_time: float = 0.0

## Индекс последнего отображённого этапа
var _current_text_index: int = -1

## Флаг активности загрузки
var _is_loading: bool = false


## Запускает имитацию загрузки с нулевого прогресса
func start_loading() -> void:
	_elapsed_time = 0.0
	_current_text_index = -1
	_is_loading = true

	if progress_slider != null and is_instance_valid(progress_slider):
		progress_slider.value = progress_slider.min_value

	_update_status_text(0)

	if loading_duration <= 0.0:
		finish_loading()


## Принудительно завершает загрузку и отправляет сигнал loading_finished
func finish_loading() -> void:
	if not _is_loading:
		return

	_is_loading = false

	if progress_slider != null and is_instance_valid(progress_slider):
		progress_slider.value = progress_slider.max_value

	if status_label != null and is_instance_valid(status_label):
		status_label.text = completion_text

	loading_finished.emit()


## Обновляет прогресс и этап загрузки
func _process(delta: float) -> void:
	if not _is_loading:
		return

	_elapsed_time += delta
	var progress_ratio: float = clampf(_elapsed_time / loading_duration, 0.0, 1.0)

	# Используем нелинейную кривую, чтобы прогресс не выглядел равномерным
	var eased_progress: float = 0.82 * pow(progress_ratio, 0.72) + 0.18 * pow(progress_ratio, 2.4)
	eased_progress = clampf(eased_progress, 0.0, 1.0)

	if progress_slider != null and is_instance_valid(progress_slider):
		var target_value: float = lerpf(
			progress_slider.min_value,
			progress_slider.max_value,
			eased_progress
		)

		# Не допускаем обратного движения ползунка
		progress_slider.value = maxf(progress_slider.value, target_value)

	_update_status_text(progress_ratio)

	if progress_ratio >= 1.0:
		finish_loading()


## Меняет подпись в соответствии с текущим этапом загрузки
func _update_status_text(progress_ratio: float) -> void:
	if loading_texts.is_empty():
		return

	var text_index: int = mini(
		int(progress_ratio * loading_texts.size()),
		loading_texts.size() - 1
	)

	if text_index == _current_text_index:
		return

	_current_text_index = text_index

	if status_label != null and is_instance_valid(status_label):
		status_label.text = loading_texts[text_index]
