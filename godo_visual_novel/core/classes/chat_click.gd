class_name ChatClick extends Control


@export var chat: Chat
@export var actions: Array[String]


func _ready() -> void:
	show()
	gui_input.connect(_on_gui_input)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if chat:
				chat.next()


func _process(_d: float):
	for i in actions:
		if Input.is_action_just_pressed(i):
			chat.next()
