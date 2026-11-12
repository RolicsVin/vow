extends Node

var _data: Node = ToolFactory.make_tool(self, "res://godo_visual_novel/data/gvn_data.gd", "Data")

var _buffer: Dictionary = {
	'history': []
}


func _ready() -> void:
	if _data.current_language == GvnEnums.languages.En:
		GvnData.emotion_protection = GvnData.emotion_en_protection
		GvnData.name_protection = GvnData.name_en_protection
	if GvnData.current_language == GvnEnums.languages.Ru:
		GvnData.emotion_protection = GvnData.emotion_ru_protection
		GvnData.name_protection = GvnData.name_ru_protection


func set_language(language: GvnEnums.languages):
	GvnData.current_language = language
	
	if GvnData.current_language == GvnEnums.languages.En:
		GvnData.emotion_protection = GvnData.emotion_en_protection
		GvnData.name_protection = GvnData.name_en_protection
	if GvnData.current_language == GvnEnums.languages.Ru:
		GvnData.emotion_protection = GvnData.emotion_ru_protection
		GvnData.name_protection = GvnData.name_ru_protection


func get_save() -> Dictionary:
	if 'chat' not in _buffer:
		_buffer['chat'] = {
			'scene': '',
			'linear_dialog': '',
			'index': 0,
			'name': ''
		}
	
	var save: Dictionary = {
		'name': GvnData.name_protection[GvnEnums.characters.ГлавныйГерой],
		'chat': _buffer['chat'],
		'video': GvnData.video,
		'bookmarks': GvnData.bookmarks_scenes,
		'language': int(GvnData.current_language),
		'text_speed': GvnData.text_speed,
		'automatic_text_switching': GvnData.automatic_text_switching,
		'automatic_text_switching_speed': GvnData.automatic_text_switching_speed
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
	GvnData.bookmarks_scenes = save['bookmarks']
	GvnData.text_speed = save['text_speed']
	GvnData.automatic_text_switching = save['automatic_text_switching']
	GvnData.automatic_text_switching_speed = save['automatic_text_switching_speed']
	GvnData.video = save['video']
	set_language(save['language'])
	GvnData.name_protection[GvnEnums.characters.ГлавныйГерой] = save['name']
	
	print()
	print('GVNsave_load-------------------------------------')
	print(save)
	print('-----------------------------------------------')
	print()


func add_bookmark(bookmark: String, _name: String) -> void:
	"""Добавляет сцену в закладки по её пути. Если закладка уже существует, то будет перезаписана."""
	GvnData.bookmarks_scenes[_name] = bookmark


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
	return get_character_name(GvnEnums.characters.ГлавныйГерой)


## Возвращает текущую скорость отображения текста.
func get_text_speed() -> float:
	return _data.text_speed


## Возвращает скорость автоматического переключения текста.
func get_automatic_text_switching_speed() -> float:
	return _data.automatic_text_switching_speed


## Возвращает текущий язык интерфейса новеллы.
func get_language() -> GvnEnums.languages:
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
