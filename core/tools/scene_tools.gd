class_name SceneTools extends Node

const SAVE_PATH: String = 'user://'


func get_scene_path() -> String: ## Выдаст путь до текущей сцены.
	return get_tree().current_scene.scene_file_path


func _reload_current_scene() -> void: ## Перезапустит текущую сцену.
	get_tree().change_scene_to_file(get_scene_path())
