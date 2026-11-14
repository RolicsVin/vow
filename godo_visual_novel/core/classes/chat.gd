## Управляет отображением реплик, диалогами и связанными игровыми действиями 
class_name Chat extends Label

signal dialog_entered(dialog: LinearDialog)
signal replica_started(replica: Replica)
signal replica_ended(replica: Replica)
signal dialog_exited(dialog: LinearDialog)

@export var default_color: Color = Color.WHITE
@export var linear_dialog_play_ready: String
@export var pos: int = 0
@export var dialog_tree: Array[LinearDialog]
@export var notes: Array[String]

@export_group('font')
@export var default_text_size: int = 0
@export var small_text_size: int = 0

@export_group('components')
@export var behind: Behind
@export var fast_action: FastAction
@export var background: Backgrounds
@export var chat_click: ChatClick
@export var mini_games_root: Control
@export var auto_text_swith_timer: Timer

@export var menu: Control
@export var settings_menu: Control
@export var back_button: TextureButton

@export var sounds: Sounds
@export var music: Music
@export var characters: Array[Character]

@export_group('linear_interpolation')
@export var timer: Timer
@export var text_speed: float = 0.03

@export_group('experienced')
@export var show_speed: float = 0.3
@export var behind_set_alpha_to_self_modulate: bool = true

var current_dialog: LinearDialog
var index: int = 0
var text_buffer: String
var _last_replica: Replica
var _hidding: bool = false
var is_loading: bool = false


func _ready() -> void:
	text_speed = GVisualNovel.get_text_speed()

	if not default_text_size:
		default_text_size = get_theme_font_size('font_size')
	if not small_text_size:
		small_text_size = int(default_text_size / 1.5)

	if auto_text_swith_timer:
		auto_text_swith_timer.timeout.connect(next)
	else:
		push_warning('[Chat] Не назначен таймер автоматического переключения реплик')

	hide()
	if behind:
		behind.hide()
	else:
		push_warning('[Chat] Не назначен компонент Behind')

	if back_button:
		back_button.pressed.connect(chat_back)

	if timer:
		timer.wait_time = text_speed
		timer.timeout.connect(_load_symbol_on_byffer)
	else:
		push_warning('[Chat] Не назначен таймер отображения текста')

	autowrap_mode = TextServer.AUTOWRAP_WORD
	modulate = default_color

	_prepare_dialog_tree()

	await get_tree().create_timer(0.5).timeout

	if is_loading:
		return

	if linear_dialog_play_ready:
		play_linear_dialog_on_libriary(linear_dialog_play_ready, pos)


func _prepare_dialog_tree() -> void:
	for dialog in dialog_tree:
		if not dialog:
			push_warning('[Chat] В дереве диалогов обнаружен пустой элемент')
			continue
		if not dialog.get_dialog_name():
			Core.push_fatal_error('У линейного диалога отсутствует имя!')

	for dialog in dialog_tree:
		if not dialog:
			continue
		for replica in dialog.get_replicas():
			if not replica:
				push_warning(
					'[Chat] В диалоге \'%s\' обнаружена пустая реплика' % dialog.get_dialog_name()
				)
				continue
			if replica.get_type_of_interpolation() == Replica.Interpolation.parent:
				replica.type_of_interpolation = dialog.get_interpolation()


func chat_back():
	if not current_dialog:
		return

	index -= 1
	text = current_dialog.get_replica_to_id(index).get_replica()
	text_buffer = text


func load_save_on_buffer() -> void:
	var buffer = GVisualNovel._get_buffer()
	if not 'chat' in buffer:
		return

	is_loading = true
	var save = buffer['chat']
	if name == save['name'] and save['scene'] == Core.scene_tools.get_scene_path():
		play_linear_dialog_on_libriary(save['linear_dialog'], save['index'])


func _process(delta: float) -> void:
	if visible:
		modulate.a = clamp(modulate.a + show_speed * delta, 0, 1)
	else:
		modulate.a = 0

	if behind and behind_set_alpha_to_self_modulate:
		behind.modulate.a = modulate.a

	if _hidding:
		modulate.a = clamp(modulate.a - delta, 0, 1)
		if modulate.a <= 0:
			if behind:
				behind.hide()
			hide()
			_hidding = false


func _load_text_on_buffer() -> void:
	text = text_buffer


func _load_symbol_on_byffer() -> void:
	if not timer:
		return

	if text == text_buffer:
		timer.stop()
		return

	text = text_buffer.substr(0, len(text) + 1)


func play_linear_dialog_on_libriary(dialog_name: String, idx: int = 0):
	_start_dialog(get_linear_dialog(dialog_name), idx, true)


func load_linear_dialog_in_libriary(linear_dialog: LinearDialog):
	if linear_dialog.dialog_name:
		dialog_tree.append(linear_dialog)
	else:
		Core.push_fatal_error('У линейного диалога отсутствует имя!')


