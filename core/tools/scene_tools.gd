class_name SceneTools extends Node


func get_scene_path() -> String: ## Выдаст путь до текущей сцены.
	return get_tree().current_scene.scene_file_path


func change_scene(scene_path: String):
	get_tree().change_scene_to_file(scene_path)


func _reload_current_scene() -> void: ## Перезапустит текущую сцену.
	get_tree().change_scene_to_file(get_scene_path())
