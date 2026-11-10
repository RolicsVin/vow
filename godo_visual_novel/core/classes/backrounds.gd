class_name Backgrounds extends Control

@export var start_bg: CanvasItem
@export var transition_duration: float = 0.5


var current_background: Control
var transition_tween: Tween


func _ready() -> void:
	for child in get_children():
		child.hide()
		child.modulate.a = 0.0
	if start_bg:
		start_bg.modulate = Color.WHITE
		start_bg.show()


func background(background_name: String) -> void:
	var new_background: Control
	
	for child in get_children():
		if child.name == background_name:
			new_background = child
			break
	
	if new_background == null:
		push_warning("Background not found: " + background_name)
		return
	
	# Если это уже активный фон — ничего не делаем
	if new_background == current_background:
		return
	
	# Останавливаем предыдущий переход
	if transition_tween:
		transition_tween.kill()
	
	# Показываем новый фон
	new_background.show()
	new_background.modulate.a = 0.0
	
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	
	# Новый фон проявляется
	transition_tween.tween_property(
		new_background,
		"modulate:a",
		1.0,
		transition_duration
	)
	
	# Старый фон исчезает
	if current_background:
		transition_tween.tween_property(
			current_background,
			"modulate:a",
			0.0,
			transition_duration
	)
	
	# После завершения скрываем старый фон
	transition_tween.chain().tween_callback(func():
		if current_background and current_background != new_background:
			current_background.hide()
	
		current_background = new_background
	)
