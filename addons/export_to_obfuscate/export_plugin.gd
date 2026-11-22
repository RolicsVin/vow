@tool
extends EditorExportPlugin
## Синхронно обфусцирует идентификаторы GDScript при экспорте.
##
## Безопасный режим ("safe") переименовывает только локальные идентификаторы
## внутри функций (параметры, var/const, переменные циклов) — это в точности
## прежнее поведение аддона.
##
## Полный режим ("full") дополнительно переименовывает имена функций,
## переменные класса (в том числе публичные и @export) и сигналы по всему
## проекту согласованно, и обновляет ссылки на них в .tscn/.tres файлах
## (свойства узлов и секции [connection]), чтобы сцены продолжали работать.

const OBFUSCATOR_PATH: String = "res://addons/export_to_obfuscate/py/obfuscate.py"
const TEMP_DIRECTORY: String = "user://export_to_obfuscate"

const SETTING_MODE: String = "export_to_obfuscate/mode"
const SETTING_EXCLUDE_DIRS: String = "export_to_obfuscate/full_mode_exclude_dirs"
const SETTING_RESERVED_NAMES: String = "export_to_obfuscate/full_mode_extra_reserved_names"

const MODE_FULL: String = "full"

var _python_executable: String = ""
var _python_available: bool = false

var _mode: String = "safe"
var _full_map_path: String = ""
var _full_map_ready: bool = false
var _full_mode_exclude_prefixes: PackedStringArray = PackedStringArray()


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

	# Проверяем интерпретатор один раз, чтобы не запускать несуществующий Python
	# для каждого файла
	if not _python_executable.is_empty():
		var version_output: Array = []
		_python_available = OS.execute(
			_python_executable,
			PackedStringArray(["--version"]),
			version_output,
			true
		) == 0

	if not _python_available or not FileAccess.file_exists(OBFUSCATOR_PATH):
		_python_available = false
		push_warning(
			"[ExportToObfuscate] Python или py/obfuscate.py аддона не найдены. "
			+ "GDScript останется без обфускации."
		)
		return

	_mode = str(ProjectSettings.get_setting(SETTING_MODE, "safe"))
	_full_map_path = ""
	_full_map_ready = false
	_full_mode_exclude_prefixes = PackedStringArray()

	if _mode == MODE_FULL:
		# Карта переименований строится только по НЕ исключённым файлам,
		# поэтому глобальное переименование нельзя применять и к файлам из
		# исключённых папок — иначе чужой код (другие аддоны и т.п.), который
		# мы даже не сканировали, может случайно совпасть по имени с
		# переименованным символом проекта и сломаться.
		var exclude_dirs: PackedStringArray = ProjectSettings.get_setting(
			SETTING_EXCLUDE_DIRS, PackedStringArray(["res://addons"])
		)
		for exclude_dir in exclude_dirs:
			_full_mode_exclude_prefixes.append(_normalized_dir_prefix(exclude_dir))

		var map_path: String = TEMP_DIRECTORY.path_join(
			"rename_map_%s.json" % str(Time.get_ticks_usec())
		)
		_full_map_ready = _build_full_mode_map(map_path)
		if _full_map_ready:
			_full_map_path = map_path
		else:
			push_warning(
				"[ExportToObfuscate] Не удалось построить карту переименований "
				+ "для полного режима — будут переименованы только локальные "
				+ "идентификаторы (как в безопасном режиме)."
			)


func _export_file(path: String, type: String, _features: PackedStringArray) -> void:
	if not _python_available:
		return

	if type == "GDScript" and path.ends_with(".gd"):
		_export_script(path)
	elif _mode == MODE_FULL and _full_map_ready and _is_scene_or_resource(path):
		# Сцены/ресурсы из исключённых папок не обрабатываем вовсе — для них
		# нет "безопасного" эквивалента точечной локальной обфускации
		if not _is_excluded_from_full_mode(path):
			_export_scene(path)


## "res://addons" -> "res://addons/" (чтобы не задеть "res://addons_other")
func _normalized_dir_prefix(dir_path: String) -> String:
	var normalized: String = dir_path
	if not normalized.ends_with("/"):
		normalized += "/"
	return normalized


func _is_excluded_from_full_mode(path: String) -> bool:
	for prefix in _full_mode_exclude_prefixes:
		if path.begins_with(prefix):
			return true
	return false


func _export_end() -> void:
	if not _full_map_path.is_empty():
		var absolute_map: String = ProjectSettings.globalize_path(_full_map_path)
		if FileAccess.file_exists(_full_map_path):
			DirAccess.remove_absolute(absolute_map)

	_python_executable = ""
	_python_available = false
	_mode = "safe"
	_full_map_path = ""
	_full_map_ready = false
	_full_mode_exclude_prefixes = PackedStringArray()


func _is_scene_or_resource(path: String) -> bool:
	return path.ends_with(".tscn") or path.ends_with(".tres")


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


