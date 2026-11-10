## Мини игра 
class_name MiniGame extends Control

signal victory
signal defeat
signal end

@export var start_on_ready: bool = false

@export var chat: Chat

@export var dialog: String
@export var dialog_defeat: String
@export var dialog_victory: String

@export var elements_root: Node = self
@export var start_element: Node
@export var end_element: Node

@export var victory_count: int = 0

var _victory_counter = 0


func _ready() -> void:
	hide()
	if not dialog_defeat:
		dialog_defeat = dialog
	if not dialog_victory:
		dialog_victory = dialog
	for child in elements_root.get_children():
		if child.has_signal('victory'):
			child.victory.connect(add_victory)
	
	if start_on_ready:
		start()


func add_victory() -> void:
	_victory_counter += 1


func start() -> void:
	for child in get_children():
		if child is LinearVisible:
			child.linear_show()
	show()
	
	_victory_counter = 0
	
	if start_element:
		start_element.start()
	else:
		get_children()[0].start()
	
	await end_element.end
	
	if _victory_counter >= victory_count:
		victory.emit()
		if chat:
			chat.play_linear_dialog_on_libriary(dialog_victory)
	else:
		defeat.emit()
		if chat:
			chat.play_linear_dialog_on_libriary(dialog_defeat)
	end.emit()
	
	_victory_counter = 0
	
	for child in get_children():
		if child is LinearVisible:
			child.linear_hide()
			return
	hide()
