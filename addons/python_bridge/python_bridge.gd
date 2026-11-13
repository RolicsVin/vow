extends Node
## Autoload singleton "PythonBridge".
##
##   var r = await PythonBridge.call_function("my_module", "add", [1, 2])
##   if r.ok: print(r.result) else: push_error(r.error)
##
## Response dictionary: { ok: bool, result: Variant, error: String, traceback: String }
## NOTE: Godot's JSON parser returns every number as float - use int(r.result) where needed.

signal python_ready(info: Dictionary)
signal python_log(level: String, text: String)  # level: "stdout" | "stderr"
signal python_exited()

const SETTING_SCRIPTS_DIR := "python_bridge/scripts_dir"
const SETTING_AUTO_START := "python_bridge/auto_start"

const ADDON_DIR := "res://addons/python_bridge"
const WORKER_RES := ADDON_DIR + "/py/bridge_worker.py"
const SYNC_ROOT := "user://python_bridge"

const BackendBase := preload("res://addons/python_bridge/backends/backend_base.gd")
const BackendDesktop := preload("res://addons/python_bridge/backends/backend_desktop.gd")
const BackendAndroid := preload("res://addons/python_bridge/backends/backend_android.gd")


class _Pending extends RefCounted:
	signal done(response: Dictionary)


var is_running := false
var is_python_ready := false

var _backend: BackendBase
var _pending: Dictionary = {}
var _next_id := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ProjectSettings.get_setting(SETTING_AUTO_START, true):
		start()


func _process(_delta: float) -> void:
	if _backend != null:
		_backend.process()


func _exit_tree() -> void:
	stop()


# --- public API ------------------------------------------------------------

func start() -> bool:
	if is_running:
		return true
	var dirs := _prepare_scripts()
	_backend = BackendAndroid.new() if OS.get_name() == "Android" else BackendDesktop.new()
	_backend.message_received.connect(_on_message)
	_backend.exited.connect(_on_backend_exited)
	if not _backend.start(dirs["worker_dir"], dirs["script_dirs"]):
		_backend = null
		return false
	is_running = true
	return true


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


func wait_until_ready() -> bool:
	while is_running and not is_python_ready:
		await get_tree().process_frame
	return is_python_ready


## Calls `function` (may be dotted, e.g. "MyClass.method") of `module`.
func call_function(module: String, function: String, args: Array = [], kwargs: Dictionary = {}) -> Dictionary:
	return await _request({"op": "call", "module": module, "function": function, "args": args, "kwargs": kwargs})


## Re-imports a module (handy while developing).
func reload_module(module: String) -> Dictionary:
	return await _request({"op": "reload", "module": module})


func ping() -> Dictionary:
	return await _request({"op": "ping"})


# --- internals -------------------------------------------------------------

func _request(msg: Dictionary) -> Dictionary:
	if not is_running and not start():
		return _error("Failed to start Python bridge")
	
	if not await wait_until_ready():
		return _error("Python bridge did not become ready")
	
	var id := _next_id
	_next_id += 1
	msg["id"] = id
	var pending := _Pending.new()
	_pending[id] = pending
	_backend.send(msg)
	return await pending.done


func _on_message(msg: Dictionary) -> void:
	match str(msg.get("type", "")):
		"response":
			var id := int(msg.get("id", -1))
			var pending: _Pending = _pending.get(id)
			if pending == null:
				return
			_pending.erase(id)
			pending.done.emit({
				"ok": bool(msg.get("ok", false)),
				"result": msg.get("result"),
				"error": str(msg.get("error", "")),
				"traceback": str(msg.get("traceback", "")),
			})
		"log":
			python_log.emit(str(msg.get("level", "stdout")), str(msg.get("text", "")))
		"ready":
			is_python_ready = true
			python_ready.emit(msg)
		"fatal":
			push_error("[PythonBridge] %s" % str(msg.get("error", "unknown error")))
			python_log.emit("stderr", str(msg.get("error", "")))


func _on_backend_exited() -> void:
	is_running = false
	is_python_ready = false
	_fail_pending("Python process exited")
	python_exited.emit()


func _fail_pending(reason: String) -> void:
	var pending := _pending
	_pending = {}
	for id in pending:
		pending[id].done.emit(_error(reason))


func _error(text: String) -> Dictionary:
	return {"ok": false, "result": null, "error": text, "traceback": ""}


## Returns {worker_dir, script_dirs} as absolute filesystem paths.
## Editor: use the project files directly. Exported: Python cannot read the .pck,
## so the files are copied to user:// first.
func _prepare_scripts() -> Dictionary:
	var scripts_res: String = ProjectSettings.get_setting(SETTING_SCRIPTS_DIR, "res://py")
	if OS.has_feature("editor"):
		return {
			"worker_dir": ProjectSettings.globalize_path(WORKER_RES.get_base_dir()),
			"script_dirs": PackedStringArray([ProjectSettings.globalize_path(scripts_res)]),
		}
	var worker_dst := SYNC_ROOT.path_join("worker")
	var scripts_dst := SYNC_ROOT.path_join("scripts")
	DirAccess.make_dir_recursive_absolute(worker_dst)
	_sync_file(WORKER_RES, worker_dst.path_join("bridge_worker.py"))
	_sync_dir(scripts_res, scripts_dst)  # stale files of removed scripts are not deleted
	return {
		"worker_dir": ProjectSettings.globalize_path(worker_dst),
		"script_dirs": PackedStringArray([ProjectSettings.globalize_path(scripts_dst)]),
	}


func _sync_dir(src: String, dst: String) -> void:
	DirAccess.make_dir_recursive_absolute(dst)
	for file in DirAccess.get_files_at(src):
		_sync_file(src.path_join(file), dst.path_join(file))
	for dir in DirAccess.get_directories_at(src):
		if dir != "__pycache__":
			_sync_dir(src.path_join(dir), dst.path_join(dir))


func _sync_file(src: String, dst: String) -> void:
	var data := FileAccess.get_file_as_bytes(src)
	if FileAccess.file_exists(dst) and FileAccess.get_file_as_bytes(dst) == data:
		return
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f == null:
		push_error("[PythonBridge] Cannot write %s (error %d)" % [dst, FileAccess.get_open_error()])
		return
	f.store_buffer(data)
