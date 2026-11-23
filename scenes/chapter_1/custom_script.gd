extends Node


func _on_chat_replica_started(replica: Replica) -> void:
	if replica.get_unical_id() == 'rainhome':
		$"../Sounds/Rain".stop()
		$"../Sounds/RainCompressed".volume_db = 0
