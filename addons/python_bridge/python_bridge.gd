extends Node
## Autoload singleton "PythonBridge".
##
## Синхронное использование:
##   var response: Dictionary = PythonBridge.call_function("my_module", "add", [1, 2])
##   if response.ok: print(response.result) else: push_error(response.error)
##
## Response: { ok: bool, result: Variant, error: String, traceback: String }
## JSON parser Godot возвращает числа как float — при необходимости используйте int().

signal python_ready(info: Dictionary)
signal python_log(level: String, text: String)
signal python_exited()

const SETTING_SCRIPTS_DIR: String = "python_bridge/scripts_dir" ## Настройка каталога Python-скриптов
const SETTING_AUTO_START: String = "python_bridge/auto_start" ## Настройка автоматического запуска
const ADDON_DIR: String = "res://addons/python_bridge" ## Каталог аддона
const WORKER_RES: String = ADDON_DIR + "/py/bridge_worker.py" ## Путь к Python-обработчику
const SYNC_ROOT: String = "user://python_bridge" ## Каталог копирования файлов при экспорте
const START_TIMEOUT_MS: int = 30000 ## Тайм-аут запуска Python в миллисекундах
const REQUEST_TIMEOUT_MS: int = 300000 ## Тайм-аут выполнения запроса в миллисекундах
const POLL_DELAY_MS: int = 1 ## Задержка между проверками ответа

const BackendBase = preload("res://addons/python_bridge/backends/backend_base.gd")
const BackendDesktop = preload("res://addons/python_bridge/backends/backend_desktop.gd")
const BackendAndroid = preload("res://addons/python_bridge/backends/backend_android.gd")

var is_running: bool = false ## Запущен ли Python-процесс
var is_python_ready: bool = false ## Завершилась ли инициализация Python

var _backend: BackendBase ## Активный платформенный backend
var _pending: Dictionary = {} ## Запросы, ожидающие ответа Python
var _next_id: int = 1 ## Идентификатор следующего запроса


## Инициализирует аддон и при необходимости запускает Python
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ProjectSettings.get_setting(SETTING_AUTO_START, true):
		start()


## Обрабатывает сообщения, когда синхронный вызов не выполняется
func _process(_delta: float) -> void:
	if _backend != null:
		_backend.process()


## Завершает работу Python при удалении синглтона
func _exit_tree() -> void:
	stop()


## Запускает Python-процесс
func start() -> bool:
	if is_running:
		return true
	var dirs: Dictionary = _prepare_scripts()
	_backend = BackendAndroid.new() if OS.get_name() == "Android" else BackendDesktop.new()
	_backend.message_received.connect(_on_message)
	_backend.exited.connect(_on_backend_exited)
	if not _backend.start(dirs["worker_dir"], dirs["script_dirs"]):
		_backend = null
		return false
	is_running = true
	return true


## Останавливает Python-процесс и завершает ожидающие запросы
func stop() -> void:
	if _backend == null:
		return
	_backend.message_received.disconnect(_on_message)
	_backend.exited.disconnect(_on_backend_exited)
	_backend.stop()
	_backend = null
	is_running = false
	is_python_ready = false
	_fail_pending("Python bridge stopped")


## Синхронно ожидает готовности Python, обрабатывая входящие сообщения
func wait_until_ready() -> bool:
	if not is_running and not start():
		return false
	var started: int = Time.get_ticks_msec()
	while is_running and not is_python_ready:
		_backend.process()
		if Time.get_ticks_msec() - started >= START_TIMEOUT_MS:
			push_error("[PythonBridge] Python startup timed out")
			return false
		OS.delay_msec(POLL_DELAY_MS)
	return is_python_ready


## Вызывает функцию Python и возвращает результат без await
func call_function(
	module: String,
	function: String,
	args: Array = [],
	kwargs: Dictionary = {}
) -> Dictionary:
	return _request({
		"op": "call",
		"module": module,
		"function": function,
		"args": args,
		"kwargs": kwargs,
	})


## Перезагружает Python-модуль без await
func reload_module(module: String) -> Dictionary:
	return _request({"op": "reload", "module": module})


## Проверяет соединение с Python без await
func ping() -> Dictionary:
	return _request({"op": "ping"})


