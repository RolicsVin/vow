## Область, которую можно перетаскивать мышкой.
class_name DraggableArea2D
extends Area2D

@export var colision: CollisionShape2D
var _is_draging: bool = false
var _is_ready: bool = false

var start_position: Vector2


func _ready() -> void:
	start_position = position
	if not colision.shape is CircleShape2D:
		GodoTools.push_fatal_error('Для DraggableArea2D поддерживается только круглая колизия(CircleShape2D)!')
	await get_tree().create_timer(0.3).timeout
	_is_ready = true


func _process(_delta: float) -> void:
	if not _is_ready:
		return
	if not is_visible_in_tree():
		position = start_position
		return
	if get_global_position().distance_to(get_global_mouse_position()) <= colision.shape.radius and Input.is_action_pressed("left_mouse"):
		_is_draging = true
	else:
		_is_draging = false


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _is_draging:
		position += event.relative
