class_name GTButton extends TextureButton

@export var scene: String

@export var action: String

@export var chat: Chat
@export var dialog_name: String

@export var hidding_on_press: bool = true

@export var animation: AnimationPlayer
@export var blend: float = 0.5

@export var find_animation: bool = true
@export var find_sound: bool = true

@export var sound: GTSound

@export var nodes: Dictionary[Node, bool]

@export var exit_button: bool = false


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	
	if find_animation and not animation:
		for i in get_children():
			if i is AnimationPlayer:
				animation = i
	
	if find_sound and not sound:
		for i in get_children():
			if i is AudioStreamPlayer:
				sound = i
	
	if sound:
		pressed.connect(sound.play)
	
	if hidding_on_press:
		pressed.connect(hide_button)


func show_button() -> void:
	for child in get_children():
		if child is LinearVisible:
			child.linear_show()
	show()


func hide_button() -> void:
	var succes: bool = false
	
	for child in get_children():
		if child is LinearVisible:
			child.linear_hide()
			succes = true
	
	if not succes:
		hide()


func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	
	if action:
		if Input.is_action_just_pressed(action):
			await get_tree().create_timer(0.01).timeout
			pressed.emit()
			_pressed()
	
	if is_hovered():
		if animation:
			animation.play('hovered', 0.5)
	
	else:
		if animation:
			animation.play('state', 0.5)


func _pressed() -> void:
	if not is_visible_in_tree():
		return
	
	for i in nodes:
		if i:
			i.visible = nodes[i]
	
	if chat and dialog_name:
		chat.play_linear_dialog_on_libriary(dialog_name)
	
	if animation:
		animation.play('pressed', 0.5)
		await animation.animation_finished
	
	if scene:
		GodoTools.change_scene(scene)
	
	if exit_button:
		GodoTools.exit_game()
