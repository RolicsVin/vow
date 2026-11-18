@tool
extends EditorExportPlugin
## Синхронно обфусцирует локальные идентификаторы GDScript при экспорте

const OBFUSCATOR_PATH: String = "res://core/py/obfuscate.py"
const TEMP_DIRECTORY: String = "user://export_to_obfuscate"

var _python_executable: String = ""


func _get_name() -> String:
	return "ExportToObfuscate"


func _supports_platform(_platform: EditorExportPlatform) -> bool:
	return true


func _export_begin(
	_features: PackedStringArray,
	_is_debug: bool,
	_path: String,
	_flags: int
) -> void:
	_python_executable = _find_python_executable()
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIRECTORY)
	)

	if _python_executable.is_empty():
		push_warning(
			"[ExportToObfuscate] Python не найден. GDScript останется без обфускации."
		)


func _export_file(path: String, type: String, _features: PackedStringArray) -> void:
	if type != "GDScript" or not path.ends_with(".gd"):
		return

	if _python_executable.is_empty():
		return

	var original_code: String = FileAccess.get_file_as_string(path)
	if original_code.is_empty():
		return

	var obfuscated_code: String = _obfuscate(original_code, path)
	if obfuscated_code.is_empty():
		return

	# Подменяем исходный файл только после успешной обработки
	skip()
	add_file(path, obfuscated_code.to_utf8_buffer(), false)


func _export_end() -> void:
	_python_executable = ""


func _find_python_executable() -> String:
	# Сначала используем явно заданный интерпретатор Python Bridge
	var custom_interpreter: String = str(
		ProjectSettings.get_setting("python_bridge/editor_interpreter", "")
	)
	if not custom_interpreter.is_empty():
		return custom_interpreter

	# На Windows используем поставляемый вместе с Python Bridge интерпретатор
	if OS.get_name() == "Windows":
		var bundled_python: String = ProjectSettings.globalize_path(
			"res://addons/python_bridge/runtime/windows/python.exe"
		)
		if FileAccess.file_exists(bundled_python):
			return bundled_python
		return "python"

	# На Linux и macOS используем системный Python 3
	return "python3"


func _obfuscate(code: String, source_path: String) -> String:
	var file_suffix: String = str(Time.get_ticks_usec())
	var input_path: String = TEMP_DIRECTORY.path_join("input_%s.gd" % file_suffix)
	var output_path: String = TEMP_DIRECTORY.path_join("output_%s.gd" % file_suffix)
	var absolute_input: String = ProjectSettings.globalize_path(input_path)
	var absolute_output: String = ProjectSettings.globalize_path(output_path)

	var input_file: FileAccess = FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		push_warning(
			"[ExportToObfuscate] Не удалось создать временный файл для '%s'" % source_path
		)
		return ""

	input_file.store_string(code)
	input_file.close()

	var process_output: Array = []
	var exit_code: int = OS.execute(
		_python_executable,
		PackedStringArray([
			"-B",
			ProjectSettings.globalize_path(OBFUSCATOR_PATH),
			"--input",
			absolute_input,
			"--output",
			absolute_output
		]),
		process_output,
		true
	)

	var result: String = ""
	if exit_code == 0 and FileAccess.file_exists(output_path):
		result = FileAccess.get_file_as_string(output_path)
	else:
		var details: String = str(process_output)
		push_warning(
			"[ExportToObfuscate] Не удалось обработать '%s' (код %d): %s"
			% [source_path, exit_code, details]
		)

	# Удаляем временные файлы независимо от результата
	DirAccess.remove_absolute(absolute_input)
	if FileAccess.file_exists(output_path):
		DirAccess.remove_absolute(absolute_output)

	return result
