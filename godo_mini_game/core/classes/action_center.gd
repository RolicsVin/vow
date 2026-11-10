## Область внутри которйо нужно удерживать [WobbleArea2D] для победы в мини-игре.
class_name ActionCenter extends Area2D

signal started
signal end
signal victory
signal defeat

@export var next: Node
@export var object: WobbleArea2D
@export var counter: float = 10.0
@export var time: float = 10.0

@export var interpolation: GmEnum.types_interpolation = GmEnum.types_interpolation.linear
@export var object_copy_alpha: bool = true

var _is_started: bool = false
var _is_entered: bool = true
var _points: float = 0.0

var _is_showing: bool = false
var _is_hidding: bool = false


func _ready() -> void:
	if next:
		end.connect(next.start)
	end.connect(_end)
	modulate.a = 0
	object.hide()
	hide()
	object.active = false
	area_entered.connect(_on_entered)
	area_exited.connect(_on_exited)


func start():
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 1
	else:
		_is_showing = true
	
	object.show()
	show()
	
	object.active = true
	started.emit()
	_is_started = true
	await get_tree().create_timer(time).timeout
	end.emit()
	
	if _points >= counter:
		victory.emit()
	else:
		defeat.emit()
	
	object.active = false
	_is_started = false

func _process(delta: float) -> void:
	if _is_showing:
		modulate.a = clamp(modulate.a + delta, 0, 1)
		if modulate.a == 1:
			_is_showing = false
	elif _is_hidding:
		modulate.a = clamp(modulate.a - delta, 0, 1)
		if modulate.a == 0:
			_is_hidding = false
			hide()
	
	if _is_entered and _is_started:
		_points += delta
	
	if object_copy_alpha:
		object.modulate.a = modulate.a


func _on_entered(area: Area2D):
	if area == object:
		_is_entered = true


func _on_exited(area: Area2D):
	if area == object:
		_is_entered = false


func _end():
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 0
		object.hide()
		hide()
	else:
		_is_hidding = true
