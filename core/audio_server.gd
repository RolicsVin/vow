## Менеджер громкости аудиошин проекта.
class_name AudioServerManager extends RefCounted


## Устанавливает линейную громкость указанной аудиошины.
func set_volume(bus_name: StringName, volume: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning('[AudioServerManager] Аудиошина не найдена: %s' % bus_name)
		return

	AudioServer.set_bus_volume_linear(bus_index, clampf(volume, 0.0, 1.0))


## Возвращает линейную громкость указанной аудиошины.
func get_volume(bus_name: StringName) -> float:
	var bus_index: int = AudioServer.get_bus_index(bus_name)

	if bus_index == -1:
		push_warning('[AudioServerManager] Аудиошина не найдена: %s' % bus_name)
		return 0.0

	return AudioServer.get_bus_volume_linear(bus_index)


## Формирует словарь с громкостью всех существующих аудиошин.
func get_save() -> Dictionary:
	var save_data: Dictionary = {}

	for bus_index: int in range(AudioServer.get_bus_count()):
		var bus_name: StringName = AudioServer.get_bus_name(bus_index)
		save_data[String(bus_name)] = AudioServer.get_bus_volume_linear(bus_index)

	return save_data


## Восстанавливает громкость аудиошин из словаря сохранения.
func load_save(save_data: Dictionary) -> void:
	for bus_name: Variant in save_data:
		if not save_data[bus_name] is float and not save_data[bus_name] is int:
			continue

		var bus_index: int = AudioServer.get_bus_index(StringName(bus_name))
		if bus_index == -1:
			continue

		var volume: float = clampf(float(save_data[bus_name]), 0.0, 1.0)
		AudioServer.set_bus_volume_linear(bus_index, volume)
