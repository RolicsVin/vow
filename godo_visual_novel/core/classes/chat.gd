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
@export var text_speed: float = GvnData.text_speed

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
	if not default_text_size:
		default_text_size = get_theme_font_size("font_size")
	if not small_text_size:
		small_text_size = int(default_text_size / 1.5)
	
	if auto_text_swith_timer:
		#auto_text_swith_timer.one_shot = true
		auto_text_swith_timer.timeout.connect(next)
	
	hide()
	behind.hide()
	
	if back_button:
		back_button.pressed.connect(chat_back)
	
	timer.wait_time = text_speed
	timer.timeout.connect(_load_symbol_on_byffer)
	autowrap_mode = TextServer.AUTOWRAP_WORD
	
	modulate = default_color
	
	for dialog in dialog_tree:
		if not dialog.get_dialog_name():
			GodoTools.push_fatal_error('У линейного диалога отсутствует имя!')
	
	# Если у реплики установлет тип интерполяции "Родитель", то устанавливаем интерполяцию от родителя
	for linear_dialog in dialog_tree:
		for replica in linear_dialog.get_replicas():
			if replica.get_type_of_interpolation() == GvnEnums.types_of_interpolation.parent:
				replica.type_of_interpolation = linear_dialog.get_interpolation()
	
	await get_tree().create_timer(0.5).timeout
	
	if is_loading:
		return
	
	if linear_dialog_play_ready:
		play_linear_dialog_on_libriary(linear_dialog_play_ready, pos)


func chat_back():
	if current_dialog:
		index -= 1
		text = current_dialog.get_replica_to_id(index).get_replica()
		text_buffer = text


func load_save_on_buffer() -> void:
	var buffer = GVN._get_buffer()
	if 'chat' in buffer:
		is_loading = true
		var save = buffer['chat']
		if name == save['name'] and save['scene'] == GodoTools.get_scene_path():
			play_linear_dialog_on_libriary(save['linear_dialog'], save['index'])


func _process(delta: float) -> void:
	if visible:
		modulate.a = clamp(modulate.a + show_speed * delta, 0, 1)
	else:
		modulate.a = 0
	
	if behind_set_alpha_to_self_modulate:
		behind.modulate.a = modulate.a
	
	if _hidding:
		modulate.a = clamp(modulate.a - delta, 0, 1)
		if modulate.a <= 0:
			behind.hide()
			hide()
			_hidding = false


func _load_text_on_buffer():
	text = text_buffer


func _load_symbol_on_byffer():
	if text == text_buffer:
		timer.stop()
		return
	text = text_buffer.substr(0, len(text) + 1)


func play_linear_dialog_on_libriary(dialog_name: String, idx: int = 0):
	show()
	behind.show()
	timer.start()
	auto_text_swith_timer.start()
	index = idx
	current_dialog = get_linear_dialog(dialog_name)
	
	if current_dialog.get_dialog_start_type() == GvnEnums.types_of_linear_dialog_interpolation.instantaneous:
		modulate = default_color
	
	set_replica(current_dialog.get_replica_to_id(index))
	dialog_entered.emit(current_dialog)


func load_linear_dialog_in_libriary(linear_dialog: LinearDialog):
	if linear_dialog.dialog_name:
		dialog_tree.append(linear_dialog)
	else:
		GodoTools.push_fatal_error('У линейного диалога отсутствует имя!')


func play_linear_dialog(linear_dialog: LinearDialog, idx: int = 0):
	index = idx
	show()
	behind.show()
	timer.start()
	current_dialog = linear_dialog
	
	if current_dialog.get_dialog_start_type() == GvnEnums.types_of_linear_dialog_interpolation.instantaneous:
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
	# быстрое дейтсвие
	for action_fast_last in replica.get_on_start_fast_action(): # основной цикл
		if action_fast_last.get_action(): # если action true
			# проверки на типы и действия
			if action_fast_last.get_action_type() == GvnEnums.action_types.visible:
				fast_action.show_child(action_fast_last.get_path_node())
			elif action_fast_last.get_action_type() == GvnEnums.action_types.sound:
				sounds.play_sound(action_fast_last.get_path_node())
			else:
				music.play_music(action_fast_last.get_path_node())
		else: # если action false
			# проверки на типы и действия
			if action_fast_last.get_action_type() == GvnEnums.action_types.visible:
				fast_action.hide_child(action_fast_last.get_path_node())
			elif action_fast_last.get_action_type() == GvnEnums.action_types.sound:
				sounds.stop_sound(action_fast_last.get_path_node())
			else:
				music.stop_music(action_fast_last.get_path_node())
	
	# медленное действие
	for action_last in replica.get_on_start_action():
		var node = get_node(action_last.get_path_node())
		if action_last.get_action(): # если action true
			# проверки на типы и действия
			if action_last.get_action_type() == GvnEnums.action_types.visible:
				for child in node.get_children():
					if child is LinearVisible:
						child.linear_show()
						continue
				node.show()
			elif action_last.get_action_type() == GvnEnums.action_types.sound:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_on()
				if not success:
					node.play()
			else:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_on()
				if not success:
					node.play()
		else:
			# проверки на типы и действия
			if action_last.get_action_type() == GvnEnums.action_types.visible:
				var success: bool = false
				for child in node.get_children():
					if child is LinearVisible:
						success = true
						child.linear_hide()
						continue
				if not success:
					node.hide()
			elif action_last.get_action_type() == GvnEnums.action_types.sound:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_off()
				if not success:
					node.stop()
			else:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_off()
				if not success:
					node.stop()


