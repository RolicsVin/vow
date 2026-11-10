extends GTButton

var _save: Dictionary


func setup(_scene: String, data: String, time: String, icon: Texture2D, save: Dictionary) -> void:
	scene = _scene
	$TextureRect2.texture = icon
	$Date.text = data
	$Time.text = time
	_save = save


func _pressed() -> void:
	Core.load_save(_save)
