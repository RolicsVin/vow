extends "res://addons/python_bridge/backends/backend_base.gd"
## Android backend: talks to the "PythonBridgeAndroid" Godot Android plugin
## (android/PythonBridgePlugin.java), which runs Python in-process via Chaquopy.
## Output is polled once per frame, so no threads / signals cross the JNI border.

const SINGLETON := "PythonBridgeAndroid"

var _plugin: Object = null


func start(worker_dir: String, script_dirs: PackedStringArray) -> bool:
	if not Engine.has_singleton(SINGLETON):
		push_error("[PythonBridge] Android plugin '%s' not found. Use a Gradle build and follow README (Android section)." % SINGLETON)
		return false
	_plugin = Engine.get_singleton(SINGLETON)
	return _plugin.start(worker_dir, "\n".join(script_dirs))


func send(msg: Dictionary) -> void:
	if _plugin != null:
		_plugin.send(JSON.stringify(msg))


func process() -> void:
	if _plugin == null:
		return
	var chunk: String = _plugin.poll()
	if chunk.is_empty():
		return
	for line in chunk.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			message_received.emit(parsed)


func stop() -> void:
	if _plugin != null:
		_plugin.shutdown()
		_plugin = null
