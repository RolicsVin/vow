## Ядро игры. 
## Объединяет игровые модули. 
extends Node

const save_path: String = 'user://'

var _buffer: Dictionary = {}

# Инструменты
var tools: GTTools = ToolFactory.make_tool(self, "res://core/tools/tools.gd", "Tools")
var window_tools: WindowTools = ToolFactory.make_tool(self, "res://core/tools/window_tools.gd", "WindowTools")
var time_tools: TimeTools = ToolFactory.make_tool(self, "res://core/tools/time_tools.gd", "TimeTools")
var scene_tools: SceneTools = ToolFactory.make_tool(self, "res://core/tools/scene_tools.gd", "SceneTools")
var platform_tools: PlatformTools = ToolFactory.make_tool(self, "res://core/tools/platform_tools.gd", "PlatformTools")


func _print_log() -> void:
	print("Печатает центральное ядро игры. (core.gd)-------------------------------------------------")


func _end_log() -> void:
	print("------------------------------------------------------------------------------------------")
	print()


func save_data() -> void:
	_print_log()
	print('Создание сохранения...')
	
	var save_name = 'vow' + tools.get_project_version() + '_number' + str(len(get_saves())) + '.save'
	
	var icon = window_tools.take_screenshot()
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	icon.resize(round(screen_size.x / 3), round(screen_size.y / 3), Image.INTERPOLATE_CUBIC)
	
	var data = {
		'godo_combat': GCombat.get_save(),
		'godo_visual_novel': await GVN.get_save(),
		'scene': get_tree().current_scene.scene_file_path,
		'version': tools.get_project_version(),
		'data': time_tools.get_date(),
		'time': time_tools.get_time(),
		'icon_data': icon.save_jpg_to_buffer()
	}
	
	print('Сохранение создано: ')
	var response: Dictionary = await PythonBridge.call_function('stdout', 'pretty_print', [data])
	if response.get("ok", false):
		print(response.get("result", ""))
	else:
		push_error("[Core] Не удалось вывести сохранение через PythonBridge: %s" % response.get("error", "unknown error"))
	print()
	print('Запись сохранения...')
	
	var file = FileAccess.open((save_path + save_name).replace('"', ''), FileAccess.WRITE)
	file.store_var(data)
	
	print('Сохранение записано.')
	
	_end_log()


func get_saves():
	"""Возращает список файлов(Array[String]), если такая папка существует."""
	var dir = DirAccess.open(save_path)
	
	if dir == null:
		_print_log()
		print("Не удалось открыть папку")
		_end_log()
		return
	
	return dir.get_files()


func get_save(save_name: String) -> Dictionary:
	_print_log()
	print('Чтение сохранения...')
	var file = FileAccess.open(save_path + save_name, FileAccess.READ)
	var data: Dictionary = file.get_var()
	 
	var icon = Image.new()
	icon.load_jpg_from_buffer(data['icon_data'])
	
	data['icon'] = icon
	data.erase('icon_data')
	
	print('Сохранение прочитано.')
	var response: Dictionary = await PythonBridge.call_function('stdout', 'pretty_print', [data])
	print(response.result)
	if not response.get("ok", false):
		push_error("[Core] Не удалось вывести сохранение через PythonBridge: %s" % response.get("error", "unknown error"))
	_end_log()
	
	return data


func load_save(_save: Dictionary):
	_print_log()
	
	print('Загрузка сохранения...')
	GCombat.load_save(_save['godo_combat'])
	GVN.load_save(_save['godo_visual_novel'])
	Core.scene_tools.change_scene(_save['scene'])
	print('Сохранение загружено.')
	
	_end_log()


func _get_obj_on_buffer(k):
	return _buffer[k]


func _get_buffer() -> Dictionary:
	return _buffer


func _write_buffer(obj, k) -> void:
	_buffer[k] = obj


func clear_buffer() -> void:
	push_warning('Буффер был очищен')
	_buffer.clear()


func push_fatal_error(message: String) -> void:
	print(message)
	push_error(message)
	Engine.get_main_loop().quit()


func print_all_singleton_variables() -> void:
	_print_log()
	print('Запрошен лог всех синглтонов')
	push_warning('Запрошен лог всех синглтонов')
	print()
	
	var root := get_tree().root
	
	for singleton in root.get_children():
		var properties := singleton.get_property_list()
		var has_variables := false
		
		for property in properties:
			# Берём только переменные, объявленные в скрипте
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if not has_variables:
					print("\n========== ", singleton.name, " ==========")
					has_variables = true
				
				var variable_name: String = property.name
				var value = singleton.get(variable_name)
				
				print(variable_name, " = ", value)
	
	_end_log()