func _export_script(path: String) -> void:
	var original_code: String = FileAccess.get_file_as_string(path)
	if original_code.is_empty():
		return

	var script_args: PackedStringArray = PackedStringArray(["--mode", "locals"])
	if _mode == MODE_FULL and _full_map_ready and not _is_excluded_from_full_mode(path):
		script_args = PackedStringArray([
			"--mode", "apply",
			"--map", ProjectSettings.globalize_path(_full_map_path),
		])

	var obfuscated_code: String = _run_file_transform(original_code, path, "gd", script_args)
	if obfuscated_code.is_empty():
		return

	# Подменяем исходный файл только после успешной обработки
	skip()
	add_file(path, obfuscated_code.to_utf8_buffer(), false)


func _export_scene(path: String) -> void:
	var original_text: String = FileAccess.get_file_as_string(path)
	if original_text.is_empty():
		return

	var scene_args: PackedStringArray = PackedStringArray([
		"--mode", "scene",
		"--map", ProjectSettings.globalize_path(_full_map_path),
	])

	var updated_text: String = _run_file_transform(original_text, path, "scene", scene_args)
	if updated_text.is_empty() or updated_text == original_text:
		return

	skip()
	add_file(path, updated_text.to_utf8_buffer(), false)


func _run_file_transform(
	content: String,
	source_path: String,
	suffix: String,
	extra_args: PackedStringArray
) -> String:
	var file_suffix: String = "%s_%s" % [suffix, str(Time.get_ticks_usec())]
	var input_path: String = TEMP_DIRECTORY.path_join("input_%s.tmp" % file_suffix)
	var output_path: String = TEMP_DIRECTORY.path_join("output_%s.tmp" % file_suffix)
	var absolute_input: String = ProjectSettings.globalize_path(input_path)
	var absolute_output: String = ProjectSettings.globalize_path(output_path)

	var input_file: FileAccess = FileAccess.open(input_path, FileAccess.WRITE)
	if input_file == null:
		push_warning(
			"[ExportToObfuscate] Не удалось создать временный файл для '%s'" % source_path
		)
		return ""

	input_file.store_string(content)
	input_file.close()

	var process_args: PackedStringArray = PackedStringArray([
		"-B",
		ProjectSettings.globalize_path(OBFUSCATOR_PATH),
	])
	process_args.append_array(extra_args)
	process_args.append_array(PackedStringArray([
		"--input", absolute_input,
		"--output", absolute_output,
	]))

	var process_output: Array = []
	var exit_code: int = OS.execute(_python_executable, process_args, process_output, true)

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


## Запускает единоразовое сканирование проекта и строит общую карту
## переименований функций/переменных/сигналов для полного режима.
func _build_full_mode_map(map_path: String) -> bool:
	var exclude_dirs: PackedStringArray = ProjectSettings.get_setting(
		SETTING_EXCLUDE_DIRS, PackedStringArray(["res://addons"])
	)
	var reserved_names: PackedStringArray = ProjectSettings.get_setting(
		SETTING_RESERVED_NAMES, PackedStringArray()
	)
	var absolute_map_path: String = ProjectSettings.globalize_path(map_path)

	var scan_args: PackedStringArray = PackedStringArray([
		"-B",
		ProjectSettings.globalize_path(OBFUSCATOR_PATH),
		"--mode", "scan",
		"--project-root", ProjectSettings.globalize_path("res://"),
		"--map-output", absolute_map_path,
	])

	for exclude_dir in exclude_dirs:
		scan_args.append("--exclude")
		scan_args.append(ProjectSettings.globalize_path(exclude_dir))

	for reserved_name in reserved_names:
		scan_args.append("--reserve")
		scan_args.append(reserved_name)

	var process_output: Array = []
	var exit_code: int = OS.execute(_python_executable, scan_args, process_output, true)

	if exit_code != 0 or not FileAccess.file_exists(map_path):
		push_warning(
			"[ExportToObfuscate] Сканирование проекта завершилось с ошибкой (код %d): %s"
			% [exit_code, str(process_output)]
		)
		return false

	_warn_about_risky_names(map_path)
	return true


## Предупреждает в выводе редактора об именах, которые совпадают с частыми
## встроенными свойствами/сигналами Godot — их переименование может задеть
## обращения к несвязанным узлам с таким же именем свойства/сигнала.
func _warn_about_risky_names(map_path: String) -> void:
	var raw_json: String = FileAccess.get_file_as_string(map_path)
	if raw_json.is_empty():
		return

	var parsed: Variant = JSON.parse_string(raw_json)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var risky: Variant = parsed.get("risky", [])
	if typeof(risky) != TYPE_ARRAY or risky.is_empty():
		return

	push_warning(
		(
			"[ExportToObfuscate] Полный режим: следующие имена совпадают с "
			+ "частыми встроенными свойствами/сигналами Godot и будут "
			+ "переименованы ПО ВСЕМУ проекту: %s. Если они используются для "
			+ "обращения к чужим узлам/сигналам с тем же именем, это может "
			+ "сломать такие места — переименуйте их в проекте или добавьте в "
			+ "export_to_obfuscate/full_mode_extra_reserved_names."
		) % ", ".join(risky)
	)
