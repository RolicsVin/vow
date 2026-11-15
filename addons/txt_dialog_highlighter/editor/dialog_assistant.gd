@tool
## Интеллектуальные подсказки и диагностика TXTLinearDialog в Script Editor 
class_name TXTLinearDialogAssistant extends RefCounted


## Свойства реплики и их описания
const REPLICA_PROPERTIES: Dictionary = {
	'speaker': 'Персонаж из Character.CharacterType',
	'name': 'Пользовательское имя над репликой',
	'emotion': 'Эмоция из Replica.Emotion',
	'background': 'Имя или путь фона реплики',
	'sound': 'Звук, который будет воспроизведён с репликой',
	'color': 'Цвет имени персонажа: название или #RRGGBB',
	'chat_color': 'Цвет текста реплики: название или #RRGGBB',
	'character_emotion': 'Название эмоции визуального персонажа',
	'interpolation': 'Режим интерполяции: parent, instantaneous или linear',
	'reset_text_buffer': 'Сбрасывать буфер текста: true или false',
	'small_text': 'Использовать уменьшенный размер текста: true или false',
	'language': 'Язык основного текста: Ru или En',
	'id': 'Пользовательский уникальный идентификатор реплики',
}

## Свойства диалога и их описания
const DIALOG_PROPERTIES: Dictionary = {
	'name': 'Имя диалога',
	'next': 'Имя следующего диалога',
	'mini_game': 'Имя мини-игры, запускаемой после диалога',
	'start': 'Тип появления диалога: instantaneous или linear',
	'end': 'Тип завершения диалога: instantaneous или linear',
	'interpolation': 'Интерполяция реплик по умолчанию: parent, instantaneous или linear',
}

## Описания директив и ключевых слов
const SYNTAX_HINTS: Dictionary = {
	'dialog': 'Настройка диалога: dialog;<свойство> <значение>',
	'lang': 'Перевод реплики: lang;<Ru|En> <текст перевода>',
	'action': 'Действие: action;<start|end>;<visible|sound|music> <путь> [off] [slow]',
}

## Допустимые значения перечислений
const ENUM_VALUES: Dictionary = {
	'interpolation': ['parent', 'instantaneous', 'linear'],
	'start': ['instantaneous', 'linear'],
	'end': ['instantaneous', 'linear'],
	'language': ['Ru', 'En'],
	'lang': ['Ru', 'En'],
	'when': ['start', 'end'],
	'action_type': ['visible', 'sound', 'music'],
	'boolean': ['true', 'false'],
	'small_text': ['true', 'false'],
	'reset_text_buffer': ['true', 'false'],
	'action_flag': ['on', 'off', 'fast', 'slow'],
	'speaker': [
		'Нет', 'Подросток', 'Асмунд', 'Сосед', 'ДругойСосед', 'Отец', 'Девушка',
		'Мать', 'ЖительДеревни', 'ЖительницаДеревни', 'Старейшина',
		'КастомныйПерсонаж',
	],
	'emotion': [
		'Без_эмоции', 'В_мыслях', 'Радостно', 'Счастливо', 'Смеясь', 'Веселясь',
		'Хихикая', 'Грустно', 'Печально', 'Огорчённо', 'Недовольно', 'Шокированно',
		'Удивлённо', 'Пугливо', 'Испуганно', 'Боясь', 'Истеря', 'Плача', 'Злясь',
		'Злостно', 'Яростно', 'Безумно', 'Неистово', 'Подозрительно',
		'Раздосадованно', 'Задумчиво', 'Насмешливо', 'Издеваясь', 'Не_доверчиво',
		'Прищурившись', 'Присмотревшись', 'Страсно', 'Возбуждённо', 'Влюблённо',
		'Стыдливо', 'Смущённо',
	],
}

## Цвет фона строки с ошибкой
const ERROR_LINE_COLOR: Color = Color(0.65, 0.12, 0.12, 0.22)

## Подсветчик синтаксиса для извлечения контекста
const HIGHLIGHTER_META: StringName = 'txt_linear_dialog_assistant'


