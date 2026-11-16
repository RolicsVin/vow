## Запись эмоции, доступная для настройки в ресурсах 
class_name CharacterEmotionEntry extends Resource

## Уникальный числовой идентификатор эмоции
@export var id: int = 0
## Ключ эмоции для сценариев и программного доступа
@export var key: StringName
## Название эмоции на русском языке
@export var name_ru: String
## Название эмоции на английском языке
@export var name_en: String
## Имя текстуры эмоции в узле Character
@export var texture_key: StringName = &'default'