## Отправляет запрос и синхронно ожидает ответ
func _request(message: Dictionary) -> Dictionary:
	if not is_running and not start():
		return _error("Failed to start Python bridge")
	if not wait_until_ready():
		return _error("Python bridge did not become ready")

	var request_id: int = _next_id
	_next_id += 1
	message["id"] = request_id
	_pending[request_id] = {"completed": false, "response": {}}
	_backend.send(message)

	var started: int = Time.get_ticks_msec()
	while _pending.has(request_id):
		_backend.process()
		if not _pending.has(request_id):
			break
		var pending: Dictionary = _pending[request_id]
		if pending["completed"]:
			_pending.erase(request_id)
			return pending["response"]
		if Time.get_ticks_msec() - started >= REQUEST_TIMEOUT_MS:
			_pending.erase(request_id)
			return _error("Python request timed out")
		OS.delay_msec(POLL_DELAY_MS)

	return _error("Python process exited before responding")


## Принимает сообщения от backend и сопоставляет ответы с запросами
func _on_message(message: Dictionary) -> void:
	match str(message.get("type", "")):
		"response":
			var request_id: int = int(message.get("id", -1))
			if not _pending.has(request_id):
				return
			var response: Dictionary = {
				"ok": bool(message.get("ok", false)),
				"result": message.get("result"),
				"error": str(message.get("error", "")),
				"traceback": str(message.get("traceback", "")),
			}
			var pending: Dictionary = _pending[request_id]
			pending["response"] = response
			pending["completed"] = true
		"log":
			python_log.emit(
				str(message.get("level", "stdout")),
				str(message.get("text", ""))
			)
		"ready":
			is_python_ready = true
			python_ready.emit(message)
		"fatal":
			push_error("[PythonBridge] %s" % str(message.get("error", "unknown error")))
			python_log.emit("stderr", str(message.get("error", "")))


## Обрабатывает завершение Python-процесса
func _on_backend_exited() -> void:
	is_running = false
	is_python_ready = false
	_fail_pending("Python process exited")
	python_exited.emit()


## Завершает все запросы с ошибкой
func _fail_pending(reason: String) -> void:
	for request_id: int in _pending:
		var pending: Dictionary = _pending[request_id]
		pending["response"] = _error(reason)
		pending["completed"] = true


## Формирует стандартный ответ с ошибкой
func _error(message: String) -> Dictionary:
	return {"ok": false, "result": null, "error": message, "traceback": ""}


## Возвращает абсолютные пути к worker и каталогам скриптов
func _prepare_scripts() -> Dictionary:
	var scripts_res: String = ProjectSettings.get_setting(SETTING_SCRIPTS_DIR, "res://py")
	if OS.has_feature("editor"):
		return {
			"worker_dir": ProjectSettings.globalize_path(WORKER_RES.get_base_dir()),
			"script_dirs": PackedStringArray([ProjectSettings.globalize_path(scripts_res)]),
		}

	var worker_dst: String = SYNC_ROOT.path_join("worker")
	var scripts_dst: String = SYNC_ROOT.path_join("scripts")
	DirAccess.make_dir_recursive_absolute(worker_dst)
	_sync_file(WORKER_RES, worker_dst.path_join("bridge_worker.py"))
	_sync_dir(scripts_res, scripts_dst)
	return {
		"worker_dir": ProjectSettings.globalize_path(worker_dst),
		"script_dirs": PackedStringArray([ProjectSettings.globalize_path(scripts_dst)]),
	}


## Копирует Python-файлы из каталога проекта в пользовательский каталог
func _sync_dir(source: String, destination: String) -> void:
	DirAccess.make_dir_recursive_absolute(destination)
	for file_name: String in DirAccess.get_files_at(source):
		_sync_file(source.path_join(file_name), destination.path_join(file_name))
	for directory_name: String in DirAccess.get_directories_at(source):
		if directory_name != "__pycache__":
			_sync_dir(source.path_join(directory_name), destination.path_join(directory_name))


## Копирует файл, только если его содержимое изменилось
func _sync_file(source: String, destination: String) -> void:
	var data: PackedByteArray = FileAccess.get_file_as_bytes(source)
	if FileAccess.file_exists(destination) and FileAccess.get_file_as_bytes(destination) == data:
		return
	var file: FileAccess = FileAccess.open(destination, FileAccess.WRITE)
	if file == null:
		push_error(
			"[PythonBridge] Cannot write %s (error %d)" % [destination, FileAccess.get_open_error()]
		)
		return
	file.store_buffer(data)