func play_linear_dialog(linear_dialog: LinearDialog, idx: int = 0):
	_start_dialog(linear_dialog, idx, false)


func _start_dialog(dialog: LinearDialog, idx: int, start_auto_switch: bool) -> void:
	if not dialog:
		push_warning('[Chat] Не удалось начать диалог: линейный диалог не назначен')
		return

	if idx < 0 or idx >= dialog.get_dialog_len():
		push_warning(
			'[Chat] Не удалось начать диалог \'%s\': индекс реплики %d выходит за границы'
			% [dialog.get_dialog_name(), idx]
		)
		return

	show()
	if behind:
		behind.show()
	if timer:
		timer.start()
	if start_auto_switch and auto_text_swith_timer:
		auto_text_swith_timer.start()
	elif start_auto_switch:
		push_warning('[Chat] Автоматическое переключение отключено: таймер не назначен')

	index = idx
	current_dialog = dialog

	if current_dialog.get_dialog_start_type() == LinearDialog.Interpolation.instantaneous:
		modulate = default_color

	set_replica(current_dialog.get_replica_to_id(index))
	dialog_entered.emit(current_dialog)


func get_dialog_tree() -> Array[LinearDialog]:
	return dialog_tree


func get_linear_dialog(dialog_name: String):
	for linear_dialog in dialog_tree:
		if linear_dialog.get_dialog_name() == dialog_name:
			return linear_dialog


func perform_an_action_start(replica: Replica):
	_perform_replica_actions(
		replica.get_on_start_fast_action(),
		replica.get_on_start_action(),
		true
	)


func perform_an_action_end(replica: Replica):
	_perform_replica_actions(
		replica.get_on_end_fast_action(),
		replica.get_on_end_action(),
		false
	)


func _perform_replica_actions(fast_actions: Array, actions: Array, is_start: bool) -> void:
	_perform_fast_actions(fast_actions)
	_perform_slow_actions(actions, is_start)


func _perform_fast_actions(actions: Array) -> void:
	for action in actions:
		if not action:
			push_warning('[Chat] Пропущено пустое быстрое действие')
			continue

		var node_path: String = action.get_path_node()
		var should_activate: bool = action.get_action()

		match action.get_action_type():
			Action.Type.visible:
				if not fast_action:
					push_warning('[Chat] Не выполнено действие видимости \'%s\': FastAction не назначен' % node_path)
					continue
				if should_activate:
					fast_action.show_child(node_path)
				else:
					fast_action.hide_child(node_path)
			Action.Type.sound:
				if not sounds:
					push_warning('[Chat] Не выполнено действие со звуком \'%s\': Sounds не назначен' % node_path)
					continue
				if should_activate:
					sounds.play_sound(node_path)
				else:
					sounds.stop_sound(node_path)
			Action.Type.music:
				if not music:
					push_warning('[Chat] Не выполнено действие с музыкой \'%s\': Music не назначен' % node_path)
					continue
				if should_activate:
					music.play_music(node_path)
				else:
					music.stop_music(node_path)


func _perform_slow_actions(actions: Array, is_start: bool) -> void:
	for action in actions:
		if not action:
			push_warning('[Chat] Пропущено пустое отложенное действие')
			continue

		var node_path: NodePath = NodePath(action.get_path_node())
		var node: Node = get_node_or_null(node_path)
		if not node:
			push_warning('[Chat] Не найден узел для действия: \'%s\'' % node_path)
			continue

		_perform_slow_action(node, action, is_start)


func _perform_slow_action(node: Node, action: Action, is_start: bool) -> void:
	var should_activate = action.get_action()

	match action.get_action_type():
		Action.Type.visible:
			_perform_visibility_action(node, should_activate, is_start)
		_:
			_perform_node_sound_action(node, should_activate)


func _perform_visibility_action(node: Node, should_show: bool, is_start: bool) -> void:
	var handled_by_component = false

	for child in node.get_children():
		if child is LinearVisible:
			handled_by_component = true
			if should_show:
				child.linear_show()
			else:
				child.linear_hide()

	if should_show:
		node.show()
	elif is_start:
		if not handled_by_component:
			node.hide()
	else:
		# Сохраняет прежнее поведение действий конца реплики.
		node.show()


func _perform_node_sound_action(node: Node, should_play: bool) -> void:
	var handled_by_component: bool = false

	for child in node.get_children():
		if child is LinearSound:
			handled_by_component = true
			if should_play:
				child.linear_on()
			else:
				child.linear_off()

	if handled_by_component:
		return

	var method_name: StringName = &'play' if should_play else &'stop'
	if node.has_method(method_name):
		node.call(method_name)
	else:
		push_warning(
			'[Chat] Узел \'%s\' не поддерживает воспроизведение звука: отсутствует метод \'%s\''
			% [node.get_path(), method_name]
		)


