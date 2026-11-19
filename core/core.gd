## Ядро игры. 
## Объединяет игровые модули. 
extends Node

const save_path: String = 'user://'

var _buffer: Dictionary = {}

# Инструменты
var tools: GTTools = ToolFactory.make_tool(self, 'res://core/tools/tools.gd', 'Tools')
var window_tools: WindowTools = ToolFactory.make_tool(self, 'res://core/tools/window_tools.gd', 'WindowTools')
var time_tools: TimeTools = ToolFactory.make_tool(self, 'res://core/tools/time_tools.gd', 'TimeTools')
var scene_tools: SceneTools = ToolFactory.make_tool(self, 'res://core/tools/scene_tools.gd', 'SceneTools')
var platform_tools: PlatformTools = ToolFactory.make_tool(self, 'res://core/tools/platform_tools.gd', 'PlatformTools')


## Выводит заголовок лога ядра.
func _print_log() -> void:
	print('Печатает центральное ядро игры. (core.gd)-------------------------------------------------')


## Завершает блок лога ядра.
func _end_log() -> void:
	print('------------------------------------------------------------------------------------------')
	print()


## Выполняет инициализацию ядра.
func _ready() -> void:
	pass


## Собирает данные модулей и записывает их в файл сохранения.
func save_data() -> String:
	_print_log()
	print('Создание сохранения...')

	var save_name: String = 'vow' + tools.get_project_version() + '_number' + str(len(get_saves())) + '.save'

	var icon: Image = window_tools.take_screenshot()
	var screen_size: Vector2i = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	icon.resize(round(screen_size.x / 3), round(screen_size.y / 3), Image.INTERPOLATE_CUBIC)

	# Модули возвращают данные синхронно, поэтому сохранение собирается в одном последовательном вызове
	var data: Dictionary = {
		'godo_combat': GCombat.get_save(),
		'godo_mini_game': GminiGame.get_save(),
		'godo_visual_novel': GVisualNovel.get_save(),
		'scene': get_tree().current_scene.scene_file_path,
		'version': tools.get_project_version(),
		'data': time_tools.get_date(),
		'time': time_tools.get_time(),
		'icon_data': icon.save_jpg_to_buffer()
	}

	print('Сохранение создано: ')
	var response: Dictionary = PythonBridge.call_function('stdout', 'pretty_print', [data])
	if response.get('ok', false):
		print(response.get('result', ''))
	else:
		push_error('[Core] Не удалось вывести сохранение через PythonBridge: %s' % response.get('error', 'unknown error'))
	print()
	print('Запись сохранения...')

	var file: FileAccess = FileAccess.open((save_path + save_name).replace('"', ''), FileAccess.WRITE)
	if file == null:
		push_error('[Core] Не удалось создать файл сохранения: %s' % save_name)
		_end_log()
		return ''

	file.store_var(data)
	file.close()

	print('Сохранение записано.')

	_end_log()
	return save_name


## Возвращает список файлов сохранений.
func get_saves() -> Array[String]:
	var dir: DirAccess = DirAccess.open(save_path)

	if dir == null:
		_print_log()
		print('Не удалось открыть папку')
		_end_log()
		return []

	var save_files: Array[String] = []
	for file_name: String in dir.get_files():
		save_files.append(file_name)

	return save_files


## Читает файл сохранения и возвращает его содержимое.
func get_save(save_name: String) -> Dictionary:
	_print_log()
	print('Чтение сохранения...')
	var file: FileAccess = FileAccess.open(save_path + save_name, FileAccess.READ)
	if file == null:
		push_error('[Core] Не удалось открыть сохранение для чтения: %s' % save_name)
		_end_log()
		return {}

	var raw_data: Variant = file.get_var()
	file.close()
	if not raw_data is Dictionary:
		push_error('[Core] Файл сохранения повреждён или пуст: %s' % save_name)
		_end_log()
		return {}

	var data: Dictionary = raw_data
	if not data.has('icon_data'):
		push_error('[Core] В сохранении отсутствуют данные иконки: %s' % save_name)
		_end_log()
		return {}

	var icon: Image = Image.new()
	icon.load_jpg_from_buffer(data['icon_data'])

	data['icon'] = icon
	data.erase('icon_data')

	print('Сохранение прочитано.')
	var response: Dictionary = PythonBridge.call_function('stdout', 'pretty_print', [data])
	if response.get('ok', false):
		print(response.get('result', ''))
	else:
		push_error('[Core] Не удалось вывести сохранение через PythonBridge: %s' % response.get('error', 'unknown error'))
	_end_log()

	return data


## Восстанавливает состояние всех модулей и переключает игровую сцену.
func load_save(_save: Dictionary) -> void:
	_print_log()

	print('Загрузка сохранения...')
	# Загрузка модулей выполняется последовательно без await
	GCombat.load_save(_save['godo_combat'])
	if _save.has('godo_mini_game'):
		GminiGame.load_save(_save['godo_mini_game'])
	GVisualNovel.load_save(_save['godo_visual_novel'])
	Core.scene_tools.change_scene(_save['scene'])
	print('Сохранение загружено.')

	_end_log()


## Возвращает объект из буфера по ключу.
func _get_obj_on_buffer(key: Variant) -> Variant:
	return _buffer[key]


## Возвращает буфер ядра.
func _get_buffer() -> Dictionary:
	return _buffer


## Записывает объект в буфер по ключу.
func _write_buffer(obj: Variant, key: Variant) -> void:
	_buffer[key] = obj


## Очищает буфер ядра.
func clear_buffer() -> void:
	push_warning('Буффер был очищен')
	_buffer.clear()


## Выводит фатальную ошибку и завершает игру.
func push_fatal_error(message: String) -> void:
	print(message)
	push_error(message)
	Engine.get_main_loop().quit()


## Выводит значения переменных всех синглтонов.
func print_all_singleton_variables() -> void:
	_print_log()
	print('Запрошен лог всех синглтонов')
	push_warning('Запрошен лог всех синглтонов')
	print()

	var root: Window = get_tree().root

	for singleton: Node in root.get_children():
		var properties: Array[Dictionary] = singleton.get_property_list()
		var has_variables: bool = false

		for property: Dictionary in properties:
			# Берём только переменные, объявленные в скрипте
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				if not has_variables:
					print('\n========== ', singleton.name, ' ==========')
					has_variables = true

				var variable_name: String = property.name
				var value: Variant = singleton.get(variable_name)

				print(variable_name, ' = ', value)

	_end_log()
