extends Control

@onready var screen_option: OptionButton = $Root/Window/MonitorNumber/OptionButton
@onready var window_option: OptionButton = $Root/Window/WindowMode/OptionButton
@export var post_process: ColorRect


func _ready() -> void:
	# Экраны
	var screen_count := DisplayServer.get_screen_count()
	
	for i in range(screen_count):
		screen_option.add_item("Экран " + str(i + 1))
		
	screen_option.selected = DisplayServer.window_get_current_screen()
	screen_option.item_selected.connect(_on_screen_selected)
	
	
	# Режим окна
	#window_option.add_item("Полноэкранный")
	#window_option.add_item("Оконный")
	
	var mode := DisplayServer.window_get_mode()
	
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
	or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		window_option.selected = 0
	else:
		window_option.selected = 1
	
	window_option.item_selected.connect(_on_window_mode_selected)


func _on_screen_selected(index: int) -> void:
	var was_fullscreen := _is_fullscreen()
	
	if was_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	DisplayServer.window_set_current_screen(index)
	
	if was_fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_window_mode_selected(index: int) -> void:
	if index == 0:
		# Полноэкранный
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	
	elif index == 1:
		# Оконный
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _is_fullscreen() -> bool:
	var mode := DisplayServer.window_get_mode()
	
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _on_vsync_item_selected(index: int) -> void:
	if index == 1:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _on_noise_value_changed(value: float) -> void:
	GodoTools._get_buffer()['noise_intensity'] = value / 100
	post_process._ready()
