## Ядро игры. 
## Объединяет игровые модули. 
## Защищает игру. 
extends Node

## Прямая ссылка на общий манифест (список манифестов всех ваших игр).
const GENERAL_MANIFEST_URL: String = (
	'https://drive.google.com/file/d/19GdjIRYv0pmPzWMF26nqgsgplxF79k3T/'
	+ 'view?usp=drive_link'
)

const GAME_MANIFEST_KEY: String = 'vow_manifest' ## Ключ этой игры в общем манифесте.
const MAX_MANIFEST_SIZE: int = 1024 * 1024 ## Максимальный размер одного JSON-манифеста

const SAVE_PATH: String = 'user://'

var _buffer: Dictionary = {} ## Общий буффер дял всей игры
## Менеджер аудиосистемы
var audio_server: AudioServerManager = AudioServerManager.new()
var protector: RuntimeProtector ## Защита

# Инструменты
## Общие инструменты ядра
var tools: GTTools = ToolFactory.make_tool(self, 'res://core/tools/tools.gd', 'Tools')
var window_tools: WindowTools = ToolFactory.make_tool(
	self, 'res://core/tools/window_tools.gd', 'WindowTools'
) ## Инструменты управления окном
var time_tools: TimeTools = ToolFactory.make_tool(
	self, 'res://core/tools/time_tools.gd', 'TimeTools'
) ## Инструменты работы со временем
var scene_tools: SceneTools = ToolFactory.make_tool(
	self, 'res://core/tools/scene_tools.gd', 'SceneTools'
) ## Инструменты управления сценами
var platform_tools: PlatformTools = ToolFactory.make_tool(
	self, 'res://core/tools/platform_tools.gd', 'PlatformTools'
) ## Инструменты определения платформы


## Выводит заголовок лога ядра
func _print_log() -> void:
	print('Печатает центральное ядро игры. (core.gd)-------------------------------------------------')


## Завершает блок лога ядра
func _end_log() -> void:
	print('------------------------------------------------------------------------------------------')
	print('')


## Настраивает защиту и запускает проверку релизной сборки
func _ready() -> void:
	_print_log()
	print('Стартовало ядро игры')
	
	print('Создание протектора...')
	protector = RuntimeProtector.new()
	
	# Настраиваем узел до add_child(), поскольку _ready() C++-расширения
	# вызывается непосредственно при добавлении узла в дерево
	protector.debugger_detected.connect(_on_debugger_detected)
	protector.hook_detected.connect(_on_hook_detected)
	protector.tampering_detected.connect(_on_tampering_detected)
	protector.check_interval_ms = 2000
	protector.enable_anti_debug = true
	protector.enable_anti_hook = true
	protector.enable_anti_tamper = false
	protector.reaction_mode = RuntimeProtector.REACTION_CRASH
	
	if OS.has_feature('template'):
		protector.pck_path = OS.get_executable_path().get_base_dir().path_join('vow.pck')
	
	if not protector.self_test_sha256():
		await push_fatal_error(
			'RuntimeProtector: SHA-256 self-test failed — hash checks cannot be trusted'
		)
		return
	
	add_child(protector)
	print('Протектор создан.')
	
	# Локальная C++-проверка выполняется синхронно внутри add_child()
	if not protector.is_release_verified():
		return
	
	if OS.has_feature('template'):
		await _fetch_expected_hashes()
	else:
		print('Обнаружена работа в редакторе: удалённая проверка отключена')
		protector.enable_anti_tamper = false
		protector.start_protection()
	
	print('Протектор настроен.')
	_end_log()


