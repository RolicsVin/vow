extends Node

var _data: Node = ToolFactory.make_tool(self, "res://godo_visual_novel/data/gvn_data.gd", "Data")

var _buffer: Dictionary = {
	'history': []
}


func _ready() -> void:
	if _data.current_language == Replica.Language.En:
		_data.emotion_protection = _data.emotion_en_protection
		_data.name_protection = _data.name_en_protection
	if _data.current_language == Replica.Language.Ru:
		_data.emotion_protection = _data.emotion_ru_protection
		_data.name_protection = _data.name_ru_protection


func set_language(language: Replica.Language):
	_data.current_language = language
	
	if _data.current_language == Replica.Language.En:
		_data.emotion_protection = _data.emotion_en_protection
		_data.name_protection = _data.name_en_protection
	if _data.current_language == Replica.Language.Ru:
		_data.emotion_protection = _data.emotion_ru_protection
		_data.name_protection = _data.name_ru_protection


func get_save() -> Dictionary:
	if 'chat' not in _buffer:
		_buffer['chat'] = {
			'scene': '',
			'linear_dialog': '',
			'index': 0,
			'name': ''
		}
	
	var save: Dictionary = {
		'name': _data.name_protection[Character.CharacterType.ГлавныйГерой],
		'chat': _buffer['chat'],
		'video': _data.video,
		'bookmarks': _data.bookmarks_scenes,
		'language': int(_data.current_language),
		'text_speed': _data.text_speed,
		'automatic_text_switching': _data.automatic_text_switching,
		'automatic_text_switching_speed': _data.automatic_text_switching_speed
	}
	print('Печатает служба Godo Visual Novel')
	
	print()
	print('GVNsave_saving-------------------------------------')
	print(save)
	print('-----------------------------------------------')
	print()
	
	return save


func load_save(save: Dictionary) -> void:
	print('Печатает служба Godo Visual Novel')
	print(save['chat'])
	_buffer['chat'] = save['chat']
	_data.bookmarks_scenes = save['bookmarks']
	_data.text_speed = save['text_speed']
	_data.automatic_text_switching = save['automatic_text_switching']
	_data.automatic_text_switching_speed = save['automatic_text_switching_speed']
	_data.video = save['video']
	set_language(save['language'])
	_data.name_protection[Character.CharacterType.ГлавныйГерой] = save['name']
	
	print()
	print('GVNsave_load-------------------------------------')
	print(save)
	print('-----------------------------------------------')
	print()


func add_bookmark(bookmark: String, _name: String) -> void:
	"""Добавляет сцену в закладки по её пути. Если закладка уже существует, то будет перезаписана."""
	_data.bookmarks_scenes[_name] = bookmark


func _get_buffer() -> Dictionary:
	"""Вернёт буффер модуля godo_visual_novel."""
	return _buffer


func _write_buffer(obj, k) -> void:
	"""Допишет в буфер информацию по ключу. Если ключ уже существует, то информация будет перезаписана."""
	_buffer[k] = obj


func _clear_buffer() -> void:
	"""Полностью очистит буфер"""
	_buffer.clear()


## Возвращает отображаемое имя персонажа для текущего языка.
func get_character_name(character: int) -> String:
	return _data.name_protection.get(character, "")


## Возвращает отображение эмоции для текущего языка.
func get_emotion_name(emotion: int) -> String:
	return _data.emotion_protection.get(emotion, "")


## Возвращает цвет персонажа.
func get_character_color(character: int) -> Color:
	return _data.characters_color.get(character, Color.WHITE)


## Возвращает защитное имя главного героя.
func get_player_name() -> String:
	return get_character_name(Character.CharacterType.ГлавныйГерой)


## Возвращает текущую скорость отображения текста.
func get_text_speed() -> float:
	return _data.text_speed


## Возвращает скорость автоматического переключения текста.
func get_automatic_text_switching_speed() -> float:
	return _data.automatic_text_switching_speed


## Возвращает текущий язык интерфейса новеллы.
func get_language() -> Replica.Language:
	return _data.current_language


## Возвращает состояние отображения видео.
func is_video_enabled() -> bool:
	return _data.video


## Проверяет наличие локализованного имени персонажа.
func has_character_name(character: int) -> bool:
	return _data.name_protection.has(character)


## Проверяет наличие локализованного названия эмоции.
func has_emotion_name(emotion: int) -> bool:
	return _data.emotion_protection.has(emotion)


## Проверяет наличие цвета персонажа.
func has_character_color(character: int) -> bool:
	return _data.characters_color.has(character)


## Возвращает внутреннее имя эмоции персонажа.
func get_character_emotion(emotion: int) -> String:
	return _data.character_emotion_protection.get(emotion, "default")
