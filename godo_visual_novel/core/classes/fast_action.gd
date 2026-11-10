class_name FastAction extends Control


func _ready() -> void:
	show()


func show_child(child_name: String):
	for child in get_children():
		if child.name == child_name:
			for i in child.get_children():
				if i is LinearVisible:
					i.linear_show()
					return
			child.show()


func hide_child(child_name: String):
	for child in get_children():
		if child.name == child_name:
			for i in child.get_children():
				if i is LinearVisible:
					i.linear_hide()
					return
			child.hide()
