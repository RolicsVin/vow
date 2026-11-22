## Узел управления экранными эффектами и оверлеями. 
## Позволяет показывать и скрывать дочерние узлы CanvasItem. 
class_name Effects extends Control


## Показывает дочерний эффект по указанному пути.
func show_effect(effect_path: NodePath) -> void:
	var effect: CanvasItem = get_node_or_null(effect_path) as CanvasItem
	if effect == null:
		push_warning("Effects: узел '%s' не найден или не является CanvasItem" % effect_path)
		return

	effect.show()


## Скрывает дочерний эффект по указанному пути.
func hide_effect(effect_path: NodePath) -> void:
	var effect: CanvasItem = get_node_or_null(effect_path) as CanvasItem
	if effect == null:
		push_warning("Effects: узел '%s' не найден или не является CanvasItem" % effect_path)
		return

	effect.hide()


## Показывает все дочерние узлы, поддерживающие видимость.
func show_all() -> void:
	for child: Node in get_children():
		if child is CanvasItem:
			child.show()


## Скрывает все дочерние узлы, поддерживающие видимость.
func hide_all() -> void:
	for child: Node in get_children():
		if child is CanvasItem:
			child.hide()
