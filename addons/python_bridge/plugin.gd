@tool
extends EditorPlugin

const ExportPlugin := preload("res://addons/python_bridge/export_plugin.gd")
const AUTOLOAD_NAME := "PythonBridge"
const AUTOLOAD_PATH := "res://addons/python_bridge/python_bridge.gd"

var _export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	_add_setting("python_bridge/scripts_dir", "res://py", TYPE_STRING, PROPERTY_HINT_DIR)
	_add_setting("python_bridge/auto_start", true, TYPE_BOOL)
	_add_setting("python_bridge/editor_interpreter", "", TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE)
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


func _enable_plugin() -> void:
	add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton(AUTOLOAD_NAME)


func _add_setting(setting: String, default: Variant, type: int, hint := PROPERTY_HINT_NONE, hint_string := "") -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default)
	ProjectSettings.set_initial_value(setting, default)
	ProjectSettings.add_property_info({
		"name": setting, "type": type, "hint": hint, "hint_string": hint_string,
	})
