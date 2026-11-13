class_name TxtLinearDialog extends LinearDialog
## LinearDialog, который заполняется из .txt файла при загрузке ресурса.
##
## Как пользоваться: в инспекторе у Chat -> dialog_tree добавь новый ресурс TxtLinearDialog
## и укажи txt_path. Больше ничего заполнять не нужно: реплики появятся сами.
##
## ФОРМАТ ФАЙЛА
##   Диалог состоит из блоков, блоки разделяются пустой строкой.
##   Первая строка блока - текст реплики. Остальные строки - свойства в виде "ключ значение".
##
##   Привет, Матвей!
##   speaker Иван
##   emotion Радостно
##   action;start;sound MatveySpeak
##
## Текст:
##   ~                      вместо текста: реплика без текста (например, только смена фона)
##   \n в тексте            перенос строки внутри реплики
##   // комментарий         строка-комментарий, игнорируется
##   lang;En Hello!         перевод реплики на язык из Replica.Language
##
## Свойства реплики:
##   speaker <Имя>          имя из Character.CharacterType; неизвестное имя станет custom_name
##   name <Имя>             custom_name (имя над репликой), без привязки к персонажу
##   emotion <Эмоция>       имя из Replica.Emotion (пробел можно писать вместо "_")
##   background <Имя>       replica.background
##   sound <Имя>            replica.sound
##   color <цвет>           custom_color (имя цвета или #RRGGBB)
##   chat_color <цвет>      chat_color
##   character_emotion <x>  custom_character_emotion
##   interpolation <тип>    parent | instantaneous | linear
##   reset_text_buffer false
##   small_text true
##   language <Ru|En>       на каком языке написан основной текст
##   id <строка>            unical_id (по умолчанию случайный)
##
## Действия:
##   action;<start|end>;<visible|sound|music> <путь> [off] [slow]
##   По умолчанию действие быстрое (fast_action_*) и включающее (показать/играть).
##   off  - выключить (скрыть/остановить), slow - медленное (on_start/on_end).
##
## Свойства самого диалога (в любом месте файла, отдельным блоком или внутри блока):
##   dialog;name <имя>      dialog_name (по умолчанию - имя файла без расширения)
##   dialog;next <имя>      next_dialog
##   dialog;mini_game <имя> mini_game
##   dialog;start <instantaneous|linear>
##   dialog;end <instantaneous|linear>
##   dialog;interpolation <parent|instantaneous|linear>

## Путь к .txt файлу с диалогом.
@export_file("*.txt") var txt_path: String:
	set(value):
		txt_path = value
		reload_from_txt()

## Ошибки последнего разбора (те же сообщения уходят в push_error / push_warning).
var parse_errors: Array[String] = []

var _source_name: String = ""

const _REPLICA_KEYS: PackedStringArray = [
	"speaker", "name", "emotion", "background", "sound", "color", "chat_color",
	"character_emotion", "interpolation", "reset_text_buffer", "small_text",
	"language", "id",
]
const _TRUE_WORDS: PackedStringArray = ["true", "1", "yes", "on", "да", "вкл"]
const _FALSE_WORDS: PackedStringArray = ["false", "0", "no", "off", "нет", "выкл"]


## Перечитать txt_path. Можно вызвать вручную, если файл поменялся.
func reload_from_txt() -> void:
	if txt_path.is_empty():
		return
	_source_name = txt_path
	if not FileAccess.file_exists(txt_path):
		_error(0, "файл не найден (в экспортированной игре добавь *.txt в include_filter экспорта)")
		return
	load_from_text(FileAccess.get_file_as_string(txt_path), txt_path)


## Разобрать текст и заполнить диалог. Публичный, чтобы можно было тестировать без файла.
func load_from_text(source: String, source_name: String = "") -> void:
	parse_errors.clear()
	_source_name = source_name if source_name else "<text>"
	
	source = source.trim_prefix("\uFEFF").replace("\r\n", "\n").replace("\r", "\n")
	
	# Делим на блоки: каждый блок - массив пар [номер строки, строка]
	var blocks: Array = []
	var current: Array = []
	var line_no: int = 0
	for raw_line in source.split("\n"):
		line_no += 1
		var line: String = raw_line.strip_edges()
		if line.begins_with("//"):
			continue
		if line.is_empty():
			if not current.is_empty():
				blocks.append(current)
				current = []
			continue
		current.append([line_no, line])
	if not current.is_empty():
		blocks.append(current)
	
	var new_replicas: Array[Replica] = []
	for block in blocks:
		var body: Array = []
		for entry in block:
			if (entry[1] as String).begins_with("dialog;"):
				_apply_dialog_line(entry[0], entry[1])
			else:
				body.append(entry)
		if not body.is_empty():
			new_replicas.append(_build_replica(body))
	replicas = new_replicas
	
	if dialog_name.is_empty():
		dialog_name = _source_name.get_file().get_basename()
	if replicas.is_empty():
		_error(0, "в диалоге нет ни одной реплики")


