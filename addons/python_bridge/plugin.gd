@tool
extends EditorPlugin

const ExportPlugin := preload("res://addons/python_bridge/export_plugin.gd")
const EditorSupport := preload("res://addons/python_bridge/editor/editor_support.gd")
const CreateMenuPlugin := preload("res://addons/python_bridge/editor/create_menu_plugin.gd")
const AUTOLOAD_NAME := "PythonBridge"
const AUTOLOAD_PATH := "res://addons/python_bridge/python_bridge.gd"
const MENU_NEW_SCRIPT := "New Python script..."

var _export_plugin: EditorExportPlugin
var _editor_support: Node
var _create_menu: EditorContextMenuPlugin


func _enter_tree() -> void:
	_add_setting("python_bridge/scripts_dir", "res://py", TYPE_STRING, PROPERTY_HINT_DIR)
	_add_setting("python_bridge/auto_start", true, TYPE_BOOL)
	_add_setting("python_bridge/editor_support", true, TYPE_BOOL)
	_add_setting("python_bridge/script_dialog_hook", false, TYPE_BOOL)
	_add_setting("python_bridge/editor_interpreter", "", TYPE_STRING, PROPERTY_HINT_GLOBAL_FILE)
	_export_plugin = ExportPlugin.new()
	add_export_plugin(_export_plugin)

	if ProjectSettings.get_setting("python_bridge/editor_support", true):
		_editor_support = EditorSupport.new()
		add_child(_editor_support)
		add_tool_menu_item(MENU_NEW_SCRIPT, _editor_support.show_new_script_dialog)
		_create_menu = CreateMenuPlugin.new(_editor_support.show_new_script_in)
		add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM_CREATE, _create_menu)


func _exit_tree() -> void:
	if _create_menu != null:
		remove_context_menu_plugin(_create_menu)
		_create_menu = null
	if _editor_support != null:
		remove_tool_menu_item(MENU_NEW_SCRIPT)
		_editor_support.queue_free()
		_editor_support = null
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
