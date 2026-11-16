## Данные визуальной новеллы: каталоги персонажей, эмоций и настройки отображения

extends Node

## Редактируемый каталог типов персонажей
@export var character_types: CharacterTypes = preload('res://godo_visual_novel/data/character_types.tres')
## Редактируемый каталог эмоций
@export var emotions: CharacterEmotions = preload('res://godo_visual_novel/data/character_emotions.tres')

## Цвета имён персонажей в диалоговом окне
var characters_color: Dictionary = {}
## Сохранённые закладки сцен
var bookmarks_scenes: Dictionary = {}
## Защищённые имена, общие для языков
var name_protection: Dictionary = {}
## Русские имена персонажей
var name_ru_protection: Dictionary = {}
## Английские имена персонажей
var name_en_protection: Dictionary = {}
## Защищённые эмоции, общие для языков
var emotion_protection: Dictionary = {}
## Русские названия эмоций
var emotion_ru_protection: Dictionary = {}
## Английские названия эмоций
var emotion_en_protection: Dictionary = {}
## Эмоции спрайтов персонажей
var character_emotion_protection: Dictionary = {}

var video: bool = true
var text_speed: float = 0.03
var automatic_text_switching: bool = true
var automatic_text_switching_speed: float = 3.0
var current_language: Replica.Language = Replica.Language.En


## Заполняет совместимые словари из редактируемых каталогов
func rebuild_catalogs() -> void:
	characters_color.clear()
	name_ru_protection.clear()
	name_en_protection.clear()
	emotion_ru_protection.clear()
	emotion_en_protection.clear()
	character_emotion_protection.clear()

	for entry: CharacterTypeEntry in character_types.entries:
		if not entry:
			continue
		characters_color[entry.id] = entry.color
		name_ru_protection[entry.id] = entry.name_ru
		name_en_protection[entry.id] = entry.name_en

	for entry: CharacterEmotionEntry in emotions.entries:
		if not entry:
			continue
		emotion_ru_protection[entry.id] = entry.name_ru
		emotion_en_protection[entry.id] = entry.name_en
		character_emotion_protection[entry.id] = String(entry.texture_key)

	if current_language == Replica.Language.Ru:
		name_protection = name_ru_protection.duplicate()
		emotion_protection = emotion_ru_protection.duplicate()
	else:
		name_protection = name_en_protection.duplicate()
		emotion_protection = emotion_en_protection.duplicate()
