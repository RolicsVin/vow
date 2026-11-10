## кнопка, которую нужно нажимать, для победы в мини игре.
class_name ButtonAction extends TextureButton

signal started
signal end
signal victory
signal defeat

@export var next: Node
@export var action: String
@export var counter: int = 1
@export var time: float = 1.0

@export var texture_button: TextureRect

@export var interpolation: GmEnum.types_interpolation = GmEnum.types_interpolation.linear

var _clicked: int = 0
var _is_started: bool = false

var _is_showing: bool = false
var _is_hidding: bool = false


func _ready() -> void:
	if next:
		end.connect(next.start)
	modulate.a = 0
	end.connect(_end)
	hide()
	pressed.connect(_pressed)


func _process(delta: float) -> void:
	if _is_showing:
		modulate.a = clamp(modulate.a + delta, 0, 1)
		if modulate.a == 1:
			_is_showing = false
	elif _is_hidding:
		modulate.a = clamp(modulate.a - delta, 0, 1)
		if modulate.a == 0:
			_is_hidding = false
			hide()
	
	if not _is_started:
		return
	if action:
		if Input.is_action_just_pressed(action):
			_clicked += 1
	if _clicked >= counter:
		_is_started = false
		end.emit()
		victory.emit()
	if not button_pressed:
		texture_button.texture = texture_pressed


func _pressed() -> void:
	texture_button.texture = texture_normal
	button_pressed = true
	_clicked += 1


func start() -> void:
	print('123')
	if _is_started:
		return
	
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 1
	else:
		_is_showing = true
	
	_is_started = true
	show()
	started.emit()
	
	await get_tree().create_timer(time).timeout
	
	_is_started = false
	if _clicked < counter:
		end.emit()
		defeat.emit()


func _end():
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 0
		hide()
	else:
		_is_hidding = true
