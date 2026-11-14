## Узел визуального представления персонажа 
class_name Character extends TextureRect

## Персонажи, встречающиеся в первой главе
enum CharacterType {
	Нет,
	Подросток,
	Асмунд,
	Сосед,
	ДругойСосед,
	Отец,
	Девушка,
	Мать,
	ЖительДеревни,
	ЖительницаДеревни,
	Старейшина,
}

@export var character: Character.CharacterType = Character.CharacterType.Нет
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


## Устанавливает эмоцию спрайта персонажа
func set_emotion(_emotion: String) -> void:
	emotion_player.play(_emotion, 0.5)
	if _emotion in custom_emotions:
		texture = custom_emotions[_emotion]
		return

	# Ищем стандартную эмоцию среди экспортируемых текстур
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var variable_name: String = property.name
			if variable_name == _emotion:
				var variable_value: Texture2D = get(variable_name)
				texture = variable_value


## Добавляет пользовательскую текстуру эмоции
func add_emotion_texture(_emotion: Texture2D, k: String) -> void:
	custom_emotions[k] = _emotion


## Удаляет пользовательскую текстуру эмоции
func remove_emotion_texture(k: String) -> void:
	custom_emotions.erase(k)


## Устанавливает текстуру эмоции напрямую
func set_texture_emotion(_emotion: Texture2D) -> void:
	texture = _emotion


## Возвращает тип персонажа, назначенный этому узлу
func get_character() -> Character.CharacterType:
	return character
