extends "res://addons/python_bridge/backends/backend_base.gd"
## Настольный backend запускает bridge_worker.py отдельным процессом
## и обменивается с ним JSON-сообщениями через stdin/stdout

const RUNTIME_DIR_NAME := "python_runtime" # Папка встроенного Python рядом с exe

var _pipe: FileAccess ## Канал stdin/stdout Python-процесса
var _err_pipe: FileAccess ## Канал stderr Python-процесса
var _pid: int = -1 ## Идентификатор Python-процесса
var _stdout_thread: Thread ## Поток чтения stdout
var _stderr_thread: Thread ## Поток чтения stderr
var _stopping: bool = false ## Флаг остановки потоков чтения
var _messages: Array[Dictionary] = [] ## Очередь сообщений для основного потока # Очередь сообщений от потоков чтения
var _messages_mutex: Mutex = Mutex.new() ## Блокировка доступа к очереди сообщений
var _exit_received: bool = false ## Получен ли сигнал завершения процесса


## Запускает отдельный процесс Python и потоки чтения его вывода
func start(worker_dir: String, script_dirs: PackedStringArray) -> bool:
	var exe: String = _find_interpreter()
	var args: PackedStringArray = PackedStringArray(["-X", "utf8", "-u"])
	if OS.has_feature("editor"):
		args.append("-B")
	args.append(worker_dir.path_join("bridge_worker.py"))
	for directory: String in script_dirs:
		args.append("--path")
		args.append(directory)

	var info: Dictionary = OS.execute_with_pipe(exe, args)
	if info.is_empty():
		push_error("[PythonBridge] Failed to start interpreter: %s" % exe)
		return false

	_pipe = info["stdio"]
	_err_pipe = info["stderr"]
	_pid = info["pid"]
	_stopping = false
	_exit_received = false
	_messages_mutex.lock()
	_messages.clear()
	_messages_mutex.unlock()

	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_loop.bind(_pipe, false))
	_stderr_thread = Thread.new()
	_stderr_thread.start(_read_loop.bind(_err_pipe, true))
	return true


## Отправляет запрос в Python
func send(msg: Dictionary) -> void:
	if _pid < 0 or _pipe == null:
		return
	_pipe.store_line(JSON.stringify(msg))
	_pipe.flush()


## Передаёт накопленные сообщения в основной поток Godot
func process() -> void:
	var messages: Array[Dictionary] = []
	var has_exited: bool = false

	_messages_mutex.lock()
	messages = _messages.duplicate()
	_messages.clear()
	has_exited = _exit_received
	_exit_received = false
	_messages_mutex.unlock()

	for message: Dictionary in messages:
		message_received.emit(message)
	if has_exited:
		exited.emit()


## Останавливает Python и дожидается завершения потоков чтения
func stop() -> void:
	if _pid < 0:
		return
	_stopping = true
	send({"op": "shutdown", "id": 0})
	var started: int = Time.get_ticks_msec()
	while OS.is_process_running(_pid) and Time.get_ticks_msec() - started < 500:
		OS.delay_msec(10)
	if OS.is_process_running(_pid):
		OS.kill(_pid)
	_stdout_thread.wait_to_finish()
	_stderr_thread.wait_to_finish()
	_pid = -1
	_pipe = null
	_err_pipe = null


## Читает stdout или stderr процесса в отдельном потоке
func _read_loop(pipe: FileAccess, is_stderr: bool) -> void:
	while not _stopping:
		var line: String = pipe.get_line()
		if line.is_empty():
			if not OS.is_process_running(_pid):
				break
			OS.delay_msec(5)
			continue
		if is_stderr:
			_enqueue({"type": "log", "level": "stderr", "text": line})
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			_enqueue(parsed)
		else:
			_enqueue({"type": "log", "level": "stdout", "text": line})
	if not is_stderr and not _stopping:
		_messages_mutex.lock()
		_exit_received = true
		_messages_mutex.unlock()


## Безопасно добавляет сообщение в очередь из рабочего потока
func _enqueue(message: Dictionary) -> void:
	_messages_mutex.lock()
	_messages.append(message)
	_messages_mutex.unlock()


## Находит доступный интерпретатор Python
func _find_interpreter() -> String:
	var is_windows: bool = OS.get_name() == "Windows"
	if OS.has_feature("editor"):
		var custom: String = ProjectSettings.get_setting("python_bridge/editor_interpreter", "")
		if not custom.is_empty():
			return custom
		if is_windows:
			var bundled: String = ProjectSettings.globalize_path(
				"res://addons/python_bridge/runtime/windows/python.exe"
			)
			if FileAccess.file_exists(bundled):
				return bundled
	elif is_windows:
		var shipped: String = OS.get_executable_path().get_base_dir().path_join(
			RUNTIME_DIR_NAME
		).path_join("python.exe")
		if FileAccess.file_exists(shipped):
			return shipped
		push_warning("[PythonBridge] %s not found - falling back to Python from PATH." % shipped)
	return "python" if is_windows else "python3"
