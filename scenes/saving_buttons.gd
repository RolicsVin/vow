extends VBoxContainer

var button_packed = preload("res://assets/ui/save_button.tscn")


func _ready() -> void:
	for save_file_name: String in Core.get_saves():
		var save: Dictionary = Core.get_save(save_file_name)
		var button = button_packed.instantiate()
		button.setup(save['scene'], save['data'], save['time'], ImageTexture.create_from_image(save['icon']), save)
		add_child(button)
