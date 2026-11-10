class_name Replica extends Resource

@export var speaker: GvnEnums.characters
@export var emotion: GvnEnums.emotions
@export var replica: String
@export var sound: String
@export var background: String

@export_group('action')
@export var fast_action_start: Array[Action]
@export var fast_action_end: Array[Action]

@export_group('language')
@export var language: GvnEnums.languages = GvnEnums.languages.Ru
@export var languages: Dictionary[GvnEnums.languages, String]

@export_group('adventure')
@export var reset_text_buffer: bool = true

@export var small_text: bool = false

@export var custom_name: String
@export var custom_color: Color
@export var chat_color: Color

@export var custom_character_emotion: String

@export var on_start: Array[Action]
@export var on_end: Array[Action]

@export var type_of_interpolation: GvnEnums.types_of_interpolation = GvnEnums.types_of_interpolation.parent
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
		if speaker in GvnData.name_protection:
			behind = GvnData.name_protection[speaker]
		else:
			behind = GvnEnums.characters.keys()[speaker]
	
	var emotion_buffer: String = '('
	if emotion in GvnData.emotion_protection:
		emotion_buffer += GvnData.emotion_protection[emotion]
	else:
		emotion_buffer += str(GvnEnums.emotions.keys()[emotion])
	
	# Если эмоции нет, то очищаем буфер эмоции, иначе закрываем скобку
	if len(emotion_buffer) < 2:
		emotion_buffer = ''
	else:
		emotion_buffer += ')'
	
	return behind + emotion_buffer


func get_speaker() -> GvnEnums.characters:
	"""Вернёт Enum."""
	if custom_name:
		return GvnEnums.characters.КастомныйПерсонаж
	return speaker


func get_emotion() -> GvnEnums.emotions:
	return emotion


func get_replica() -> String:
	"""Вернёт реплику персонажа."""
	if language == GvnData.current_language:
		return replica.replace('@', GvnData.name_protection[GvnEnums.characters.ГлавныйГерой])
	elif GvnData.current_language in languages:
		return languages[GvnData.current_language].replace('@', GvnData.name_protection[GvnEnums.characters.ГлавныйГерой])
	else:
		return replica.replace('@', GvnData.name_protection[GvnEnums.characters.ГлавныйГерой])


func get_color() -> Color:
	"""Вернёт цвет имени персонажа."""
	if custom_color:
		return custom_color
	if speaker in GvnData.characters_color:
		return GvnData.characters_color[speaker]
	
	return Color.WHITE


func get_chat_color() -> Color:
	return chat_color


func get_type_of_interpolation() -> GvnEnums.types_of_interpolation:
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