## Загружает общий и игровой манифесты, затем включает сверку хешей
func _fetch_expected_hashes() -> void:
	## Прямой URL общего манифеста
	var general_manifest_url: String = await _resolve_manifest_url(GENERAL_MANIFEST_URL)
	if general_manifest_url.is_empty():
		push_warning('[Core] Не удалось разрешить URL общего манифеста. Удалённая сверка пропущена.')
		_start_protection_without_remote()
		return
	
	## Результат загрузки общего манифеста
	var general_response: Dictionary = await _download_manifest(general_manifest_url)
	if not general_response.get('transport_ok', false):
		push_warning('[Core] Общий манифест недоступен. Удалённая сверка пропущена.')
		_start_protection_without_remote()
		return
	if general_response.get('malformed', false):
		_reject_remote_manifest('[Core] Общий манифест превышает допустимый размер.')
		return
	
	## Тело общего манифеста
	var general_body: PackedByteArray = general_response.get('body', PackedByteArray())
	## Распарсенный общий манифест
	var general_manifest: Variant = JSON.parse_string(general_body.get_string_from_utf8())
	if not general_manifest is Dictionary:
		_reject_remote_manifest(
			'[Core] Загруженный общий манифест повреждён или не является JSON-объектом.'
		)
		return
	
	## Ссылка на манифест текущей игры
	var game_manifest_reference: Variant = general_manifest.get(GAME_MANIFEST_KEY)
	if not game_manifest_reference is String or game_manifest_reference.is_empty():
		_reject_remote_manifest(
			'[Core] В общем манифесте отсутствует корректная ссылка «%s».' % GAME_MANIFEST_KEY
		)
		return
	
	## Прямой URL манифеста игры
	var game_manifest_url: String = await _resolve_manifest_url(game_manifest_reference)
	if game_manifest_url.is_empty():
		_reject_remote_manifest('[Core] Ссылка на манифест игры в общем манифесте некорректна.')
		return
	
	## Результат загрузки манифеста игры
	var game_response: Dictionary = await _download_manifest(game_manifest_url)
	if not game_response.get('transport_ok', false):
		push_warning('[Core] Манифест игры недоступен. Удалённая сверка пропущена.')
		_start_protection_without_remote()
		return
	if game_response.get('malformed', false):
		_reject_remote_manifest('[Core] Манифест игры превышает допустимый размер.')
		return
	
	## Тело манифеста игры
	var game_body: PackedByteArray = game_response.get('body', PackedByteArray())
	## Распарсенный манифест игры
	var game_manifest: Variant = JSON.parse_string(game_body.get_string_from_utf8())
	if not game_manifest is Dictionary:
		_reject_remote_manifest(
			'[Core] Загруженный манифест игры повреждён или не является JSON-объектом.'
		)
		return
	
	# Обязательные хеши релизных файлов
	## Ожидаемый хеш PCK
	var pck_hash: Variant = game_manifest.get('pck_cache')
	## Ожидаемый хеш EXE
	var exe_hash: Variant = game_manifest.get('exe_cache')
	## Ожидаемый хеш библиотеки
	var library_hash: Variant = game_manifest.get('lib_cache')
	## Ожидаемый хеш каталога Python
	var runtime_hash: Variant = game_manifest.get('runtime_cache', '')
	
	if not _is_valid_sha256(pck_hash):
		_reject_remote_manifest('[Core] pck_cache отсутствует или содержит некорректный SHA-256.')
		return
	if not _is_valid_sha256(exe_hash):
		_reject_remote_manifest('[Core] exe_cache отсутствует или содержит некорректный SHA-256.')
		return
	if not _is_valid_sha256(library_hash):
		_reject_remote_manifest('[Core] lib_cache отсутствует или содержит некорректный SHA-256.')
		return
	if not runtime_hash is String:
		_reject_remote_manifest('[Core] runtime_cache должен быть строкой.')
		return
	if not runtime_hash.is_empty() and not _is_valid_sha256(runtime_hash):
		_reject_remote_manifest('[Core] runtime_cache содержит некорректный SHA-256.')
		return
	
	# Передаём ожидаемые значения в AntiTamper только после полной валидации JSON
	protector.expected_pck_hash = pck_hash
	protector.expected_exe_hash = exe_hash
	protector.expected_library_hash = library_hash
	if not runtime_hash.is_empty():
		protector.runtime_dir_path = OS.get_executable_path().get_base_dir().path_join('python_runtime')
		protector.expected_runtime_dir_hash = runtime_hash
	protector.enable_anti_tamper = true
	
	# Проверяем файлы до запуска фонового потока, чтобы не допустить старта игры
	if not protector.verify_pck_now():
		_reject_remote_manifest('[Core] SHA-256 PCK не совпадает с удалённым манифестом.')
		return
	if not protector.verify_exe_now():
		_reject_remote_manifest('[Core] SHA-256 EXE не совпадает с удалённым манифестом.')
		return
	if not protector.verify_library_now():
		_reject_remote_manifest(
			'[Core] SHA-256 RuntimeProtector DLL не совпадает с удалённым манифестом.'
		)
		return
	if not runtime_hash.is_empty() and not protector.verify_runtime_dir_now():
		_reject_remote_manifest(
			'[Core] SHA-256 каталога python_runtime не совпадает с удалённым манифестом.'
		)
		return
	
	protector.start_protection()


## Загружает один манифест; транспортная ошибка отделена от некорректного содержимого
func _download_manifest(url: String) -> Dictionary:
	## HTTP-клиент для загрузки манифеста
	var http: HTTPRequest = HTTPRequest.new()
	http.timeout = 10.0
	http.body_size_limit = MAX_MANIFEST_SIZE
	add_child(http)
	
	## Код ошибки запуска HTTP-запроса
	var request_error: Error = http.request(url)
	if request_error != OK:
		http.queue_free()
		return {'transport_ok': false}
	
	## Ответ HTTP-клиента
	var response: Array = await http.request_completed
	http.queue_free()
	
	## Результат выполнения HTTP-запроса
	var result: int = response[0]
	## HTTP-код ответа сервера
	var response_code: int = response[1]
	## Загруженное тело ответа
	var body: PackedByteArray = response[3]
	
	if result == HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
		return {'transport_ok': true, 'malformed': true}
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return {'transport_ok': false}
	
	return {'transport_ok': true, 'body': body}


