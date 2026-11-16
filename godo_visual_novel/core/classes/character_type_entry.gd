## Запись типа персонажа, доступная для настройки в ресурсах
class_name CharacterTypeEntry extends Resource

## Уникальный числовой идентификатор типа персонажа
@export var id: int = 0
## Ключ типа персонажа для сценариев и программного доступа
@export var key: StringName
## Название типа персонажа на русском языке
@export var name_ru: String
## Название типа персонажа на английском языке
@export var name_en: String
## Цвет имени персонажа в диалоговом окне
@export var color: Color = Color.WHITE
