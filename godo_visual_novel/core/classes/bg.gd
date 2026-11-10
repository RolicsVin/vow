class_name BG extends TextureRect


@export var anim_name: StringName
@export var anim: AnimationPlayer

@export var video: VideoStreamPlayer
@export var find_video: bool = true


func _ready() -> void:
	visibility_changed.connect(play)
	
	if find_video and not video:
		for i in get_children():
			if i is VideoStreamPlayer:
				video = i
	
	if GvnData.video and video:
		texture = null
		self_modulate.a = 0
		video.show()
		video.play()
		video.modulate = Color.WHITE
	
	elif video:
		video.queue_free()
	
	if not video:
		for i in get_children():
			if i is VideoStreamPlayer:
				i.queue_free()


func play() -> void:
	if is_visible_in_tree():
		if anim:
			anim.play(anim_name)
