class_name Replica extends Resource


enum Emotion {Без_эмоции, В_мыслях, Радостно, Счастливо, Смеясь, Веселясь, Хихикая, Грустно, Печально, Огорчённо, Недовольно, Шокированно, Удивлённо, Пугливо, Испуганно, Боясь, Истеря, Плача, Злясь, Злостно, Яростно, Безумно, Неистово, Подозрительно, Раздосадованно, Задумчиво, Насмешливо, Издеваясь, Не_доверчиво, Прищурившись, Присмотревшись, Страсно, Возбуждённо, Влюблённо, Стыдливо, Смущённо}
enum Language {Ru, En}
enum Interpolation {parent, instantaneous, linear}

@export var speaker: Character.CharacterType
@export var emotion: Replica.Emotion
@export var replica: String
@export var sound: String
@export var background: String

@export_group('action')
@export var fast_action_start: Array[Action]
@export var fast_action_end: Array[Action]

@export_group('language')
@export var language: Replica.Language = Replica.Language.Ru
@export var languages: Dictionary[Replica.Language, String]

@export_group('adventure')
@export var reset_text_buffer: bool = true

@export var small_text: bool = false

@export var custom_name: String
@export var custom_color: Color
@export var chat_color: Color

@export var custom_character_emotion: String

@export var on_start: Array[Action]
@export var on_end: Array[Action]

@export var type_of_interpolation: Replica.Interpolation = Replica.Interpolation.parent
@export var unical_id: String


func _init() -> void:
	if not unical_id:
		unical_id = str(randi_range(0, 999_999_999_999))


func get_behind() -> String:
	"""Вернёт экранированное имя персонажа с экранированной эмоцией."""
	var behind: String
	
	if custom_name:
		behind = custom_name
	else:
		if GVN.has_character_name(speaker):
			behind = GVN.get_character_name(speaker)
		else:
			behind = Character.CharacterType.keys()[speaker]
	
	var emotion_buffer: String = '('
	if GVN.has_emotion_name(emotion):
		emotion_buffer += GVN.get_emotion_name(emotion)
	else:
		emotion_buffer += str(Replica.Emotion.keys()[emotion])
	
	# Если эмоции нет, то очищаем буфер эмоции, иначе закрываем скобку
	if len(emotion_buffer) < 2:
		emotion_buffer = ''
	else:
		emotion_buffer += ')'
	
	return behind + emotion_buffer


func get_speaker() -> Character.CharacterType:
	"""Вернёт Enum."""
	if custom_name:
		return Character.CharacterType.КастомныйПерсонаж
	return speaker


func get_emotion() -> Replica.Emotion:
	return emotion


func get_replica() -> String:
	"""Вернёт реплику персонажа."""
	if language == GVN.get_language():
		return replica.replace('@', GVN.get_player_name())
	elif GVN.get_language() in languages:
		return languages[GVN.get_language()].replace('@', GVN.get_player_name())
	else:
		return replica.replace('@', GVN.get_player_name())


func get_color() -> Color:
	"""Вернёт цвет имени персонажа."""
	if custom_color:
		return custom_color
	if GVN.has_character_color(speaker):
		return GVN.get_character_color(speaker)
	
	return Color.WHITE


func get_chat_color() -> Color:
	return chat_color


func get_type_of_interpolation() -> Replica.Interpolation:
	return type_of_interpolation


func get_on_start_fast_action() -> Array[Action]:
	return fast_action_start


func get_on_end_fast_action() -> Array[Action]:
	return fast_action_end


func get_on_start_action() -> Array[Action]:
	return on_start


func get_on_end_action() -> Array[Action]:
	return on_end


func get_sound() -> String:
	return sound


func get_background() -> String:
	return background


func get_custom_character_emotion() -> String:
	return custom_character_emotion


func get_reset_text_buffer() -> bool:
	return reset_text_buffer


func get_small_text() -> bool:
	return small_text


func get_unical_id() -> String:
	return unical_id
