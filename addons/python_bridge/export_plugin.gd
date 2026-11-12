@tool
extends EditorExportPlugin
## - puts the Python scripts + worker into the .pck (all platforms)
## - Windows: copies runtime/windows next to the exported .exe as "python_runtime/"
## - Android: copies the Java plugin into the Gradle project and registers it in the manifest

const ADDON_DIR := "res://addons/python_bridge"
const WORKER_RES := ADDON_DIR + "/py/bridge_worker.py"
const ANDROID_JAVA_SRC := ADDON_DIR + "/android/PythonBridgePlugin.java"
const ANDROID_JAVA_DST := "res://android/build/src/main/java/io/github/pythonbridge/PythonBridgePlugin.java"
const ANDROID_PLUGIN_NAME := "PythonBridgeAndroid"
const ANDROID_PLUGIN_CLASS := "io.github.pythonbridge.PythonBridgePlugin"

var _export_path := ""
var _is_windows := false


func _get_name() -> String:
	return "PythonBridgeExport"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(features: PackedStringArray, _is_debug: bool, path: String, _flags: int) -> void:
	_export_path = path
	_is_windows = features.has("windows")

	add_file(WORKER_RES, FileAccess.get_file_as_bytes(WORKER_RES), false)
	var scripts_dir: String = ProjectSettings.get_setting("python_bridge/scripts_dir", "res://py")
	_add_dir(scripts_dir)

	if features.has("android"):
		_prepare_android()


func _export_end() -> void:
	if _is_windows and not _export_path.is_empty():
		_copy_windows_runtime()
	_is_windows = false
	_export_path = ""


func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	return '<meta-data android:name="org.godotengine.plugin.v2.%s" android:value="%s"/>' % [ANDROID_PLUGIN_NAME, ANDROID_PLUGIN_CLASS]


# --- helpers ---------------------------------------------------------------

func _add_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "pyc":
			continue
		var path := dir.path_join(file)
		add_file(path, FileAccess.get_file_as_bytes(path), false)
	for sub in DirAccess.get_directories_at(dir):
		if sub != "__pycache__":
			_add_dir(dir.path_join(sub))


func _copy_windows_runtime() -> void:
	var src := ProjectSettings.globalize_path(ADDON_DIR + "/runtime/windows")
	if not FileAccess.file_exists(src.path_join("python.exe")):
		push_error("[PythonBridge] runtime/windows/python.exe is missing - the exported game will not find Python. Run addons/python_bridge/tools/setup_windows_runtime.py")
		return
	var dst := _export_path.get_base_dir().path_join("python_runtime")
	var count := _copy_dir(src, dst)
	print("[PythonBridge] Copied %d runtime files to %s" % [count, dst])


func _copy_dir(src: String, dst: String) -> int:
	DirAccess.make_dir_recursive_absolute(dst)
	var count := 0
	for file in DirAccess.get_files_at(src):
		var err := DirAccess.copy_absolute(src.path_join(file), dst.path_join(file))
		if err == OK:
			count += 1
		else:
			push_error("[PythonBridge] Copy failed (%d): %s" % [err, src.path_join(file)])
	for sub in DirAccess.get_directories_at(src):
		if sub != "__pycache__":
			count += _copy_dir(src.path_join(sub), dst.path_join(sub))
	return count


func _prepare_android() -> void:
	var preset := get_export_preset()
	if preset != null and not bool(preset.get("gradle_build/use_gradle_build")):
		push_error("[PythonBridge] Android needs 'Use Gradle Build' enabled in the export preset (plus Chaquopy, see README).")
		return
	if not DirAccess.dir_exists_absolute("res://android/build"):
		push_error("[PythonBridge] res://android/build not found - run Project > Install Android Build Template.")
		return
	var data := FileAccess.get_file_as_bytes(ANDROID_JAVA_SRC)
	if FileAccess.file_exists(ANDROID_JAVA_DST) and FileAccess.get_file_as_bytes(ANDROID_JAVA_DST) == data:
		return
	DirAccess.make_dir_recursive_absolute(ANDROID_JAVA_DST.get_base_dir())
	var f := FileAccess.open(ANDROID_JAVA_DST, FileAccess.WRITE)
	if f == null:
		push_error("[PythonBridge] Cannot write " + ANDROID_JAVA_DST)
		return
	f.store_buffer(data)
	print("[PythonBridge] Installed Java plugin into the Android build template.")
