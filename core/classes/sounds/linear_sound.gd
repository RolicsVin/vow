class_name LinearSound extends Node

@export var speed: float = 50.0
@export var volume_db_reset: float = -70.0

var parent: Node
var on: bool = false
var off: bool = false


func _process(delta: float) -> void:
	if on:
		parent.volume_db = clamp(parent.volume_db + speed * delta, -100, 0)
		if parent.volume_db >= 0:
			on = false
	elif off:
		parent.volume_db = clamp(parent.volume_db - speed * delta, -100, 0)
		if parent.volume_db <= volume_db_reset:
			parent.stop()
			off = false


func linear_on():
	parent = get_parent()
	parent.play()
	parent.volume_db = volume_db_reset
	on = true
	off = false


func linear_off():
	parent = get_parent()
	off = true
	on = false
