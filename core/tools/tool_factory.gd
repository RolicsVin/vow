## Фабрика вспомогательных узлов, создаваемых из скриптов.
class_name ToolFactory extends RefCounted


## Создаёт экземпляр скрипта, задаёт имя и добавляет его к родителю.
static func make_tool(parent: Node, path: String, tool_name: String) -> Node:
	var node: Node = load(path).new()
	node.name = tool_name
	parent.add_child(node)
	return node
