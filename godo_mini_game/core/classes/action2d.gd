## Область по которйо нужно вести для победы в игре
class_name Action2D extends Marker2D

signal started
signal end
signal victory
signal defeat

@export var next: Node
@export var next_dialog: String


@export var start_on_ready: bool = false
@export var time: float = 1.0
@export var object: DraggableArea2D
@export var path: Area2D
@export var end_point: Area2D
@export var interpolation: GmEnum.types_interpolation = GmEnum.types_interpolation.linear

var _has_victory: bool = false
var _play: bool = false

var _is_showing: bool = false
var _is_hidding: bool = false


func _ready() -> void:
	if next is Chat:
		end.connect(next.play_linear_dialog_on_libriary(next_dialog))
	elif next:
		end.connect(next.start)
	end.connect(_end)
	hide()
	modulate.a = 0
	end_point.area_entered.connect(_victory)
	path.area_exited.connect(_exit_path)
	if start_on_ready:
		start()


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


func start():
	show()
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 1
	else:
		_is_showing = true
	_play = true
	started.emit()
	await get_tree().create_timer(time).timeout
	if not _has_victory:
		_defeat()


func _exit_path(area: Area2D):
	"""Обьект покинул допустимую область"""
	if area == object:
		_has_victory = false
		_defeat()


func _victory(area: Area2D):
	if not _play:
		return
	if area == object:
		_has_victory = true
		victory.emit()
		end.emit()
		_play = false


func _defeat():
	if not _play:
		return
	_play = false
	end.emit()
	defeat.emit()


func _end():
	if interpolation == GmEnum.types_interpolation.instantaneous:
		modulate.a = 0
		hide()
	else:
		_is_hidding = true
