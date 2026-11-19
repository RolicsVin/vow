@tool
extends EditorContextMenuPlugin
## Adds "Python Script..." to FileSystem dock -> right click -> Create New.

var _on_create: Callable  # func(dir: String)


func _init(on_create: Callable) -> void:
	_on_create = on_create


func _popup_menu(_paths: PackedStringArray) -> void:
	var icon: Texture2D = null
	var theme := EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon("Script", "EditorIcons"):
		icon = theme.get_icon("Script", "EditorIcons")
	add_context_menu_item("Python Script...", _on_item, icon)


func _on_item(paths: PackedStringArray) -> void:
	_on_create.call(_target_dir(paths))


## The slot may pass the folder or a selected file; always resolve to a folder.
func _target_dir(paths: PackedStringArray) -> String:
	var path := "res://" if paths.is_empty() else paths[0]
	if path.is_empty():
		return "res://"
	if DirAccess.dir_exists_absolute(path):
		return path
	return path.get_base_dir()
