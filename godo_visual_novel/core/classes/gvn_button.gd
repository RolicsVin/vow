class_name GVNButton extends GTButton

@export var linear_dialog: String
@export var chat: Chat

@export var combat: Combat
@export var enemy: Entitie


func _pressed() -> void:
	if linear_dialog:
		chat.play_linear_dialog_on_libriary(linear_dialog)
	elif combat:
		if enemy:
			combat.start_combat(combat.player, enemy)
		else:
			combat.start_combat()
