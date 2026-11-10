class_name GTTools extends Node


func read_lines(path: String) -> Array[String]: ## Аналог read_lines из python. Прочитает файл и вернёт список из строк
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	
	var lines: Array[String] = []
	
	while not file.eof_reached():
		lines.append(file.get_line())
	
	return lines


func chance(percent: float) -> bool: ## Вернёт true с заданной вероятностью, иначе false
	return randf() * 100.0 < percent
