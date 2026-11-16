## Каталог эмоций визуальной новеллы
class_name CharacterEmotions extends Resource

## Список эмоций. Для новых записей используйте уникальные ID
@export var entries: Array[CharacterEmotionEntry] = []


## Возвращает запись эмоции по числовому идентификатору
func get_entry(id: int) -> CharacterEmotionEntry:
	for entry: CharacterEmotionEntry in entries:
		if entry and entry.id == id:
			return entry
	return null


## Возвращает запись эмоции по ключу
func find_by_key(key: StringName) -> CharacterEmotionEntry:
	for entry: CharacterEmotionEntry in entries:
		if entry and entry.key == key:
			return entry
	return null
