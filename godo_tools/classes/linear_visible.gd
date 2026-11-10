class_name LinearVisible extends Node

@export var speed: float = 1.0
@export var _showing: bool = false
@export var _hidding: bool = false


func linear_show() -> void:
	_showing = true
	_hidding = false
	get_parent().modulate.a = 0
	get_parent().show()
	get_parent().show()


func linear_hide() -> void:
	_showing = false
	_hidding = true


func _process(delta: float) -> void:
	if _showing:
		get_parent().modulate.a = clamp(get_parent().modulate.a + speed * delta, 0, 1)
		if get_parent().modulate.a == 1:
			_showing = false
	if _hidding:
		get_parent().modulate.a = clamp(get_parent().modulate.a - speed * delta, 0, 1)
		if get_parent().modulate.a == 0:
			_hidding = false
			get_parent().hide()