func _build_replica(body: Array) -> Replica:
	var replica := Replica.new()
	var first: String = body[0][1]
	
	if first != "~":
		replica.replica = first.replace("\\n", "\n")
		var head: String = first.split(" ")[0].split(";")[0]
		if head in _REPLICA_KEYS or head == "action" or head == "lang":
			_warn(body[0][0], "текст реплики начинается с ключевого слова «%s». Если это свойство, а текста нет - поставь первой строкой ~" % head)
	
	for i in range(1, body.size()):
		_apply_replica_line(replica, body[i][0], body[i][1])
	return replica


func _apply_replica_line(replica: Replica, line_no: int, line: String) -> void:
	var split := _split_key_value(line)
	var key_parts: PackedStringArray = split[0].split(";")
	var value: String = split[1]
	var key: String = key_parts[0]
	
	if value.is_empty() and key != "action":
		_error(line_no, "у свойства «%s» нет значения" % split[0])
		return
	
	match key:
		"speaker":
			var idx := _find_enum(Character.CharacterType, value)
			if idx == -1:
				_warn(line_no, "персонаж «%s» не найден в Character.CharacterType, использую как custom_name" % value)
				replica.custom_name = value
			else:
				replica.speaker = idx as Character.CharacterType
		"name":
			replica.custom_name = value
		"emotion":
			var idx := _find_enum(Replica.Emotion, value)
			if idx == -1:
				_warn(line_no, "эмоция «%s» не найдена в Replica.Emotion" % value)
			else:
				replica.emotion = idx as Replica.Emotion
		"background":
			replica.background = value
		"sound":
			replica.sound = value
		"color":
			var color := _parse_color(line_no, value)
			if color.a >= 0.0:
				replica.custom_color = color
		"chat_color":
			var color := _parse_color(line_no, value)
			if color.a >= 0.0:
				replica.chat_color = color
		"character_emotion":
			replica.custom_character_emotion = value
		"interpolation":
			var idx := _find_enum(Replica.Interpolation, value)
			if idx == -1:
				_error(line_no, "тип интерполяции «%s» не найден (parent / instantaneous / linear)" % value)
			else:
				replica.type_of_interpolation = idx as Replica.Interpolation
		"reset_text_buffer":
			var flag: Variant = _parse_bool(line_no, value)
			if flag != null:
				replica.reset_text_buffer = flag
		"small_text":
			var flag: Variant = _parse_bool(line_no, value)
			if flag != null:
				replica.small_text = flag
		"language":
			var idx := _find_enum(Replica.Language, value)
			if idx == -1:
				_error(line_no, "язык «%s» не найден в Replica.Language" % value)
			else:
				replica.language = idx as Replica.Language
		"id":
			replica.unical_id = value
		"lang":
			if key_parts.size() != 2:
				_error(line_no, "ожидалось «lang;<язык> текст»")
				return
			var idx := _find_enum(Replica.Language, key_parts[1])
			if idx == -1:
				_error(line_no, "язык «%s» не найден в Replica.Language" % key_parts[1])
			else:
				replica.languages[idx as Replica.Language] = value.replace("\\n", "\n")
		"action":
			_apply_action(replica, line_no, key_parts, value)
		_:
			_error(line_no, "неизвестное свойство «%s»" % split[0])


