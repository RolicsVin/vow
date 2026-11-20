@tool
extends EditorPlugin

## Настройка режима обфускации: "safe" (только локальные идентификаторы,
## поведение аддона как раньше) или "full" (дополнительно переименовываются
## функции, публичные переменные и сигналы; .tscn/.tres обновляются синхронно).
const SETTING_MODE: String = "export_to_obfuscate/mode"

## Папки, которые полный режим не сканирует и не переименовывает.
## По умолчанию исключены все аддоны, чтобы не затронуть сторонний код
## и сам аддон ExportToObfuscate.
const SETTING_EXCLUDE_DIRS: String = "export_to_obfuscate/full_mode_exclude_dirs"

## Дополнительные имена функций/переменных/сигналов, которые полный режим
## никогда не должен переименовывать (например собственные колбэки, на
## которые ссылается внешний код по строковому имени).
const SETTING_RESERVED_NAMES: String = "export_to_obfuscate/full_mode_extra_reserved_names"

var export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_register_settings()
	export_plugin = preload("export_plugin.gd").new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(export_plugin)
	export_plugin = null


func _register_settings() -> void:
	_add_setting(SETTING_MODE, "safe", TYPE_STRING, PROPERTY_HINT_ENUM, "safe,full")
	_add_setting(
		SETTING_EXCLUDE_DIRS,
		PackedStringArray(["res://addons"]),
		TYPE_PACKED_STRING_ARRAY,
		PROPERTY_HINT_NONE,
		""
	)
	_add_setting(
		SETTING_RESERVED_NAMES,
		PackedStringArray(),
		TYPE_PACKED_STRING_ARRAY,
		PROPERTY_HINT_NONE,
		""
	)


func _add_setting(
	setting_name: String,
	default_value: Variant,
	type: int,
	hint: int,
	hint_string: String
) -> void:
	if not ProjectSettings.has_setting(setting_name):
		ProjectSettings.set_setting(setting_name, default_value)

	ProjectSettings.set_initial_value(setting_name, default_value)
	ProjectSettings.add_property_info({
		"name": setting_name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})
	ProjectSettings.set_as_basic(setting_name, true)
