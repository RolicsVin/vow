extends ColorRect

@export var hidding: bool = true


func _ready() -> void:
	if hidding:
		show()
		$LinearVisible.linear_hide()
	else:
		$LinearVisible.linear_show()
