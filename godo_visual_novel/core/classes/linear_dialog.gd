class_name LinearDialog extends Resource


enum Interpolation {instantaneous, linear}

@export var dialog_name: String
@export var replicas: Array[Replica]


@export_group('next')
@export var next_dialog: String
@export var mini_game: String

@export_group('interpoliation')
@export var type_of_interpolation: Replica.Interpolation = Replica.Interpolation.linear
@export var type_of_start: LinearDialog.Interpolation = LinearDialog.Interpolation.linear
@export var type_of_end: LinearDialog.Interpolation = LinearDialog.Interpolation.linear


func get_replicas() -> Array[Replica]:
	return replicas


func get_dialog_name() -> String:
	return dialog_name


func get_dialog_start_type() -> LinearDialog.Interpolation:
	return type_of_start


func get_dialog_end_type() -> LinearDialog.Interpolation:
	return type_of_end


func get_repcica_to_unical_id(unical_id: String):
	for replica in replicas:
		if replica.get_unical_id() == unical_id:
			return replica


func get_replica_to_id(id: int):
	return replicas[id]


func get_next_dialog() -> String:
	return next_dialog


func get_next_mini_game() -> String:
	return mini_game


func get_dialog_len() -> int:
	return len(replicas)


func get_interpolation() -> Replica.Interpolation:
	return type_of_interpolation
