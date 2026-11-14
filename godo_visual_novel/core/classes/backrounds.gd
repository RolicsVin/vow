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
		if start_bg is Control:
			current_background = start_bg
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

	# Если выбранный фон уже единственный активный — переход не требуется
	if new_background == current_background:
		var has_extra_backgrounds: bool = false
		for child in get_children():
			if child is CanvasItem and child != new_background and child.visible:
				has_extra_backgrounds = true
				break

		if not has_extra_backgrounds:
			return

	# Останавливаем предыдущий переход, который мог оставить фоны полупрозрачными
	if is_instance_valid(transition_tween) and transition_tween.is_running():
		transition_tween.kill()

	# Показываем выбранный фон и плавно проявляем его
	new_background.show()

	transition_tween = create_tween()
	transition_tween.set_parallel(true)

	var duration: float = maxf(transition_duration, 0.0)

	transition_tween.tween_property(
		new_background,
		"modulate:a",
		1.0,
		duration
	)

	# Одновременно скрываем все остальные фоны, включая оставшиеся от прерванных переходов
	for child in get_children():
		if child is CanvasItem and child != new_background:
			transition_tween.tween_property(
				child,
				"modulate:a",
				0.0,
				duration
			)

	# После перехода принудительно скрываем все лишние фоны
	var background_to_show: Control = new_background
	transition_tween.chain().tween_callback(func():
		for child in get_children():
			if child is CanvasItem:
				if child == background_to_show:
					child.modulate.a = 1.0
					child.show()
				else:
					child.modulate.a = 0.0
					child.hide()

		current_background = background_to_show
	)
