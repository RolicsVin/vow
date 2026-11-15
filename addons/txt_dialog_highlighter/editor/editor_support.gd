@tool
extends Node
## Подключает подсветчик и интеллектуальные подсказки TXTLinearDialog к Script Editor


## Путь к настройке расширений текстовых файлов
const TEXT_EXTENSIONS_SETTING: String = 'docks/filesystem/textfile_extensions'

## Метаданные экземпляра подсветчика
const HIGHLIGHTER_META: StringName = 'txt_linear_dialog_highlighter'

## Метаданные помощника редактора
const ASSISTANT_META: StringName = 'txt_linear_dialog_assistant'

## Интервал поиска открытых вкладок
const SCAN_INTERVAL: float = 0.5

const Highlighter = preload(
	'res://addons/txt_dialog_highlighter/editor/txt_dialog_highlighter.gd'
)
const Assistant = preload(
	'res://addons/txt_dialog_highlighter/editor/dialog_assistant.gd'
)

var _timer: Timer ## Таймер периодического поиска открытых вкладок


## Запустить поиск текстовых вкладок
func _ready() -> void:
	_ensure_text_extension()

	_timer = Timer.new()
	_timer.wait_time = SCAN_INTERVAL
	_timer.timeout.connect(_scan_editors)
	_timer.autostart = true
	add_child(_timer)

	_scan_editors.call_deferred()


## Найти открытые TXT-вкладки Script Editor
func _scan_editors() -> void:
	var script_editor: ScriptEditor = EditorInterface.get_script_editor()
	var editors: Array[ScriptEditorBase] = script_editor.get_open_script_editors()
	if editors.is_empty():
		return

	var tabs: TabContainer = editors[0].get_parent() as TabContainer
	if tabs == null:
		return

	for node in script_editor.find_children('*', 'ItemList', true, false):
		var list: ItemList = node as ItemList
		for item_index in range(list.item_count):
			var tab_index: Variant = list.get_item_metadata(item_index)
			if not (tab_index is int):
				continue
			if tab_index < 0 or tab_index >= tabs.get_tab_count():
				continue
			if not _is_text_item(
				list.get_item_text(item_index),
				list.get_item_tooltip(item_index)
			):
				continue

			var tab: Control = tabs.get_tab_control(tab_index)
			if tab == null or not tab.has_method('get_base_editor'):
				continue

			var code_edit: CodeEdit = tab.get_base_editor() as CodeEdit
			_setup_code_edit(tab, code_edit)


## Проверить, что вкладка относится к TXT-файлу
func _is_text_item(item_text: String, tooltip: String) -> bool:
	if tooltip.get_extension().to_lower() == 'txt':
		return true

	var file_name: String = item_text.strip_edges().trim_suffix('(*)').strip_edges()
	return file_name.get_extension().to_lower() == 'txt'


## Подключить подсветчик и помощник к CodeEdit конкретной вкладки
func _setup_code_edit(tab: Control, code_edit: CodeEdit) -> void:
	if not is_instance_valid(code_edit):
		return

	var highlighter: EditorSyntaxHighlighter = code_edit.get_meta(
		HIGHLIGHTER_META,
		null
	)

	if highlighter == null:
		highlighter = Highlighter.new()
		tab.add_syntax_highlighter(highlighter)
		code_edit.set_meta(HIGHLIGHTER_META, highlighter)

	if code_edit.syntax_highlighter != highlighter:
		code_edit.syntax_highlighter = highlighter

	if not code_edit.has_meta(ASSISTANT_META):
		var assistant: RefCounted = Assistant.new()
		assistant.setup(code_edit)
		code_edit.set_meta(ASSISTANT_META, assistant)


## Добавить расширение TXT в список текстовых файлов Godot
func _ensure_text_extension() -> void:
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	var extensions: PackedStringArray = String(
		settings.get_setting(TEXT_EXTENSIONS_SETTING)
	).split(',', false)

	for extension in extensions:
		if extension.strip_edges().to_lower() == 'txt':
			return

	extensions.append('txt')
	settings.set_setting(TEXT_EXTENSIONS_SETTING, ','.join(extensions))

	_show_restart_dialog()


## Предупредить о необходимости перезапуска редактора
func _show_restart_dialog() -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = 'TXTLinearDialog'
	dialog.dialog_text = (
		'Расширение .txt добавлено в список текстовых файлов Godot. '
		+ 'Перезапусти редактор, чтобы TXT-файлы открывались во вкладке Скрипт.'
	)
	dialog.ok_button_text = 'Перезапустить сейчас'
	dialog.cancel_button_text = 'Позже'
	dialog.confirmed.connect(func() -> void: EditorInterface.restart_editor(true))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)

	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
