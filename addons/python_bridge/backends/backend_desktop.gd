extends "res://addons/python_bridge/backends/backend_base.gd"
## Desktop backend: runs bridge_worker.py as a child process and talks to it
## through JSON lines over stdin/stdout. Requires Godot 4.4+ (OS.execute_with_pipe).

const RUNTIME_DIR_NAME := "python_runtime"  # next to the exported exe (see export_plugin.gd)

var _pipe: FileAccess
var _err_pipe: FileAccess
var _pid := -1
var _stdout_thread: Thread
var _stderr_thread: Thread
var _stopping := false


func start(worker_dir: String, script_dirs: PackedStringArray) -> bool:
	var exe := _find_interpreter()
	var args := PackedStringArray(["-X", "utf8", "-u"])
	if OS.has_feature("editor"):
		args.append("-B")  # don't litter res:// with __pycache__
	args.append(worker_dir.path_join("bridge_worker.py"))
	for d in script_dirs:
		args.append("--path")
		args.append(d)

	var info := OS.execute_with_pipe(exe, args)
	if info.is_empty():
		push_error("[PythonBridge] Failed to start interpreter: %s" % exe)
		return false

	_pipe = info["stdio"]
	_err_pipe = info["stderr"]
	_pid = info["pid"]
	_stopping = false
	_stdout_thread = Thread.new()
	_stdout_thread.start(_read_loop.bind(_pipe, false))
	_stderr_thread = Thread.new()
	_stderr_thread.start(_read_loop.bind(_err_pipe, true))
	return true


func send(msg: Dictionary) -> void:
	if _pid < 0 or _pipe == null:
		return
	_pipe.store_line(JSON.stringify(msg))
	_pipe.flush()


func stop() -> void:
	if _pid < 0:
		return
	_stopping = true
	send({"op": "shutdown", "id": 0})
	var started := Time.get_ticks_msec()
	while OS.is_process_running(_pid) and Time.get_ticks_msec() - started < 500:
		OS.delay_msec(10)
	if OS.is_process_running(_pid):
		OS.kill(_pid)
	# Process is gone -> pipes hit EOF -> reader threads leave their loops.
	_stdout_thread.wait_to_finish()
	_stderr_thread.wait_to_finish()
	_pid = -1
	_pipe = null
	_err_pipe = null


# --- worker threads --------------------------------------------------------

func _read_loop(pipe: FileAccess, is_stderr: bool) -> void:
	while not _stopping:
		var line := pipe.get_line()  # blocks until a line arrives or EOF
		if line.is_empty():
			if not OS.is_process_running(_pid):
				break
			OS.delay_msec(5)
			continue
		if is_stderr:
			_deliver.call_deferred({"type": "log", "level": "stderr", "text": line})
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			_deliver.call_deferred(parsed)
		else:  # something printed straight to the pipe, not a protocol message
			_deliver.call_deferred({"type": "log", "level": "stdout", "text": line})
	if not is_stderr and not _stopping:
		_notify_exit.call_deferred()


func _deliver(msg: Dictionary) -> void:
	message_received.emit(msg)


func _notify_exit() -> void:
	exited.emit()


# --- interpreter lookup ----------------------------------------------------

func _find_interpreter() -> String:
	var is_windows := OS.get_name() == "Windows"
	if OS.has_feature("editor"):
		var custom: String = ProjectSettings.get_setting("python_bridge/editor_interpreter", "")
		if not custom.is_empty():
			return custom
		if is_windows:
			var bundled := ProjectSettings.globalize_path("res://addons/python_bridge/runtime/windows/python.exe")
			if FileAccess.file_exists(bundled):
				return bundled
	elif is_windows:
		var shipped := OS.get_executable_path().get_base_dir().path_join(RUNTIME_DIR_NAME).path_join("python.exe")
		if FileAccess.file_exists(shipped):
			return shipped
		push_warning("[PythonBridge] %s not found - falling back to Python from PATH." % shipped)
	# Dev convenience on other desktops / fallback: system Python.
	return "python" if is_windows else "python3"
