class_name Music extends Node


func play_music(music_name: String):
	var node = get_node(music_name)
	var success: bool = false
	for child in node.get_children():
		if child is LinearSound:
			success = true
			child.linear_on()
	if not success:
		node.play()


func stop_music(music_name: String):
	var node = get_node(music_name)
	var success: bool = false
	for child in node.get_children():
		if child is LinearSound:
			success = true
			child.linear_off()
	if not success:
		node.stop()