func perform_an_action_end(replica: Replica):
	# быстрое дейтсвие
	for action_fast_last in replica.get_on_end_fast_action(): # основной цикл
		if action_fast_last.get_action(): # если action true
			# проверки на типы и действия
			if action_fast_last.get_action_type() == GvnEnums.action_types.visible:
				fast_action.show_child(action_fast_last.get_path_node())
			elif action_fast_last.get_action_type() == GvnEnums.action_types.sound:
				sounds.play_sound(action_fast_last.get_path_node())
			else:
				music.play_music(action_fast_last.get_path_node())
		else: # если action false
			# проверки на типы и действия
			if action_fast_last.get_action_type() == GvnEnums.action_types.visible:
				fast_action.hide_child(action_fast_last.get_path_node())
			elif action_fast_last.get_action_type() == GvnEnums.action_types.sound:
				sounds.stop_sound(action_fast_last.get_path_node())
			else:
				music.stop_music(action_fast_last.get_path_node())
	
	# медленное действие
	for action_last in replica.get_on_end_action():
		var node = get_node(action_last.get_path_node())
		if action_last.get_action(): # если action true
			# проверки на типы и действия
			if action_last.get_action_type() == GvnEnums.action_types.visible:
				for child in node.get_children():
					if child is LinearVisible:
						child.linear_show()
						continue
				node.show()
			elif action_last.get_action_type() == GvnEnums.action_types.sound:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_on()
				if not success:
					node.play()
			else:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_on()
				if not success:
					node.play()
		else:
			# проверки на типы и действия
			if action_last.get_action_type() == GvnEnums.action_types.visible:
				for child in node.get_children():
					if child is LinearVisible:
						child.linear_hide()
						continue
				node.show()
			elif action_last.get_action_type() == GvnEnums.action_types.sound:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_off()
				if not success:
					node.stop()
			else:
				var success: bool = false
				for child in node.get_children():
					if child is LinearSound:
						success = true
						child.linear_off()
				if not success:
					node.stop()


func next() -> void:
	if back_button.is_hovered():
		return
	
	if menu.is_visible_in_tree() or settings_menu.is_visible_in_tree():
		# Если включено меню или настройки то диалог не пойдёт дальше, пока игрок не закроет их
		return
	
	if not current_dialog:
		return
	
	if text != text_buffer:
		text = text_buffer
		return
	
	index += 1
	if index >= current_dialog.get_dialog_len():
		index = 0
		dialog_exited.emit(current_dialog)
		
		if current_dialog.get_next_dialog():
			play_linear_dialog_on_libriary(current_dialog.get_next_dialog())
			return
		
		if current_dialog.get_dialog_end_type() == GvnEnums.types_of_linear_dialog_interpolation.instantaneous:
			hide()
			behind.hide()
			modulate.a = 0
		else:
			_hidding = true
		
		perform_an_action_end(_last_replica)
		
		replica_ended.emit(_last_replica)
		
		if current_dialog.get_next_mini_game():
			mini_games_root.get_node(current_dialog.get_next_mini_game()).start()
		
		current_dialog = null
		timer.stop()
		
		# current_dialog был выгружен выше. ОБРАТИТЕ ВНИМАНИЕ! НЕ НАДО ТУТ ПИСАТЬ ЛОГИКУ, СВЯЗАННУЮ С ОКОНЧАНИЕМ ДИАЛОГА, ПИШИТЕ ЕЁ ВЫШЕ
		
		return
	
	if index < current_dialog.get_dialog_len():
		timer.start()
		if current_dialog.get_replica_to_id(index).get_reset_text_buffer():
			text = ''
		set_replica(current_dialog.get_replica_to_id(index))


func set_replica(replica: Replica):
	if _last_replica:
		perform_an_action_end(_last_replica)
		replica_ended.emit(_last_replica)
	
	GVN._write_buffer({
		'scene': GodoTools.get_scene_path(),
		'linear_dialog': current_dialog.get_dialog_name(),
		'index': index,
		'name': name}, 'chat')
	
	GVN._get_buffer()['history'].append(replica.get_behind() + ': ' + replica.get_replica())
	
	if replica.get_background():
		background.background(replica.get_background())
	if replica.get_sound():
		sounds.play_sound(replica.get_sound())
	
	# эмоция у персонажа
	if replica.get_custom_character_emotion():
		for character in characters:
			if character.get_character() == replica.get_speaker():
				character.set_emotion(replica.get_custom_character_emotion())
	else:
		for character in characters:
			if character.get_character() == replica.get_speaker():
				character.set_emotion(GvnData.character_emotion_protection[replica.get_emotion()])
	
	_last_replica = replica
	replica_started.emit(replica)
	
	behind.set_text(replica.get_behind())
	
	text_buffer = replica.get_replica()
	
	var behind_color = replica.get_color()
	if behind_set_alpha_to_self_modulate:
		behind_color.a = modulate.a
	behind.set_color(behind_color)
	
	var alpha = modulate.a
	if replica.get_chat_color() != Color.BLACK:
		modulate = replica.get_chat_color()
		modulate.a = alpha
	else:
		modulate = default_color
		modulate.a = alpha
	
	if replica.get_type_of_interpolation() == GvnEnums.types_of_interpolation.instantaneous:
		_load_text_on_buffer()
	
	if replica.get_small_text():
		add_theme_font_size_override("font_size", small_text_size)
	else:
		add_theme_font_size_override("font_size", default_text_size)
	
	auto_text_swith_timer.stop()
	auto_text_swith_timer.start(len(replica.get_replica().split(" ")) * GvnData.automatic_text_switching_speed)
	
	perform_an_action_start(replica)

func get_len_text() -> int:
	return len(text)
