## Узел управления экранными эффектами и оверлеями. 
## Позволяет показывать и скрывать дочерние узлы CanvasItem. 
class_name EffectsShaders extends Control


## Показывает дочерний эффект по указанному пути.
func show_effect(effect_path: NodePath, is_slow: bool = false) -> void:
	var effect: CanvasItem = _get_effect(effect_path)
	if effect == null:
		return

	var linear_visible: LinearVisible = _get_linear_visible(effect)
	if is_slow and linear_visible:
		linear_visible.linear_show()
	else:
		effect.show()


## Скрывает дочерний эффект по указанному пути.
func hide_effect(effect_path: NodePath, is_slow: bool = false) -> void:
	var effect: CanvasItem = _get_effect(effect_path)
	if effect == null:
		return

	var linear_visible: LinearVisible = _get_linear_visible(effect)
	if is_slow and linear_visible:
		linear_visible.linear_hide()
	else:
		effect.hide()


## Находит эффект по пути и проверяет его тип.
func _get_effect(effect_path: NodePath) -> CanvasItem:
	if effect_path.is_empty():
		push_warning('[EffectsShaders] Не указан путь к эффекту')
		return null

	var effect: CanvasItem = get_node_or_null(effect_path) as CanvasItem
	if effect == null:
		push_warning(
			"[EffectsShaders] Узел '%s' не найден или не является CanvasItem" % effect_path
		)
	return effect


## Находит компонент LinearVisible у эффекта.
func _get_linear_visible(effect: CanvasItem) -> LinearVisible:
	for child: Node in effect.get_children():
		if child is LinearVisible:
			return child

	return null


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
