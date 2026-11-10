extends Control

var last_space_press: int = 0
const SAVE_BLOCK_TIME := 200 # миллисекунд


func _ready() -> void:
	$Illustrations.show()
	$MiniGamesRoot.show()
	$ChatRoot/Chat.load_save_on_buffer()


func _on_save_button_pressed() -> void:
	
	var current_time := Time.get_ticks_msec()
	
	if current_time - last_space_press < SAVE_BLOCK_TIME:
		return
	
	Core.save()
	$ChatRoot/Control/HBoxContainer/Menu/GTSound.play()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("space"):
		last_space_press = Time.get_ticks_msec()
