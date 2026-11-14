@tool
## Плагин для прикрепления текстовых подсказок к файлам и папкам 
## в панели «Файловая система». 
class_name PathNotesPlugin extends EditorPlugin

const NOTES_PATH: String = 'res://addons/path_notes/notes.json' ## Файл с сохранёнными подсказками
const NOTE_MARKER: String = '📝 ' ## Префикс, по которому узнаём наши тултипы

var notes: Dictionary = {} ## Соответствие «путь -> текст подсказки»
var context_menu: ContextMenu ## Плагин контекстного меню
var edit_dialog: ConfirmationDialog ## Диалог редактирования подсказки
var note_input: TextEdit ## Поле ввода текста подсказки
var edited_path: String = '' ## Путь, подсказка которого сейчас редактируется
var tooltip_plugin: NoteTooltip ## Плагин, дополняющий тултипы файлов заметкой


## Возвращает текст подсказки для пути или пустую строку, если подсказки нет
func get_note(path: String) -> String:
	return notes.get(_normalize(path), '')


func _enter_tree() -> void: ## Включение плагина
	_load_notes()
	
	# Создаём диалог редактирования
	edit_dialog = ConfirmationDialog.new()
	edit_dialog.title = 'Подсказка'
	note_input = TextEdit.new()
	note_input.custom_minimum_size = Vector2(400, 120)
	edit_dialog.add_child(note_input)
	edit_dialog.confirmed.connect(_on_dialog_confirmed)
	EditorInterface.get_base_control().add_child(edit_dialog)
	
	# Регистрируем пункт контекстного меню
	context_menu = ContextMenu.new()
	context_menu.plugin = self
	add_context_menu_plugin(EditorContextMenuPlugin.CONTEXT_SLOT_FILESYSTEM, context_menu)
	
	# Регистрируем плагин тултипов для файлов
	tooltip_plugin = NoteTooltip.new()
	tooltip_plugin.plugin = self
	EditorInterface.get_file_system_dock().add_resource_tooltip_plugin(tooltip_plugin)
	
	# Переприменяем подсказки при каждом обновлении файловой системы
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refresh_tooltips)
	_refresh_tooltips.call_deferred()


func _exit_tree() -> void: ## Выключение плагина
	remove_context_menu_plugin(context_menu)
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_refresh_tooltips)
	EditorInterface.get_file_system_dock().remove_resource_tooltip_plugin(tooltip_plugin)
	edit_dialog.queue_free()


## Открывает диалог редактирования подсказки для указанного пути
func open_editor(path: String) -> void:
	edited_path = _normalize(path)
	note_input.text = notes.get(edited_path, '')
	edit_dialog.popup_centered()


## Сохраняет введённый текст и обновляет тултипы
func _on_dialog_confirmed() -> void:
	var text: String = note_input.text.strip_edges()
	if text.is_empty():
		notes.erase(edited_path) # Пустой текст удаляет подсказку
	else:
		notes[edited_path] = text
	_save_notes()
	_refresh_tooltips()


## Загружает подсказки из JSON-файла
func _load_notes() -> void:
	if not FileAccess.file_exists(NOTES_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
	if parsed is Dictionary:
		notes = parsed


## Сохраняет подсказки в JSON-файл
func _save_notes() -> void:
	var file: FileAccess = FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(notes, '\t'))


## Убирает завершающий слэш у путей папок (кроме корня)
func _normalize(path: String) -> String:
	if path.length() > 6 and path.ends_with('/'):
		return path.trim_suffix('/')
	return path


## Применяет подсказки ко всем деревьям и спискам в панели файлов
func _refresh_tooltips() -> void:
	_apply_to_node(EditorInterface.get_file_system_dock())


## Рекурсивно обходит узлы панели и ставит тултипы
func _apply_to_node(node: Node) -> void:
	if node is Tree:
		var root: TreeItem = node.get_root()
		if root != null:
			_apply_to_tree_item(root)
	elif node is ItemList:
		_apply_to_item_list(node)
	for child: Node in node.get_children():
		_apply_to_node(child)


## Ставит тултипы элементу дерева и его потомкам (только для папок)
func _apply_to_tree_item(item: TreeItem) -> void:
	var meta: Variant = item.get_metadata(0)
	if meta is String and DirAccess.dir_exists_absolute(meta):
		var path: String = _normalize(meta)
		if notes.has(path):
			item.set_tooltip_text(0, NOTE_MARKER + notes[path] + '\n\n' + path)
		elif item.get_tooltip_text(0).begins_with(NOTE_MARKER):
			item.set_tooltip_text(0, path) # Подсказку удалили - возвращаем обычный тултип
	for child: TreeItem in item.get_children():
		_apply_to_tree_item(child)


## Ставит тултипы папкам в списке файлов
func _apply_to_item_list(list: ItemList) -> void:
	for index: int in list.item_count:
		var meta: Variant = list.get_item_metadata(index)
		if not (meta is String and DirAccess.dir_exists_absolute(meta)):
			continue
		var path: String = _normalize(meta)
		if notes.has(path):
			list.set_item_tooltip(index, NOTE_MARKER + notes[path] + '\n\n' + path)
		elif list.get_item_tooltip(index).begins_with(NOTE_MARKER):
			list.set_item_tooltip(index, path)


## Пункт контекстного меню «Изменить подсказку…»
class ContextMenu extends EditorContextMenuPlugin:
	var plugin: PathNotesPlugin ## Ссылка на основной плагин

	## Добавляет пункт меню, если выбран ровно один файл или папка
	func _popup_menu(paths: PackedStringArray) -> void:
		if paths.size() == 1:
			add_context_menu_item('Изменить подсказку…', _on_item_pressed)

	## Открывает диалог для выбранного пути
	func _on_item_pressed(paths: PackedStringArray) -> void:
		plugin.open_editor(paths[0])


## Дополняет стандартный тултип файла текстом подсказки
class NoteTooltip extends EditorResourceTooltipPlugin:
	var plugin: PathNotesPlugin ## Ссылка на основной плагин

	## Обрабатываем файлы любого типа
	func _handles(resource_type: String) -> bool:
		return true

	## Добавляет подсказку в начало стандартного тултипа
	func _make_tooltip_for_path(path: String, metadata: Dictionary, base: Control) -> Control:
		var note: String = plugin.get_note(path)
		if note.is_empty():
			return base # Подсказки нет - оставляем стандартный тултип

		# Метка с текстом подсказки
		var note_label: Label = Label.new()
		note_label.text = PathNotesPlugin.NOTE_MARKER + note
		note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note_label.custom_minimum_size.x = 300

		# Вставляем метку и разделитель перед стандартным содержимым
		base.add_child(note_label)
		base.move_child(note_label, 0)
		var separator: HSeparator = HSeparator.new()
		base.add_child(separator)
		base.move_child(separator, 1)
		return base
