## Каталог типов персонажей визуальной новеллы 
class_name CharacterTypes extends Resource

## Список типов персонажей. Для новых записей используйте уникальные ID
@export var entries: Array[CharacterTypeEntry] = []


## Возвращает запись типа персонажа по числовому идентификатору
func get_entry(id: int) -> CharacterTypeEntry:
	for entry: CharacterTypeEntry in entries:
		if entry and entry.id == id:
			return entry
	return null


## Возвращает запись типа персонажа по ключу
func find_by_key(key: StringName) -> CharacterTypeEntry:
	for entry: CharacterTypeEntry in entries:
		if entry and entry.key == key:
			return entry
	return null
