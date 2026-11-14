## Узел управления звуковыми эффектами.
class_name Sounds extends Node


## Запускает звуковой эффект по пути к узлу.
func play_sound(sound_name: String) -> void:
	_set_sound_state(sound_name, true)


## Останавливает звуковой эффект по пути к узлу.
func stop_sound(sound_name: String) -> void:
	_set_sound_state(sound_name, false)


## Переключает состояние звукового узла или его компонента LinearSound.
func _set_sound_state(sound_name: String, should_play: bool) -> void:
	if sound_name.is_empty():
		push_warning('[Sounds] Не указан путь к звуковому эффекту')
		return

	var sound_node: Node = get_node_or_null(NodePath(sound_name))
	if not sound_node:
		push_warning('[Sounds] Звуковой эффект не найден: '%s'' % sound_name)
		return

	var has_linear_sound: bool = false
	for child in sound_node.get_children():
		if child is LinearSound:
			has_linear_sound = true
			if should_play:
				child.linear_on()
			else:
				child.linear_off()

	if has_linear_sound:
		return

	var method_name: StringName = &'play' if should_play else &'stop'
	if sound_node.has_method(method_name):
		sound_node.call(method_name)
	else:
		push_warning(
			'[Sounds] Узел '%s' не поддерживает управление звуком: отсутствует метод '%s''
			% [sound_node.get_path(), method_name]
		)
