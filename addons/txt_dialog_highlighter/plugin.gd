@tool
extends EditorPlugin


const EditorSupport = preload(
	'res://addons/txt_dialog_highlighter/editor/editor_support.gd'
)

var _editor_support: Node


## Подключить поддержку подсветки TXTLinearDialog
func _enter_tree() -> void:
	_add_color_settings()

	_editor_support = EditorSupport.new()
	add_child(_editor_support)


## Отключить поддержку подсветки TXTLinearDialog
func _exit_tree() -> void:
	if is_instance_valid(_editor_support):
		_editor_support.queue_free()
		_editor_support = null


## Зарегистрировать пользовательские цвета в настройках редактора
func _add_color_settings() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var colors: Dictionary = {
		'dialogue_text_color': Color.WHITE,
		'property_color': Color(0.4, 0.8, 1.0),
		'value_color': Color(0.75, 0.85, 0.95),
		'dialog_property_color': Color(0.8, 0.6, 1.0),
		'action_color': Color(1.0, 0.7, 0.35),
		'unknown_property_color': Color(1.0, 0.35, 0.35),
		'comment_color': Color(0.5, 0.55, 0.6),
	}

	for setting_name: String in colors:
		var setting_path: String = (
			'text_editor/theme/highlighting/txt_dialog_' + setting_name
		)
		if not settings.has_setting(setting_path):
			settings.set_setting(setting_path, colors[setting_name])

		settings.set_initial_value(setting_path, colors[setting_name], false)
		settings.add_property_info({
			'name': setting_path,
			'type': TYPE_COLOR,
		})
