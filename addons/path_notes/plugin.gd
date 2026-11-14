@tool
## Плагин для прикрепления текстовых подсказок к файлам и папкам 
## в панели «Файловая система». Файлы определяются по uid, 
## путь служит запасным вариантом. 
class_name PathNotesPlugin extends EditorPlugin

const NOTES_PATH: String = 'res://addons/path_notes/notes.json' ## Файл с сохранёнными подсказками
const NOTE_MARKER: String = '📝 ' ## Префикс, по которому узнаём наши тултипы

var entries: Array[Dictionary] = [] ## Все подсказки: словари с ключами uid, path и text
var by_uid: Dictionary = {} ## Индекс «uid -> запись»
var by_path: Dictionary = {} ## Индекс «путь -> запись»
var context_menu: ContextMenu ## Плагин контекстного меню
var tooltip_plugin: NoteTooltip ## Плагин, дополняющий тултипы файлов заметкой
var edit_dialog: ConfirmationDialog ## Диалог редактирования подсказки
var note_input: TextEdit ## Поле ввода текста подсказки
var edited_path: String = '' ## Путь, подсказка которого сейчас редактируется


func _enter_tree() -> void: ## Включение плагина
	_load_notes()
	_sync_entries()

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
	var dock: FileSystemDock = EditorInterface.get_file_system_dock()
	dock.add_resource_tooltip_plugin(tooltip_plugin)

	# Следим за изменениями и перемещениями
	dock.folder_moved.connect(_on_folder_moved)
	dock.files_moved.connect(_on_file_moved)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	_refresh_tooltips.call_deferred()


func _exit_tree() -> void: ## Выключение плагина
	var dock: FileSystemDock = EditorInterface.get_file_system_dock()
	remove_context_menu_plugin(context_menu)
	dock.remove_resource_tooltip_plugin(tooltip_plugin)
	dock.folder_moved.disconnect(_on_folder_moved)
	dock.files_moved.disconnect(_on_file_moved)
	EditorInterface.get_resource_filesystem().filesystem_changed.disconnect(_on_filesystem_changed)
	edit_dialog.queue_free()


## Открывает диалог редактирования подсказки для указанного пути
func open_editor(path: String) -> void:
	edited_path = _normalize(path)
	note_input.text = get_note(edited_path)
	edit_dialog.popup_centered()


## Возвращает текст подсказки для пути или пустую строку, если подсказки нет
func get_note(path: String) -> String:
	var entry: Dictionary = _find_entry(path)
	return String(entry.get('text', ''))


## Создаёт, обновляет или удаляет подсказку для пути
func set_note(path: String, text: String) -> void:
	var normalized_path: String = _normalize(path)
	var entry: Dictionary = _find_entry(normalized_path)

	# Пустой текст удаляет подсказку
	if text.is_empty():
		if not entry.is_empty():
			entries.erase(entry)
	elif entry.is_empty():
		entries.append({
			'uid': _get_uid_text(normalized_path),
			'path': normalized_path,
			'text': text,
		})
	else:
		entry['text'] = text

	_reindex()
	_save_notes()


## Ищет запись: сначала по uid, затем по пути. Возвращает пустой словарь, если записи нет
func _find_entry(path: String) -> Dictionary:
	var normalized_path: String = _normalize(path)
	var uid_text: String = _get_uid_text(normalized_path)

	# Основной способ - поиск по uid
	if not uid_text.is_empty() and by_uid.has(uid_text):
		return by_uid[uid_text]

	# Запасной способ - поиск по пути
	if not by_path.has(normalized_path):
		return {}
	var entry: Dictionary = by_path[normalized_path]
	var entry_uid: String = entry['uid']
	if entry_uid == uid_text:
		return entry

	# Старый uid записи всё ещё жив, но принадлежит другому файлу - запись чужая
	if not entry_uid.is_empty() and ResourceUID.has_id(ResourceUID.text_to_id(entry_uid)):
		return {}

	# Файл пересоздан или раньше не имел uid - привязываем запись к текущему uid
	entry['uid'] = uid_text
	_reindex()
	_save_notes()
	return entry


