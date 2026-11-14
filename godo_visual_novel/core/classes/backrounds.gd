class_name Backgrounds extends Control

@export var start_bg: CanvasItem
@export var transition_duration: float = 0.5


var current_background: Control
var transition_tween: Tween


func _ready() -> void:
	for child in get_children():
		if not child is CanvasItem:
			push_warning(
				"[Backgrounds] Дочерний узел '%s' не является CanvasItem и не может "
				+ "использоваться как фон" % child.name
			)
			continue

		child.hide()
		child.modulate.a = 0.0

	if is_instance_valid(start_bg):
		start_bg.modulate = Color.WHITE
		start_bg.show()
	else:
		push_warning("[Backgrounds] Стартовый фон start_bg не назначен")


func background(background_name: String) -> void:
	if background_name.is_empty():
		push_warning("[Backgrounds] Не указано имя фона")
		return

	var new_background: Control

	for child in get_children():
		if child.name == background_name:
			if child is Control:
				new_background = child
			else:
				push_warning(
					"[Backgrounds] Узел '%s' найден, но не является Control" % background_name
				)
				return
			break

	if not is_instance_valid(new_background):
		push_warning("[Backgrounds] Фон '%s' не найден среди дочерних узлов" % background_name)
		return

	# Если это уже активный фон — ничего не делаем.
	if new_background == current_background:
		return

	# Останавливаем предыдущий переход.
	if is_instance_valid(transition_tween) and transition_tween.is_running():
		transition_tween.kill()

	# Показываем новый фон.
	new_background.show()
	new_background.modulate.a = 0.0

	transition_tween = create_tween()
	transition_tween.set_parallel(true)

	# Новый фон проявляется.
	transition_tween.tween_property(
		new_background,
		"modulate:a",
		1.0,
		maxf(transition_duration, 0.0)
	)

	# Старый фон исчезает.
	if is_instance_valid(current_background):
		transition_tween.tween_property(
			current_background,
			"modulate:a",
			0.0,
			maxf(transition_duration, 0.0)
		)

	# После завершения скрываем старый фон.
	transition_tween.chain().tween_callback(func():
		if is_instance_valid(current_background) and current_background != new_background:
			current_background.hide()

		current_background = new_background
	)
