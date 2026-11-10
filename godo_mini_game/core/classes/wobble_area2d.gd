## Область которую можно перетаскивать мышкой. Во время мини-игры область будет всё время трястись и не будет находится на одном месте
class_name WobbleArea2D extends DraggableArea2D

signal push

@export var max_v: float = 10.0
@export var min_v: float = -10.0

@export var max_push: float = 500
@export var min_push: float = -500

@export var time: float = 5.0
@export var random_time: float = 2.0

@export var active: bool = true


func _ready() -> void:
	super._ready()
	_push()


func _process(delta: float) -> void:
	if not active:
		return
	if not is_visible_in_tree():
		return
	super._process(delta)
	position += Vector2(randi_range(min_v, max_v), randi_range(min_v, max_v))


func _push():
	await get_tree().create_timer(time + randi_range(-random_time, random_time)).timeout
	push.emit()
	if active and is_visible_in_tree():
		position += Vector2(randi_range(min_push, max_push), randi_range(min_push, max_push))
	_push()