## Возвращает uid файла в текстовом виде или пустую строку (для папок и файлов без uid)
func _get_uid_text(path: String) -> String:
	if DirAccess.dir_exists_absolute(path):
		return '' # У папок uid нет
	var uid: int = ResourceLoader.get_resource_uid(path)
	if uid == ResourceUID.INVALID_ID:
		return ''
	return ResourceUID.id_to_text(uid)


## Приводит записи в соответствие с проектом: обновляет пути по uid и добавляет недостающие uid
func _sync_entries() -> void:
	var changed: bool = false
	for entry: Dictionary in entries:
		var entry_uid: String = entry['uid']

		# Запись с uid: актуализируем запасной путь
		if not entry_uid.is_empty():
			var uid: int = ResourceUID.text_to_id(entry_uid)
			if ResourceUID.has_id(uid):
				var current_path: String = ResourceUID.get_id_path(uid)
				if current_path != entry['path']:
					entry['path'] = current_path
					changed = true
			continue

		# Запись без uid: пробуем его получить (например, после миграции со старого формата)
		var found_uid: String = _get_uid_text(entry['path'])
		if not found_uid.is_empty():
			entry['uid'] = found_uid
			changed = true

	if changed:
		_reindex()
		_save_notes()


## Пересобирает индексы по uid и по пути
func _reindex() -> void:
	by_uid.clear()
	by_path.clear()
	for entry: Dictionary in entries:
		by_path[entry['path']] = entry
		if not String(entry['uid']).is_empty():
			by_uid[entry['uid']] = entry


## Загружает подсказки из JSON-файла (поддерживается и старый формат «путь -> текст»)
func _load_notes() -> void:
	entries.clear()
	if FileAccess.file_exists(NOTES_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
		if parsed is Dictionary and parsed.has('notes'):
			for item: Variant in parsed['notes']:
				if item is Dictionary:
					entries.append(item)
		elif parsed is Dictionary:
			# Старый формат: переносим записи без uid, он подтянется при синхронизации
			for path: String in parsed:
				entries.append({'uid': '', 'path': path, 'text': parsed[path]})
	_reindex()


## Сохраняет подсказки в JSON-файл
func _save_notes() -> void:
	var file: FileAccess = FileAccess.open(NOTES_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({'notes': entries}, '\t'))


## Убирает завершающий слэш у путей папок (кроме корня)
func _normalize(path: String) -> String:
	if path.length() > 6 and path.ends_with('/'):
		return path.trim_suffix('/')
	return path


## Реакция на обновление файловой системы
func _on_filesystem_changed() -> void:
	_sync_entries()
	_refresh_tooltips()


## Сохраняет подсказки после переноса папки (у папок нет uid, поэтому правим пути вручную)
func _on_folder_moved(old_folder: String, new_folder: String) -> void:
	var old_path: String = _normalize(old_folder)
	var new_path: String = _normalize(new_folder)
	for entry: Dictionary in entries:
		var entry_path: String = entry['path']
		# Затрагиваем саму папку и всё, что лежит внутри
		if entry_path == old_path or entry_path.begins_with(old_path + '/'):
			entry['path'] = new_path + entry_path.substr(old_path.length())
	_reindex()
	_save_notes()
	_refresh_tooltips()


## Сохраняет подсказки после переноса файла без uid
func _on_file_moved(old_file: String, new_file: String) -> void:
	if by_path.has(old_file):
		by_path[old_file]['path'] = new_file
		_reindex()
		_save_notes()


## Сохраняет введённый текст и обновляет тултипы
func _on_dialog_confirmed() -> void:
	set_note(edited_path, note_input.text.strip_edges())
	_refresh_tooltips()


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
		var note: String = get_note(path)
		if not note.is_empty():
			item.set_tooltip_text(0, NOTE_MARKER + note + '\n\n' + path)
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
		var note: String = get_note(path)
		if not note.is_empty():
			list.set_item_tooltip(index, NOTE_MARKER + note + '\n\n' + path)
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
