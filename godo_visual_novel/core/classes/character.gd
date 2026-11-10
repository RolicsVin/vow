class_name Character extends TextureRect

@export var character: GvnEnums.characters = GvnEnums.characters.Нет
@export var emotion_player: AnimationPlayer

@export_group('emotions')
@export var default: Texture2D
@export var avert_eyes: Texture2D
@export var lower_eyes: Texture2D
@export var happy: Texture2D
@export var happy2: Texture2D
@export var evil: Texture2D
@export var screaming: Texture2D
@export var shocked: Texture2D
@export var embarrassed: Texture2D
@export var crying: Texture2D

@export var custom_emotions: Dictionary[String, Texture2D] = {}


func set_emotion(_emotion: String) -> void:
	emotion_player.play(_emotion, 0.5)
	if _emotion in custom_emotions:
		texture = custom_emotions[_emotion]
		return
	
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var variable_name = property.name
			if variable_name == _emotion:
				var variable_value = get(variable_name)
				texture = variable_value


func add_emotion_texture(_emotion: Texture2D, k: String) -> void:
	custom_emotions[k] = _emotion


func remove_emotion_texture(k: String) -> void:
	custom_emotions.erase(k)


func set_texture_emotion(_emotion: Texture2D) -> void:
	texture = _emotion


func get_character() -> GvnEnums.characters:
	return character