## Подключить подсказки к CodeEdit
func setup(code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return

	code_edit.code_completion_enabled = true
	code_edit.code_completion_requested.connect(
		_on_code_completion_requested.bind(code_edit)
	)
	code_edit.text_changed.connect(_on_text_changed.bind(code_edit))
	code_edit.caret_changed.connect(_on_caret_changed.bind(code_edit))
	code_edit.symbol_hovered.connect(_on_symbol_hovered.bind(code_edit))
	code_edit.symbol_tooltip_on_hover = true

	_refresh_diagnostics(code_edit)
	_update_hint(code_edit)


## Обработать запрос автодополнения от редактора
func _on_code_completion_requested(code_edit: CodeEdit) -> void:
	_fill_completion_options(code_edit, true)


## Обновить автодополнение после изменения текста
func _on_text_changed(code_edit: CodeEdit) -> void:
	_refresh_diagnostics(code_edit)

	if _can_show_automatic_completion(code_edit):
		code_edit.request_code_completion(true)

	_update_hint(code_edit)


## Обновить подсказку при перемещении курсора
func _on_caret_changed(code_edit: CodeEdit) -> void:
	_update_hint(code_edit)


## Обновить всплывающую подсказку при наведении на символ
func _on_symbol_hovered(symbol: String, line: int, column: int, code_edit: CodeEdit) -> void:
	var issues: Dictionary = code_edit.get_meta('txt_dialog_issues', {})
	if issues.has(line):
		code_edit.tooltip_text = issues[line]
		return

	var description: String = _get_description(symbol)
	if description.is_empty():
		return

	code_edit.tooltip_text = description


## Проверить, разрешено ли автоматическое автодополнение в текущей позиции
func _can_show_automatic_completion(code_edit: CodeEdit) -> bool:
	var line: int = code_edit.get_caret_line()
	var column: int = code_edit.get_caret_column()
	var line_text: String = code_edit.get_line(line).substr(0, column).strip_edges()

	if line_text.is_empty() or line_text.begins_with('//'):
		return false

	if _is_first_replica_line(code_edit, line):
		return false

	return true


## Заполнить список автодополнения с учётом текущего контекста
func _fill_completion_options(code_edit: CodeEdit, manual: bool) -> void:
	var line_index: int = code_edit.get_caret_line()
	var column: int = code_edit.get_caret_column()
	var line_text: String = code_edit.get_line(line_index).substr(0, column).strip_edges()

	if line_text.begins_with('//'):
		return

	var options: Array[String] = _get_completion_values(code_edit, line_index, line_text, manual)
	if options.is_empty():
		return

	code_edit.add_code_completion_option(
		CodeEdit.KIND_PLAIN_TEXT,
		options[0],
		options[0]
	)

	for index in range(1, options.size()):
		code_edit.add_code_completion_option(
			CodeEdit.KIND_PLAIN_TEXT,
			options[index],
			options[index]
		)

	code_edit.update_code_completion_options(true)


## Получить варианты автодополнения для текущего контекста
func _get_completion_values(
	code_edit: CodeEdit,
	line_index: int,
	line_text: String,
	manual: bool
) -> Array[String]:
	if line_text.begins_with('dialog;'):
		var dialog_parts: PackedStringArray = line_text.split(';')
		if dialog_parts.size() == 1:
			return _dictionary_keys(DIALOG_PROPERTIES)
		if dialog_parts.size() == 2 and not dialog_parts[1].contains(' '):
			return _matching_values(_dictionary_keys(DIALOG_PROPERTIES), dialog_parts[1])
		return _get_value_options(dialog_parts[1].split(' ')[0], line_text)

	if line_text.begins_with('action;') or line_text == 'action':
		var action_parts: PackedStringArray = line_text.split(';')
		if action_parts.size() == 1:
			return ['start', 'end']
		if action_parts.size() == 2:
			return _matching_values(ENUM_VALUES['when'], action_parts[1])
		if action_parts.size() == 3:
			return _matching_values(ENUM_VALUES['action_type'], action_parts[2])
		if line_text.contains(' '):
			return _matching_values(
				ENUM_VALUES['action_flag'],
				line_text.substr(line_text.rfind(' ') + 1)
			)

	if line_text.begins_with('lang;'):
		var language_parts: PackedStringArray = line_text.split(';')
		if language_parts.size() == 2 and not language_parts[1].contains(' '):
			return _matching_values(ENUM_VALUES['lang'], language_parts[1])
		return []

	if line_text.contains(' '):
		var key: String = line_text.get_slice(' ', 0)
		var value: String = line_text.substr(line_text.find(' ') + 1).strip_edges()
		return _get_value_options(key, value)

	if _is_first_replica_line(code_edit, line_index) and not manual:
		return []

	return _matching_values(_dictionary_keys(REPLICA_PROPERTIES), line_text)


## Получить варианты значений конкретного свойства
func _get_value_options(key: String, current_value: String) -> Array[String]:
	if not ENUM_VALUES.has(key):
		return []

	return _matching_values(ENUM_VALUES[key], current_value)


## Отфильтровать варианты по введённому префиксу
func _matching_values(values: Array, prefix: String) -> Array[String]:
	var result: Array[String] = []
	var normalized_prefix: String = prefix.to_lower()

	for value: String in values:
		if value.to_lower().begins_with(normalized_prefix):
			result.append(value)

	return result


## Преобразовать ключи словаря в типизированный массив
func _dictionary_keys(source: Dictionary) -> Array[String]:
	var result: Array[String] = []

	for key: String in source:
		result.append(key)

	return result


## Получить описание свойства или директивы
func _get_description(symbol: String) -> String:
	if REPLICA_PROPERTIES.has(symbol):
		return REPLICA_PROPERTIES[symbol]

	if DIALOG_PROPERTIES.has(symbol):
		return DIALOG_PROPERTIES[symbol]

	if SYNTAX_HINTS.has(symbol):
		return SYNTAX_HINTS[symbol]

	if ENUM_VALUES.has(symbol):
		return 'Допустимые значения: ' + ', '.join(ENUM_VALUES[symbol])

	for enum_name: String in ENUM_VALUES:
		if symbol in ENUM_VALUES[enum_name]:
			return 'Допустимое значение параметра ' + enum_name

	return ''


## Обновить подсказку для свойства под курсором
func _update_hint(code_edit: CodeEdit) -> void:
	var line_index: int = code_edit.get_caret_line()
	var column: int = code_edit.get_caret_column()
	var line_text: String = code_edit.get_line(line_index).substr(0, column).strip_edges()

	if line_text.is_empty() or line_text.begins_with('//'):
		code_edit.set_code_hint('')
		return

	var key: String = line_text.get_slice(' ', 0).get_slice(';', 0)
	var description: String = _get_description(key)

	if description.is_empty():
		code_edit.set_code_hint('')
		return

	if _is_first_replica_line(code_edit, line_index) and not _is_known_replica_property(line_text):
		code_edit.set_code_hint('')
		return

	code_edit.set_code_hint(description)


## Проверить, является ли строка первой строкой реплики в блоке
func _is_first_replica_line(code_edit: CodeEdit, line_index: int) -> bool:
	for previous_line in range(line_index - 1, -1, -1):
		var previous_text: String = code_edit.get_line(previous_line).strip_edges()

		if previous_text.is_empty():
			return true

		if previous_text.begins_with('//') or previous_text.begins_with('dialog;'):
			continue

		return false

	return true


## Проверить строки файла и отметить простые синтаксические ошибки
func _refresh_diagnostics(code_edit: CodeEdit) -> void:
	var issues: Dictionary = {}
	for line_index in range(code_edit.get_line_count()):
		code_edit.clear_line_background_color(line_index)

	code_edit.set_meta('txt_dialog_issues', issues)

	var first_replica_line: bool = true
	for line_index in range(code_edit.get_line_count()):
		var line_text: String = code_edit.get_line(line_index).strip_edges()

		if line_text.is_empty():
			first_replica_line = true
			continue

		if line_text.begins_with('//'):
			continue

		if line_text.begins_with('dialog;'):
			var dialog_issue: String = _validate_dialog_line(line_text)
			_mark_issue(code_edit, line_index, dialog_issue)
			continue

		if first_replica_line:
			if _is_known_replica_property(line_text):
				first_replica_line = false
			else:
				first_replica_line = false
				continue

		var issue: String = _validate_replica_line(line_text)
		_mark_issue(code_edit, line_index, issue)
		first_replica_line = false


## Проверить директиву настройки диалога
func _validate_dialog_line(line_text: String) -> String:
	var split: PackedStringArray = line_text.split(' ', false, 1)
	var key_parts: PackedStringArray = split[0].split(';')

	if key_parts.size() != 2 or split.size() < 2:
		return 'Ожидается: dialog;<свойство> <значение>'

	if not DIALOG_PROPERTIES.has(key_parts[1]):
		return 'Неизвестное свойство диалога: ' + key_parts[1]

	var value: String = split[1]
	if value.is_empty():
		return 'Не указано значение свойства диалога'

	if key_parts[1] in ['start', 'end']:
		if value.to_lower() not in PackedStringArray(ENUM_VALUES[key_parts[1]]).map(func(item: String) -> String: return item.to_lower()):
			return 'Допустимые значения: ' + ', '.join(ENUM_VALUES[key_parts[1]])

	if key_parts[1] == 'interpolation':
		if value.to_lower() not in ENUM_VALUES['interpolation']:
			return 'Допустимые значения: ' + ', '.join(ENUM_VALUES['interpolation'])

	return ''


## Проверить свойство реплики или директиву действия
func _validate_replica_line(line_text: String) -> String:
	if line_text.begins_with('action;'):
		var action_parts: PackedStringArray = line_text.split(';')
		if action_parts.size() != 3:
			return 'Формат: action;<start|end>;<visible|sound|music> <путь>'
		if action_parts[1].to_lower() not in ENUM_VALUES['when']:
			return 'Первый параметр action должен быть start или end'
		var action_value: PackedStringArray = action_parts[2].split(' ', false, 1)
		if action_value[0].to_lower() not in ENUM_VALUES['action_type']:
			return 'Тип действия: visible, sound или music'
		if action_value.size() < 2 or action_value[1].strip_edges().is_empty():
			return 'Не указан путь к ноде'
		return ''

	if line_text.begins_with('lang;'):
		var language_parts: PackedStringArray = line_text.split(' ', false, 1)
		var key_parts: PackedStringArray = language_parts[0].split(';')
		if key_parts.size() != 2 or key_parts[1].to_lower() not in ['ru', 'en']:
			return 'Формат перевода: lang;<Ru|En> <текст>'
		if language_parts.size() < 2 or language_parts[1].is_empty():
			return 'Не указан текст перевода'
		return ''

	var split: PackedStringArray = line_text.split(' ', false, 1)
	if split.size() < 2:
		if line_text not in REPLICA_PROPERTIES:
			return 'Неизвестное свойство реплики: ' + line_text
		return 'Не указано значение свойства ' + line_text

	if not REPLICA_PROPERTIES.has(split[0]):
		return 'Неизвестное свойство реплики: ' + split[0]

	var value: String = split[1].strip_edges()
	if value.is_empty():
		return 'Не указано значение свойства ' + split[0]

	if split[0] in ['reset_text_buffer', 'small_text']:
		if value.to_lower() not in ['true', 'false', '1', '0', 'yes', 'no', 'on', 'off', 'да', 'нет', 'вкл', 'выкл']:
			return 'Ожидается логическое значение true или false'

	if split[0] == 'interpolation' and value not in ENUM_VALUES['interpolation']:
		return 'Допустимые значения: ' + ', '.join(ENUM_VALUES['interpolation'])

	if split[0] == 'language' and value.to_lower() not in ['ru', 'en']:
		return 'Допустимые значения: Ru или En'

	if split[0] == 'speaker' and value not in ENUM_VALUES['speaker']:
		return 'Персонаж не найден в Character.CharacterType'

	if split[0] == 'emotion' and value not in ENUM_VALUES['emotion']:
		return 'Эмоция не найдена в Replica.Emotion'

	return ''


## Проверить, является ли строка известным свойством реплики
func _is_known_replica_property(line_text: String) -> bool:
	var key: String = line_text.get_slice(' ', 0).get_slice(';', 0)
	return REPLICA_PROPERTIES.has(key) or key in ['action', 'lang']


## Отметить строку с диагностикой
func _mark_issue(code_edit: CodeEdit, line_index: int, message: String) -> void:
	if message.is_empty():
		return

	code_edit.set_line_background_color(line_index, ERROR_LINE_COLOR)
	var issues: Dictionary = code_edit.get_meta('txt_dialog_issues', {})
	issues[line_index] = message
	code_edit.set_meta('txt_dialog_issues', issues)