func next() -> void:
	if back_button and back_button.is_hovered():
		return

	if (menu and menu.is_visible_in_tree()) or (settings_menu and settings_menu.is_visible_in_tree()):
		return

	if not current_dialog:
		return

	if text != text_buffer:
		text = text_buffer
		return

	index += 1
	if index >= current_dialog.get_dialog_len():
		_finish_dialog()
		return

	if timer:
		timer.start()
	var replica: Replica = current_dialog.get_replica_to_id(index)
	if replica.get_reset_text_buffer():
		text = ''
	set_replica(replica)


func _finish_dialog() -> void:
	index = 0
	dialog_exited.emit(current_dialog)

	if current_dialog.get_next_dialog():
		play_linear_dialog_on_libriary(current_dialog.get_next_dialog())
		return

	if current_dialog.get_dialog_end_type() == LinearDialog.Interpolation.instantaneous:
		hide()
		if behind:
			behind.hide()
		modulate.a = 0
	else:
		_hidding = true

	perform_an_action_end(_last_replica)
	replica_ended.emit(_last_replica)

	if current_dialog.get_next_mini_game():
		if not mini_games_root:
			push_warning('[Chat] Не удалось запустить мини-игру: корневой узел мини-игр не назначен')
		else:
			var mini_game_path: NodePath = NodePath(current_dialog.get_next_mini_game())
			var mini_game: Node = mini_games_root.get_node_or_null(mini_game_path)
			if mini_game and mini_game.has_method('start'):
				mini_game.call('start')
			else:
				push_warning(
					'[Chat] Не найдена мини-игра или отсутствует метод start(): \'%s\''
					% mini_game_path
				)

	current_dialog = null
	if timer:
		timer.stop()


func set_replica(replica: Replica) -> void:
	if not replica:
		push_warning('[Chat] Не удалось установить реплику: ресурс Replica отсутствует')
		return

	if not current_dialog:
		push_warning('[Chat] Не удалось установить реплику: текущий диалог отсутствует')
		return

	if _last_replica:
		perform_an_action_end(_last_replica)
		replica_ended.emit(_last_replica)

	GVisualNovel._write_buffer({
		'scene': Core.scene_tools.get_scene_path(),
		'linear_dialog': current_dialog.get_dialog_name(),
		'index': index,
		'name': name
	}, 'chat')

	GVisualNovel._get_buffer()['history'].append(
		replica.get_behind() + ': ' + replica.get_replica()
	)

	var background_name: String = replica.get_background()
	if not background_name.is_empty():
		if background and background.has_method('background'):
			background.call('background', background_name)
		else:
			var warning_message: String = (
				'[Chat] Не удалось установить фон \'%s\': Backgrounds не назначен '
				+ 'или не поддерживает background()'
			) % background_name
			push_warning(warning_message)

	var sound_name: String = replica.get_sound()
	if not sound_name.is_empty():
		if sounds:
			sounds.play_sound(sound_name)
		else:
			push_warning(
				'[Chat] Не удалось воспроизвести звук \'%s\': Sounds не назначен' % sound_name
			)

	_set_character_emotion(replica)

	_last_replica = replica
	replica_started.emit(replica)

	if behind:
		behind.set_text(replica.get_behind())
	else:
		push_warning('[Chat] Не удалось отобразить имя персонажа: компонент Behind не назначен')

	text_buffer = replica.get_replica()

	var behind_color: Color = replica.get_color()
	if behind_set_alpha_to_self_modulate:
		behind_color.a = modulate.a
	if behind:
		behind.set_color(behind_color)

	var alpha = modulate.a
	if replica.get_chat_color() != Color.BLACK:
		modulate = replica.get_chat_color()
	else:
		modulate = default_color
	modulate.a = alpha

	if replica.get_type_of_interpolation() == Replica.Interpolation.instantaneous:
		_load_text_on_buffer()

	if replica.get_small_text():
		add_theme_font_size_override('font_size', small_text_size)
	else:
		add_theme_font_size_override('font_size', default_text_size)

	if auto_text_swith_timer:
		auto_text_swith_timer.stop()
		auto_text_swith_timer.start(
			len(replica.get_replica().split(' ')) * GVisualNovel.get_automatic_text_switching_speed()
		)

	perform_an_action_start(replica)


func _set_character_emotion(replica: Replica) -> void:
	var emotion: String = replica.get_custom_character_emotion()
	if not emotion:
		emotion = GVisualNovel.get_character_emotion(replica.get_emotion())

	for character in characters:
		if not character:
			continue
		if character.get_character() == replica.get_speaker():
			character.set_emotion(emotion)


func get_len_text() -> int:
	return len(text)