func _apply_action(replica: Replica, line_no: int, key_parts: PackedStringArray, value: String) -> void:
	# action;<start|end>;<visible|sound|music> <путь> [off] [slow]
	if key_parts.size() != 3:
		_error(line_no, "ожидалось «action;start|end;visible|sound|music путь»")
		return
	
	var when: String = key_parts[1].to_lower()
	if when != "start" and when != "end":
		_error(line_no, "в action первым словом должно быть start или end, а не «%s»" % key_parts[1])
		return
	
	var type_idx := _find_enum(Action.Type, key_parts[2])
	if type_idx == -1:
		_error(line_no, "тип действия «%s» не найден (visible / sound / music)" % key_parts[2])
		return
	
	var tokens: PackedStringArray = value.replace("\t", " ").split(" ", false)
	var enable: bool = true
	var fast: bool = true
	while tokens.size() > 1:
		var last: String = tokens[tokens.size() - 1].to_lower()
		if last == "off":
			enable = false
		elif last == "on":
			enable = true
		elif last == "slow":
			fast = false
		elif last == "fast":
			fast = true
		else:
			break
		tokens.remove_at(tokens.size() - 1)
	
	if tokens.is_empty():
		_error(line_no, "в action не указан путь к ноде")
		return
	
	var action := Action.new()
	action.path_node = " ".join(tokens)
	action.action = enable
	action.action_type = type_idx as Action.Type
	
	if when == "start":
		(replica.fast_action_start if fast else replica.on_start).append(action)
	else:
		(replica.fast_action_end if fast else replica.on_end).append(action)


func _apply_dialog_line(line_no: int, line: String) -> void:
	var split := _split_key_value(line)
	var key_parts: PackedStringArray = split[0].split(";")
	var value: String = split[1]
	
	if key_parts.size() != 2 or value.is_empty():
		_error(line_no, "ожидалось «dialog;свойство значение»")
		return
	
	match key_parts[1]:
		"name":
			dialog_name = value
		"next":
			next_dialog = value
		"mini_game":
			mini_game = value
		"start":
			var idx := _find_enum(LinearDialog.Interpolation, value)
			if idx == -1:
				_error(line_no, "тип «%s» не найден (instantaneous / linear)" % value)
			else:
				type_of_start = idx as LinearDialog.Interpolation
		"end":
			var idx := _find_enum(LinearDialog.Interpolation, value)
			if idx == -1:
				_error(line_no, "тип «%s» не найден (instantaneous / linear)" % value)
			else:
				type_of_end = idx as LinearDialog.Interpolation
		"interpolation":
			var idx := _find_enum(Replica.Interpolation, value)
			if idx == -1:
				_error(line_no, "тип «%s» не найден (parent / instantaneous / linear)" % value)
			else:
				type_of_interpolation = idx as Replica.Interpolation
		_:
			_error(line_no, "неизвестное свойство диалога «%s»" % split[0])


# --- вспомогательные функции -------------------------------------------------

## "ключ значение с пробелами" -> ["ключ", "значение с пробелами"]
func _split_key_value(line: String) -> Array[String]:
	for i in line.length():
		if line[i] == " " or line[i] == "\t":
			return [line.substr(0, i), line.substr(i + 1).strip_edges()]
	return [line, ""]


## Ищет значение enum по имени без учёта регистра; пробел считается за "_". Нет совпадения -> -1.
func _find_enum(enum_dict: Dictionary, raw: String) -> int:
	var wanted: String = raw.strip_edges().replace(" ", "_").to_lower()
	for enum_key: String in enum_dict:
		if enum_key.to_lower() == wanted:
			return enum_dict[enum_key]
	return -1


func _parse_bool(line_no: int, value: String) -> Variant:
	var word: String = value.to_lower()
	if word in _TRUE_WORDS:
		return true
	if word in _FALSE_WORDS:
		return false
	_error(line_no, "ожидалось true/false (или да/нет), а не «%s»" % value)
	return null


## Вернёт Color с a < 0, если цвет не удалось разобрать.
func _parse_color(line_no: int, value: String) -> Color:
	var invalid := Color(0, 0, 0, -1)
	var color := Color.from_string(value, invalid)
	if color.a < 0.0:
		_error(line_no, "не удалось разобрать цвет «%s»" % value)
	return color


func _error(line_no: int, message: String) -> void:
	var text := "%s:%d: %s" % [_source_name, line_no, message] if line_no > 0 else "%s: %s" % [_source_name, message]
	parse_errors.append(text)
	push_error(text)


func _warn(line_no: int, message: String) -> void:
	var text := "%s:%d: %s" % [_source_name, line_no, message]
	parse_errors.append(text)
	push_warning(text)
