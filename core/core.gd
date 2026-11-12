## Ядро игры.
## Объединяет игровые модули и централизованно управляет SQL-сохранениями.
extends Node

const SAVE_INTERVAL := 15.0

var _buffer: Dictionary = {}
var _save_elapsed: float = 0.0
var _data_loaded: bool = false

# Инструменты
var tools: GTTools = ToolFactory.make_tool(self, "res://core/tools/tools.gd", "Tools")
var window_tools: WindowTools = ToolFactory.make_tool(self, "res://core/tools/window_tools.gd", "WindowTools")
var time_tools: TimeTools = ToolFactory.make_tool(self, "res://core/tools/time_tools.gd", "TimeTools")
var scene_tools: SceneTools = ToolFactory.make_tool(self, "res://core/tools/scene_tools.gd", "SceneTools")
var platform_tools: PlatformTools = ToolFactory.make_tool(self, "res://core/tools/platform_tools.gd", "PlatformTools")


func _ready() -> void:
	# Сцена Map и её бассейны должны завершить _ready() до загрузки модульных данных.
	call_deferred("_load_after_scene_ready")


func _load_after_scene_ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	load_data()


func _process(delta: float) -> void:
	if not _data_loaded:
		return

	_save_elapsed += delta
	if _save_elapsed >= SAVE_INTERVAL:
		_save_elapsed = 0.0
		save_data()


func _get_modules() -> Array[Node]:
	var modules: Array[Node] = []
	for child in get_children():
		if child.has_method("get_save_data") and child.has_method("load_data"):
			modules.append(child)
	return modules


func save_data() -> void:
	pass


func load_data() -> void:
	pass


func _notification(what: int) -> void:
	if not _data_loaded:
		return

	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_data()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		load_data()


func _print_log() -> void:
	print("Печатает ядро игры. (core.gd)")


func _get_obj_on_buffer(k):
	return _buffer[k]


func _get_buffer() -> Dictionary:
	return _buffer


func _write_buffer(obj, k) -> void:
	_buffer[k] = obj


func clear_buffer() -> void:
	_buffer.clear()


func push_fatal_error(message: String) -> void:
	print(message)
	push_error(message)
	Engine.get_main_loop().quit()
