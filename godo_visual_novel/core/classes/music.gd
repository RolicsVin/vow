## Узел управления музыкальными композициями.
class_name Music extends Node


## Запускает музыкальную композицию по пути к узлу.
func play_music(music_name: String) -> void:
	_set_music_state(music_name, true)


## Останавливает музыкальную композицию по пути к узлу.
func stop_music(music_name: String) -> void:
	_set_music_state(music_name, false)


## Переключает состояние музыкального узла или его компонента LinearSound.
func _set_music_state(music_name: String, should_play: bool) -> void:
	if music_name.is_empty():
		push_warning("[Music] Не указан путь к музыкальной композиции")
		return

	var music_node: Node = get_node_or_null(NodePath(music_name))
	if not music_node:
		push_warning("[Music] Музыкальная композиция не найдена: '%s'" % music_name)
		return

	var has_linear_sound: bool = false
	for child in music_node.get_children():
		if child is LinearSound:
			has_linear_sound = true
			if should_play:
				child.linear_on()
			else:
				child.linear_off()

	if has_linear_sound:
		return

	var method_name: StringName = &"play" if should_play else &"stop"
	if music_node.has_method(method_name):
		music_node.call(method_name)
	else:
		push_warning(
			"[Music] Узел '%s' не поддерживает управление музыкой: отсутствует метод '%s'"
			% [music_node.get_path(), method_name]
		)
