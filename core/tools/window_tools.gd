class_name WindowTools extends Node


func take_screenshot() -> Image:
	"""Вернёт скриншот экрана(Image)."""
	var screenshot = get_viewport().get_texture().get_image()
	return screenshot


func get_screen_size() -> Vector2:
	return DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
