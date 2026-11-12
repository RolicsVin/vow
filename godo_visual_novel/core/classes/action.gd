class_name Action extends Resource


enum Type {visible, sound, music}

@export var path_node: String
@export var action: bool = false
@export var action_type: Action.Type = Action.Type.visible
@export var unical_data: Dictionary


func get_path_node() -> String:
	return path_node


func get_action() -> bool:
	return action


func get_action_type() -> Action.Type:
	return action_type


func get_unical_data() -> Dictionary:
	return unical_data
