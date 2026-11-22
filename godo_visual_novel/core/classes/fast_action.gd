## Выполняет быстрые действия над дочерними узлами интерфейса 
class_name FastAction extends Control


@export var effects: Effects


func _ready() -> void:
	show()


## Показывает дочерний узел или запускает его LinearVisible.
func show_child(child_name: String):
	if child_name.is_empty():
		push_warning('[FastAction] Не указан путь к узлу для отображения')
		return

	var target: Node = get_node_or_null(NodePath(child_name))
	if not target:
		push_warning('[FastAction] Не найден узел для отображения: \'%s\'' % child_name)
		return

	for child in target.get_children():
		if child is LinearVisible:
			child.linear_show()
			return
	target.show()


## Скрывает дочерний узел или запускает его LinearVisible.
func hide_child(child_name: String):
	if child_name.is_empty():
		push_warning('[FastAction] Не указан путь к узлу для скрытия')
		return

	var target: Node = get_node_or_null(NodePath(child_name))
	if not target:
		push_warning('[FastAction] Не найден узел для скрытия: \'%s\'' % child_name)
		return

	for child in target.get_children():
		if child is LinearVisible:
			child.linear_hide()
			return
	target.hide()


## Показывает эффект по пути относительно компонента Effects.
func show_effect(effect_path: String) -> void:
	if not effects:
		push_warning('[FastAction] Компонент Effects не назначен')
		return

	if effect_path.is_empty():
		push_warning('[FastAction] Не указан путь к эффекту для отображения')
		return

	effects.show_effect(NodePath(effect_path))


## Скрывает эффект по пути относительно компонента Effects.
func hide_effect(effect_path: String) -> void:
	if not effects:
		push_warning('[FastAction] Компонент Effects не назначен')
		return

	if effect_path.is_empty():
		push_warning('[FastAction] Не указан путь к эффекту для скрытия')
		return

	effects.hide_effect(NodePath(effect_path))
