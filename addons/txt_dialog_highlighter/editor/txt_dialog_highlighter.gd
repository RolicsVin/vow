@tool
## Подсветка синтаксиса TXTLinearDialog в редакторе Godot 
class_name TXTLinearDialogEditorHighlighter extends EditorSyntaxHighlighter


## Цвет текста реплики
const DEFAULT_DIALOGUE_TEXT_COLOR: Color = Color.WHITE

## Цвет названий свойств
const DEFAULT_PROPERTY_COLOR: Color = Color(0.4, 0.8, 1.0)

## Цвет значений свойств
const DEFAULT_VALUE_COLOR: Color = Color(0.75, 0.85, 0.95)

## Цвет настроек диалога
const DEFAULT_DIALOG_PROPERTY_COLOR: Color = Color(0.8, 0.6, 1.0)

## Цвет команд действий
const DEFAULT_ACTION_COLOR: Color = Color(1.0, 0.7, 0.35)

## Цвет неизвестных свойств
const DEFAULT_UNKNOWN_PROPERTY_COLOR: Color = Color(1.0, 0.35, 0.35)

## Цвет комментариев
const DEFAULT_COMMENT_COLOR: Color = Color(0.5, 0.55, 0.6)

## Путь к настройкам цветов редактора
const COLOR_SETTING_PREFIX: String = 'text_editor/theme/highlighting/txt_dialog_'

## Допустимые свойства реплики
const REPLICA_KEYS: PackedStringArray = [
	'speaker',
	'name',
	'emotion',
	'background',
	'sound',
	'color',
	'chat_color',
	'character_emotion',
	'interpolation',
	'reset_text_buffer',
	'small_text',
	'language',
	'id',
]


## Получить имя подсветчика
func _get_name() -> String:
	return 'TXTLinearDialog'


## Получить список поддерживаемых языков
func _get_supported_languages() -> PackedStringArray:
	return PackedStringArray()


## Создать отдельный экземпляр подсветчика для вкладки
func _create() -> EditorSyntaxHighlighter:
	return get_script().new()


## Сбросить кеш подсветки
func _update_cache() -> void:
	pass


## Получить подсветку указанной строки
func _get_line_syntax_highlighting(line: int) -> Dictionary:
	var text_edit: TextEdit = get_text_edit()
	if not is_instance_valid(text_edit):
		return {}

	if line < 0 or line >= text_edit.get_line_count():
		return {}

	var line_text: String = text_edit.get_line(line)
	var normalized_line: String = line_text.strip_edges()
	if normalized_line.is_empty():
		return {}

	var colors: Dictionary = _get_colors()
	var result: Dictionary = {}
	var offset: int = line_text.find(normalized_line)

	if normalized_line.begins_with('//'):
		result[offset] = {'color': colors['comment']}
		return result

	result[0] = {'color': colors['dialogue_text']}

	if _is_first_content_line(text_edit, line):
		if not _is_property_line(normalized_line):
			return result

	var separator: int = _find_separator(normalized_line)
	if separator == -1:
		var key_color: Color = _get_key_color(normalized_line, colors)
		_set_color(result, offset, key_color)
		return result

	var key: String = normalized_line.substr(0, separator)
	var value_start: int = separator + 1
	while value_start < normalized_line.length():
		if normalized_line[value_start] != ' ' and normalized_line[value_start] != '\t':
			break
		value_start += 1

	var key_color: Color = _get_key_color(key, colors)
	var value_color: Color = colors['value']
	if key.begins_with('lang;'):
		value_color = colors['dialogue_text']

	_set_color(result, offset, key_color)
	if value_start < normalized_line.length():
		_set_color(result, offset + value_start, value_color)

	return result


## Проверить, является ли строка первой содержательной строкой блока
func _is_first_content_line(text_edit: TextEdit, line: int) -> bool:
	for previous_line in range(line - 1, -1, -1):
		var previous_text: String = text_edit.get_line(previous_line).strip_edges()

		if previous_text.is_empty():
			return true

		if previous_text.begins_with('//'):
			continue

		return false

	return true


## Проверить, распознаётся ли строка как свойство формата
func _is_property_line(line: String) -> bool:
	var separator: int = _find_separator(line)
	var key: String = line if separator == -1 else line.substr(0, separator)

	if key.begins_with('dialog;') or key.begins_with('lang;'):
		return true

	if key.begins_with('action;'):
		return true

	return key in REPLICA_KEYS


## Получить цвет ключа в соответствии с синтаксисом
func _get_key_color(key: String, colors: Dictionary) -> Color:
	if key.begins_with('dialog;'):
		return colors['dialog_property']

	if key.begins_with('lang;'):
		return colors['property']

	if key.begins_with('action;') or key == 'action':
		return colors['action']

	if key in REPLICA_KEYS or key == 'lang':
		return colors['property']

	return colors['unknown_property']


## Найти разделитель между ключом и значением
func _find_separator(line: String) -> int:
	for index in range(line.length()):
		var character: String = line[index]
		if character == ' ' or character == '\t':
			return index

	return -1


## Получить цвета из пользовательских настроек редактора
func _get_colors() -> Dictionary:
	var settings: EditorSettings = EditorInterface.get_editor_settings()

	return {
		'dialogue_text': _get_color(
			settings,
			'dialogue_text_color',
			DEFAULT_DIALOGUE_TEXT_COLOR
		),
		'property': _get_color(settings, 'property_color', DEFAULT_PROPERTY_COLOR),
		'value': _get_color(settings, 'value_color', DEFAULT_VALUE_COLOR),
		'dialog_property': _get_color(
			settings,
			'dialog_property_color',
			DEFAULT_DIALOG_PROPERTY_COLOR
		),
		'action': _get_color(settings, 'action_color', DEFAULT_ACTION_COLOR),
		'unknown_property': _get_color(
			settings,
			'unknown_property_color',
			DEFAULT_UNKNOWN_PROPERTY_COLOR
		),
		'comment': _get_color(settings, 'comment_color', DEFAULT_COMMENT_COLOR),
	}


## Получить цвет из EditorSettings или вернуть значение по умолчанию
func _get_color(
	settings: EditorSettings,
	setting_name: String,
	default_color: Color
) -> Color:
	var setting_path: String = COLOR_SETTING_PREFIX + setting_name
	var value: Variant = settings.get_setting(setting_path)

	return value if value is Color else default_color


## Установить цвет для указанной позиции строки
func _set_color(result: Dictionary, position: int, color: Color) -> void:
	result[position] = {'color': color}
