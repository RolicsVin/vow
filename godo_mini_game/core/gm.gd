extends Node

var _buffer: Dictionary = {}


## Возвращает и выводит сохранение состояния модуля.
func get_save() -> Dictionary:
	var save := _buffer.duplicate(true)
	
	print("[GM] Сохранение модуля:")
	var response: Dictionary = await PythonBridge.call_function("stdout", "pretty_print", [save])
	if response.get("ok", false):
		print(response.get("result", ""))
	else:
		push_error("[GM] Не удалось вывести сохранение через PythonBridge: %s" % response.get("error", "unknown error"))
	
	return save


func _get_obj_on_buffer(k):
	"""Вернёт объект из буфера по ключу."""
	return _buffer[k]


func _get_buffer() -> Dictionary:
	"""Вернёт буффер модуля godo_visual_novel."""
	return _buffer


func _write_buffer(obj, k) -> void:
	"""Допишет в буфер информацию по ключу. Если ключ уже существует, то информация будет перезаписана."""
	_buffer[k] = obj
