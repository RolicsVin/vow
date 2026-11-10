class_name Action extends Resource

@export var path_node: String
@export var action: bool = false
@export var action_type: GvnEnums.action_types = GvnEnums.action_types.visible
@export var unical_data: Dictionary


func get_path_node() -> String:
	return path_node


func get_action() -> bool:
	return action


func get_action_type() -> GvnEnums.action_types:
	return action_type


func get_unical_data() -> Dictionary:
	return unical_data
