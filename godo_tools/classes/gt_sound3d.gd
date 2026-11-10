class_name GTSound3D extends AudioStreamPlayer3D

@export var sound_type: GtEnums.sound_type = GtEnums.sound_type.SOUND


func _ready() -> void:
	match sound_type:
		GtEnums.sound_type.CHARACTER:
			volume_db += GtData.data[GtEnums.sound_type.CHARACTER]
		
		GtEnums.sound_type.SOUND:
			volume_db += GtData.data[GtEnums.sound_type.SOUND]
		
		GtEnums.sound_type.MUSIC:
			volume_db += GtData.data[GtEnums.sound_type.MUSIC]
		
		GtEnums.sound_type.OTHER:
			volume_db += GtData.data[GtEnums.sound_type.OTHER]
