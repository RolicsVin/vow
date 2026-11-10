extends Control

@export var container: VBoxContainer
var is_active: bool = false


func _ready() -> void:
	visibility_changed.connect(showed)


func showed():
	if is_visible_in_tree():
		is_active = false
		on()


func on():
	if is_active:
		off()
		return
	
	is_active = true
	
	show()
	
	for i in container.get_children():
		i.queue_free()
	
	for i in GVN._get_buffer()['history']:
		var text: Label = Label.new()
		text.add_theme_font_override("font", load("res://assets/fonts/Constantine.ttf"))
		text.size.x = container.size.x
		text.size.y = 40
		text.text = i
		container.add_child(text)


func off():
	hide()
	is_active = false
	for i in container.get_children():
		i.queue_free()