## Разрешает ссылку на Google Drive в прямой URL загрузки
func _resolve_manifest_url(value: Variant) -> String:
	if not value is String or value.is_empty():
		return ''
	
	## Ответ HTTP-клиента
	var response: Dictionary = await PythonBridge.call_function('tools', 'drive_direct_url', [value])
	if not response.get('ok', false):
		push_warning('[Core] drive_direct_url не смог разобрать ссылку: %s' % response.get('error', 'unknown error'))
		return ''
	
	return str(response.get('result', ''))


## Проверяет формат SHA-256 в нижнем регистре
func _is_valid_sha256(value: Variant) -> bool:
	if not value is String:
		return false
	## Регулярное выражение формата SHA-256
	var regex: RegEx = RegEx.new()
	regex.compile('^[0-9a-f]{64}$')
	return regex.search(value) != null


## Запускает защиту без удалённой проверки, сохраняя локальные проверки
func _start_protection_without_remote() -> void:
	protector.enable_anti_tamper = false
	protector.start_protection()


## Блокирует запуск при успешно загруженном, но некорректном манифесте
func _reject_remote_manifest(message: String) -> void:
	push_error(message)
	get_tree().quit(1)


## Обработчик обнаружения отладчика
func _on_debugger_detected(reason: String) -> void:
	print('Debugger detected: ', reason)


## Обработчик обнаружения перехватчика
func _on_hook_detected(reason: String) -> void:
	print('Hook detected: ', reason)


## Обработчик обнаружения изменения файлов
func _on_tampering_detected(reason: String) -> void:
	print('Tampering detected: ', reason)


func save_data() -> String:
	_print_log()
	print('Создание сохранения...')
	
	var save_name = 'vow' + tools.get_project_version() + '_number' + str(len(get_saves())) + '.save'
	
	var icon = window_tools.take_screenshot()
	var screen_size = DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	icon.resize(round(screen_size.x / 3), round(screen_size.y / 3), Image.INTERPOLATE_CUBIC)
	
	var data = {
		'godo_combat': await GCombat.get_save(),
		'godo_mini_game': await GminiGame.get_save(),
		'godo_visual_novel': await GVisualNovel.get_save(),
		'audio_server': audio_server.get_save(),
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
	
	var file = FileAccess.open((SAVE_PATH + save_name).replace('"', ''), FileAccess.WRITE)
	if file == null:
		push_error("[Core] Не удалось создать файл сохранения: %s" % save_name)
		_end_log()
		return ""
	
	file.store_var(data)
	file.close()
	
	print('Сохранение записано.')
	
	_end_log()
	return save_name


func get_saves(): ##Возращает список файлов(Array[String]), если такая папка существует
	var dir = DirAccess.open(SAVE_PATH)
	
	if dir == null:
		_print_log()
		print("Не удалось открыть папку")
		_end_log()
		return
	
	return dir.get_files()


func get_save(save_name: String) -> Dictionary:
	_print_log()
	print('Чтение сохранения...')
	var file = FileAccess.open(SAVE_PATH + save_name, FileAccess.READ)
	if file == null:
		push_error("[Core] Не удалось открыть сохранение для чтения: %s" % save_name)
		_end_log()
		return {}
	
	var raw_data: Variant = file.get_var()
	file.close()
	if not raw_data is Dictionary:
		push_error("[Core] Файл сохранения повреждён или пуст: %s" % save_name)
		_end_log()
		return {}
	
	var data: Dictionary = raw_data
	if not data.has('icon_data'):
		push_error("[Core] В сохранении отсутствуют данные иконки: %s" % save_name)
		_end_log()
		return {}
	
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


func load_save(_save: Dictionary) -> void:
	_print_log()
	
	print('Загрузка сохранения...')
	await GCombat.load_save(_save['godo_combat'])
	if _save.has('godo_mini_game'):
		await GminiGame.load_save(_save['godo_mini_game'])
	await GVisualNovel.load_save(_save['godo_visual_novel'])
	if _save.has('audio_server') and _save['audio_server'] is Dictionary:
		audio_server.load_save(_save['audio_server'])
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


func push_fatal_error(message: String = 'Фатальная ошибка') -> void:
	print(message)
	push_error(message)
	await get_tree().process_frame
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
