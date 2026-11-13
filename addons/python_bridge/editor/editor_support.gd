@tool
extends Node
## Makes the Godot editor usable for .py files:
##  * adds "py" to the editor's text-file extensions (FileSystem dock + script editor)
##  * syntax highlighting, spaces-for-indent, auto-indent after ":" in open .py tabs
##  * "New Python script" dialog

const Highlighter := preload("res://addons/python_bridge/editor/python_highlighter.gd")
const EXT_SETTING := "docks/filesystem/textfile_extensions"
const HL_META := "python_bridge_hl"
const PATCHED_META := "python_bridge_patched"
const PREV_LANG_META := "python_bridge_prev_language"
const SCRIPT_DIALOG_CLASS := "ScriptCreateDialog"

var _patched: Array[Dictionary] = []

var _prototype: EditorSyntaxHighlighter


func _ready() -> void:
	_prototype = Highlighter.new()
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_scan_editors)
	add_child(timer)

	if _hook_enabled():
		var dialog_timer := Timer.new()
		dialog_timer.wait_time = 2.0
		dialog_timer.autostart = true
		dialog_timer.timeout.connect(_patch_script_dialogs)
		add_child(dialog_timer)
		_patch_script_dialogs.call_deferred()

	_ensure_py_extension.call_deferred()


func _exit_tree() -> void:
	_unpatch_script_dialogs()


# --- .py as a text file ----------------------------------------------------

func _ensure_py_extension() -> void:
	var settings := EditorInterface.get_editor_settings()
	var exts := String(settings.get_setting(EXT_SETTING)).split(",", false)
	for e in exts:
		if e.strip_edges().to_lower() == "py":
			return
	exts.append("py")
	settings.set_setting(EXT_SETTING, ",".join(exts))
	_ask_restart()


func _ask_restart() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Python Bridge"
	dlg.dialog_text = "Python (.py) files were enabled in the editor.\nGodot has to restart to show them in the FileSystem dock."
	dlg.ok_button_text = "Restart now"
	dlg.cancel_button_text = "Later"
	dlg.confirmed.connect(func(): EditorInterface.restart_editor(true))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered()


# --- highlighting / indentation -------------------------------------------

## ScriptEditorBase doesn't expose the edited file, so .py tabs are found through the
## "open scripts" list on the left of the script editor: every item holds the tab
## index (metadata) and the file name / path (text / tooltip).
func _scan_editors() -> void:
	var script_editor := EditorInterface.get_script_editor()
	var editors := script_editor.get_open_script_editors()
	if editors.is_empty():
		return
	var tabs := editors[0].get_parent() as TabContainer
	if tabs == null:
		return
	for node in script_editor.find_children("*", "ItemList", true, false):
		var list := node as ItemList
		for i in list.item_count:
			var tab_index: Variant = list.get_item_metadata(i)
			if not (tab_index is int) or tab_index < 0 or tab_index >= tabs.get_tab_count():
				continue
			if not _is_python_item(list.get_item_text(i), list.get_item_tooltip(i)):
				continue
			var tab := tabs.get_tab_control(tab_index)
			if tab == null or not tab.has_method("get_base_editor"):
				continue
			_setup_code_edit(tab, tab.get_base_editor() as CodeEdit)


func _is_python_item(text: String, tooltip: String) -> bool:
	if tooltip.get_extension() == "py":
		return true
	return text.strip_edges().trim_suffix("(*)").strip_edges().get_extension() == "py"


func _setup_code_edit(tab: Control, code_edit: CodeEdit) -> void:
	if code_edit == null or not is_instance_valid(code_edit):
		return
	# One highlighter instance per tab, registered in that tab's own highlighter list
	# (exactly what the editor does for its built-in ones), then selected.
	var hl: EditorSyntaxHighlighter = code_edit.get_meta(HL_META, null)
	if hl == null:
		hl = _prototype._create()
		tab.add_syntax_highlighter(hl)
		code_edit.set_meta(HL_META, hl)
	if code_edit.syntax_highlighter != hl:
		code_edit.syntax_highlighter = hl
	# Python: spaces only, 4 wide, indent after a trailing ":"
	code_edit.indent_use_spaces = true
	code_edit.indent_size = 4
	code_edit.indent_automatic = true


# --- "Python" in the Create Script dialog -----------------------------------
## A real ScriptLanguage can only be registered from GDExtension. As a stand-in, the
## FileSystem dock's "Create Script" dialog gets an extra "Python" entry in its
## language list. The dialog's own handler is never called with that entry (it would
## look up a language that doesn't exist): choosing it closes the dialog and opens
## our own "new Python script" dialog in the same folder.

