extends Control

@export var strength: float = 10.0
@export var smoothness: float = 8.0

var start_position: Vector2
var target_position: Vector2


func _ready() -> void:
	start_position = position
	target_position = position


func _process(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	
	# Переводим положение мыши в диапазон от -1 до 1
	var mouse_offset := (mouse_position / viewport_size) * 2.0 - Vector2.ONE
	
	# Целевая позиция объекта
	target_position = start_position + mouse_offset * strength
	
	# Плавное движение
	position = position.lerp(target_position, smoothness * delta)
