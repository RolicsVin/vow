extends ScrollContainer


func start():
	$"../ColorRect/AnimationPlayer".play("start")
	await  $"../ColorRect/AnimationPlayer".animation_finished
	show()
	


func end():
	$"../ColorRect/AnimationPlayer".play("end")
	await  $"../ColorRect/AnimationPlayer".animation_finished
	hide()