func _hook_enabled() -> bool:
	return bool(ProjectSettings.get_setting("python_bridge/script_dialog_hook", false))


func _patch_script_dialogs() -> void:
	if not _hook_enabled():
		return
	var dock := EditorInterface.get_file_system_dock()
	if dock == null:
		return
	for node in dock.find_children("*", "ConfirmationDialog", true, false):
		if node.get_class() == SCRIPT_DIALOG_CLASS and not node.has_meta(PATCHED_META):
			_patch_script_dialog(node as ConfirmationDialog)


func _patch_script_dialog(dlg: ConfirmationDialog) -> void:
	var lang := _find_language_menu(dlg)
	if lang == null:
		return
	dlg.set_meta(PATCHED_META, true)
	var count := lang.item_count
	var originals: Array = lang.item_selected.get_connections()
	for c in originals:
		lang.item_selected.disconnect(c["callable"])
	lang.add_item("Python")
	lang.set_meta(PREV_LANG_META, maxi(lang.selected, 0))

	var handler := _on_language_selected.bind(dlg, lang, count, originals)
	lang.item_selected.connect(handler)
	var visibility := _on_dialog_visibility.bind(dlg, lang, count)
	dlg.visibility_changed.connect(visibility)
	_patched.append({
		"dlg": dlg, "lang": lang, "count": count, "originals": originals,
		"handler": handler, "visibility": visibility,
	})


func _find_language_menu(dlg: Node) -> OptionButton:
	for node in dlg.find_children("*", "OptionButton", true, false):
		var menu := node as OptionButton
		for i in menu.item_count:
			if menu.get_item_text(i) == "GDScript":
				return menu
	return null


func _on_dialog_visibility(dlg: Window, lang: OptionButton, count: int) -> void:
	if dlg.visible and lang.selected >= 0 and lang.selected < count:
		lang.set_meta(PREV_LANG_META, lang.selected)


func _on_language_selected(index: int, dlg: Window, lang: OptionButton, count: int, originals: Array) -> void:
	if index < count:
		lang.set_meta(PREV_LANG_META, index)
		for c in originals:
			(c["callable"] as Callable).call(index)
		return
	# "Python" was chosen: restore the previous language right away, but close the
	# dialog and open ours on the next idle frame (not from inside the popup's signal).
	lang.select(int(lang.get_meta(PREV_LANG_META, 0)))
	_close_and_create.call_deferred(dlg, _dialog_dir(dlg))


func _close_and_create(dlg: Window, dir: String) -> void:
	if is_instance_valid(dlg):
		dlg.hide()
	show_new_script_in.call_deferred(dir)


## The dialog's path field holds "<folder>/new_script.gd" - take the folder from there.
func _dialog_dir(dlg: Node) -> String:
	for node in dlg.find_children("*", "LineEdit", true, false):
		var text := (node as LineEdit).text
		if text.begins_with("res://") or text.begins_with("user://"):
			return text.get_base_dir() if not text.get_extension().is_empty() else text
	return String(ProjectSettings.get_setting("python_bridge/scripts_dir", "res://py"))


func _unpatch_script_dialogs() -> void:
	for entry in _patched:
		var dlg: Object = entry["dlg"]
		var lang: OptionButton = entry["lang"]
		if is_instance_valid(lang):
			if lang.item_selected.is_connected(entry["handler"]):
				lang.item_selected.disconnect(entry["handler"])
			if lang.selected >= int(entry["count"]):
				lang.select(0)
			if lang.item_count > int(entry["count"]):
				lang.remove_item(lang.item_count - 1)
			for c in entry["originals"]:
				if not lang.item_selected.is_connected(c["callable"]):
					lang.item_selected.connect(c["callable"], c["flags"])
		if is_instance_valid(dlg):
			var window := dlg as Window
			if window.visibility_changed.is_connected(entry["visibility"]):
				window.visibility_changed.disconnect(entry["visibility"])
			dlg.remove_meta(PATCHED_META)
	_patched.clear()


# --- new script ------------------------------------------------------------

