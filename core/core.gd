## Ядро игры. 
## Объединяет игровые модули. 
## Защищает игру. 
extends Node

## Прямая ссылка на общий манифест (список манифестов всех ваших игр).
const GENERAL_MANIFEST_URL: String = "https://drive.google.com/file/d/19GdjIRYv0pmPzWMF26nqgsgplxF79k3T/view?usp=drive_link"

const GAME_MANIFEST_KEY: String = "vow_manifest" ## Ключ этой игры в общем манифесте.

const SAVE_PATH: String = 'user://'


var _buffer: Dictionary = {} ## Общий буффер дял всей игры

var audio_server: AudioServerManager = AudioServerManager.new()

var protector: RuntimeProtector ## Защита

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
	print('')

func _ready() -> void:
	_print_log()
	print('Стартовало ядро игры')
	
	print('Создание протектора...')
	protector = RuntimeProtector.new()
	add_child(protector)
	print('Протектор создан.')
	
	print('Настройка протектора.')
	protector.debugger_detected.connect(_on_debugger_detected)
	#protector.debugger_detected.connect(push_fatal_error)
	
	protector.hook_detected.connect(_on_hook_detected)
	#protector.hook_detected.connect(push_fatal_error)
	
	protector.tampering_detected.connect(_on_tampering_detected)
	#protector.tampering_detected.connect(push_fatal_error)
	
	if not protector.self_test_sha256():
		push_error("RuntimeProtector: SHA-256 self-test failed — do not trust hash checks!")
	
	protector.check_interval_ms = 2000
	protector.enable_anti_debug = true
	protector.enable_anti_hook = true
	
	# Anti-tamper is opt-in: you need the real hash of your shipped .pck.
	# Compute it once at build time (e.g. with sha256sum) and bake it in —
	# ideally not as one obvious plain string literal; split/obfuscate it
	# at the very least, since this is just a string an attacker can read
	# out of the binary otherwise.
	if OS.has_feature("template"):
		protector.pck_path = OS.get_executable_path().get_base_dir().path_join("vow.pck")
		_fetch_expected_hashes()
	else:
		print('Обнаружена работа в редакторе: enable_anti_tamper = false')
		protector.enable_anti_tamper = false  # играем из редактора — проверять нечего
	
	# 0 = signal only (recommended to start with), 1 = quit, 2 = crash
	protector.reaction_mode = RuntimeProtector.REACTION_CRASH
	protector.start_protection()
	
	print('Протектор настроен.')
	_end_log()


func _fetch_expected_hashes() -> void:
	var path: String = await _resolve_manifest_url(GENERAL_MANIFEST_URL)
	if path.is_empty():
		push_warning("[Core] Не удалось разрешить ссылку на общий манифест. Анти-тампер отключён.")
		return

	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_general_manifest_completed.bind(http))
	var err := http.request(path)
	if err != OK:
		push_warning("[Core] Не удалось запросить общий манифест (код %d). Анти-тампер отключён." % err)
		http.queue_free()


func _on_general_manifest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[Core] Общий манифест недоступен (result=%d, code=%d). Анти-тампер отключён." % [result, response_code])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not parsed.has(GAME_MANIFEST_KEY):
		push_warning("[Core] В общем манифесте нет ключа '%s'. Анти-тампер отключён." % GAME_MANIFEST_KEY)
		return

	var game_manifest_url: String = await _resolve_manifest_url(parsed[GAME_MANIFEST_KEY])
	if game_manifest_url.is_empty():
		push_warning("[Core] Значение ключа '%s' в общем манифесте пустое или некорректное. Анти-тампер отключён." % GAME_MANIFEST_KEY)
		return

	var game_http := HTTPRequest.new()
	add_child(game_http)
	game_http.request_completed.connect(_on_game_manifest_completed.bind(game_http))
	var err := game_http.request(game_manifest_url)
	if err != OK:
		push_warning("[Core] Не удалось запросить манифест игры (код %d). Анти-тампер отключён." % err)
		game_http.queue_free()


## Прогоняет значение (ссылку на Google Диск) через Python-хелпер
## drive_direct_url, который сам разбирает и /file/d/<ID>/view, и ?id=<ID>.
func _resolve_manifest_url(value) -> String:
	if not (value is String) or value.is_empty():
		return ""

	var response: Dictionary = await PythonBridge.call_function('tools', 'drive_direct_url', [value])
	if not response.get("ok", false):
		push_warning("[Core] drive_direct_url не смог разобрать ссылку '%s': %s" % [value, response.get("error", "unknown error")])
		return ""

	return str(response.get("result", ""))


func _on_game_manifest_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[Core] Манифест игры недоступен (result=%d, code=%d). Анти-тампер отключён." % [result, response_code])
		return

	var parsed = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary:
		push_warning("[Core] Манифест игры повреждён или не является объектом. Анти-тампер отключён.")
		return

	var pck_hash: String = str(parsed.get("pck_cache", ""))
	var exe_hash: String = str(parsed.get("exe_cache", ""))

	var any_enabled := false

	if _is_valid_sha256(pck_hash):
		protector.expected_pck_hash = pck_hash
		any_enabled = true
	else:
		push_warning("[Core] pck_cache в манифесте отсутствует или некорректен — проверка .pck пропущена.")

	if _is_valid_sha256(exe_hash):
		protector.expected_exe_hash = exe_hash
		any_enabled = true
	else:
		push_warning("[Core] exe_cache в манифесте отсутствует или некорректен — проверка .exe пропущена.")

	protector.enable_anti_tamper = any_enabled


func _is_valid_sha256(text: String) -> bool:
	var regex := RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	return regex.search(text) != null


func _on_pck_hash_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest) -> void:
	http.queue_free()
	
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("[Core] Сервер хэшей недоступен (result=%d, code=%d). Анти-тампер отключён на эту сессию." % [result, response_code])
		return
	
	var text := body.get_string_from_utf8().strip_edges()
	
	# Защита от мусора: если Google Диск вдруг вернул HTML-страницу
	# (например, из-за смены политики ссылок), а не чистый хэш —
	# не включаем проверку с заведомо неверным значением.
	var regex := RegEx.new()
	regex.compile("^[0-9a-f]{64}$")
	if not regex.search(text):
		push_warning("[Core] Полученный ответ не похож на валидный SHA-256 (%d симв.). Анти-тампер отключён." % text.length())
		return
	
	protector.expected_pck_hash = text
	protector.enable_anti_tamper = true


func _on_debugger_detected(reason: String) -> void:
	print("Debugger detected: ", reason)
	# Your call: degrade silently, corrupt save state, flag the session
	# server-side, etc. An instant, obvious crash is the easiest pattern
	# to find and patch out.


func _on_hook_detected(reason: String) -> void:
	print("Hook detected: ", reason)


func _on_tampering_detected(reason: String) -> void:
	print("Tampering detected: ", reason)


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
