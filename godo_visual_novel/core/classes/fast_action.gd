## Выполняет быстрые действия над дочерними узлами интерфейса 
class_name FastAction extends Control


func _ready() -> void:
	show()


## Показывает дочерний узел или запускает его LinearVisible.
func show_child(child_name: String) -> void:
	if child_name.is_empty():
		push_warning('[FastAction] Не указан путь к узлу для отображения')
		return

	if child_name.is_empty():
		push_warning('[FastAction] Не указан путь к узлу для скрытия')
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
func hide_child(child_name: String) -> void:
	var target: Node = get_node_or_null(NodePath(child_name))
	if not target:
		push_warning('[FastAction] Не найден узел для скрытия: \'%s\'' % child_name)
		return

	for child in target.get_children():
		if child is LinearVisible:
			child.linear_hide()
			return
	target.hide()