func show_new_script_dialog() -> void:
	var scripts_dir: String = ProjectSettings.get_setting("python_bridge/scripts_dir", "res://py")
	DirAccess.make_dir_recursive_absolute(scripts_dir)
	var dlg := EditorFileDialog.new()
	dlg.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	dlg.access = EditorFileDialog.ACCESS_RESOURCES
	dlg.title = "New Python script"
	dlg.add_filter("*.py", "Python script")
	dlg.current_dir = scripts_dir
	dlg.current_file = "new_script.py"
	dlg.file_selected.connect(_create_script)
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())
	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered_ratio(0.6)


## Small "name your script" dialog for a known folder (used by the FileSystem context menu).
func show_new_script_in(dir: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Create Python script"
	dlg.ok_button_text = "Create"

	var box := VBoxContainer.new()
	var label := Label.new()
	label.text = "Script name (in %s):" % dir
	var edit := LineEdit.new()
	edit.custom_minimum_size.x = 380
	edit.text = _unique_name(dir)
	var error := Label.new()
	error.modulate = Color(1.0, 0.5, 0.5)
	box.add_child(label)
	box.add_child(edit)
	box.add_child(error)
	dlg.add_child(box)
	dlg.register_text_enter(edit)

	var validate := func(_text := "") -> void:
		var message := _name_error(edit.text.strip_edges(), dir)
		error.text = message
		dlg.get_ok_button().disabled = not message.is_empty()
	edit.text_changed.connect(validate)
	dlg.confirmed.connect(func():
		var name := edit.text.strip_edges()
		if not _name_error(name, dir).is_empty():
			return
		if name.get_extension() != "py":
			name += ".py"
		_create_script(dir.path_join(name)))
	dlg.visibility_changed.connect(func():
		if not dlg.visible:
			dlg.queue_free())

	EditorInterface.get_base_control().add_child(dlg)
	dlg.popup_centered()
	validate.call()
	edit.grab_focus.call_deferred()
	edit.select.call_deferred(0, edit.text.get_basename().length())


func _unique_name(dir: String) -> String:
	var name := "new_script"
	var n := 2
	while FileAccess.file_exists(dir.path_join(name + ".py")):
		name = "new_script_%d" % n
		n += 1
	return name + ".py"


## Empty string = OK. The name must be importable from Python.
func _name_error(name: String, dir: String) -> String:
	var base := name.get_basename() if name.get_extension() == "py" else name
	if base.is_empty():
		return "Enter a name."
	if not base.is_valid_identifier():
		return "Use letters, digits and _ only (not starting with a digit)."
	if FileAccess.file_exists(dir.path_join(base + ".py")):
		return "This file already exists."
	return ""


func _create_script(path: String) -> void:
	if path.get_extension() != "py":
		path += ".py"
	if not FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			push_error("[PythonBridge] Cannot create %s (error %d)" % [path, FileAccess.get_open_error()])
			return
		f.store_string(_template(path))
		f.close()
	var fs := EditorInterface.get_resource_filesystem()
	fs.scan()
	await get_tree().process_frame
	var tries := 0
	while fs.is_scanning() and tries < 50:
		await get_tree().create_timer(0.1).timeout
		tries += 1
	# Text files are not loaded via ResourceLoader; the editor opens them when the
	# FileSystem dock activates the entry, so select it there and activate it.
	EditorInterface.select_file(path)
	await get_tree().process_frame
	if not _open_via_file_dock(path):
		print("[PythonBridge] Created %s - double-click it in the FileSystem dock to open." % path)


func _open_via_file_dock(path: String) -> bool:
	var dock := EditorInterface.get_file_system_dock()
	if dock == null:
		return false
	for node in dock.find_children("*", "Tree", true, false):
		var tree := node as Tree
		var item := tree.get_selected()
		if item != null and str(item.get_metadata(0)) == path:
			tree.item_activated.emit()
			return true
	for node in dock.find_children("*", "ItemList", true, false):
		var list := node as ItemList
		for i in list.item_count:
			if list.is_selected(i) and str(list.get_item_metadata(i)) == path:
				list.item_activated.emit(i)
				return true
	return false


func _template(path: String) -> String:
	var root: String = String(ProjectSettings.get_setting("python_bridge/scripts_dir", "res://py")).trim_suffix("/")
	var module := path.get_file().get_basename()
	if path.begins_with(root + "/"):
		module = path.trim_prefix(root + "/").get_basename().replace("/", ".")
	return '"""%s\n\nCall from GDScript:\n    var r = await PythonBridge.call_function("%s", "hello", ["Godot"])\n"""\n\n\ndef hello(name="world"):\n    return f"Hello, {name}!"\n' % [path.get_file(), module]
