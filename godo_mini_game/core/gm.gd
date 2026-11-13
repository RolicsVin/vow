extends Node

var _buffer: Dictionary = {}


func _print_log() -> void:
	print("Печатает служба GMiniGame. (g_mimi_game.gd)-----------------------------------------------")


func _end_log() -> void:
	print("------------------------------------------------------------------------------------------")
	print()


## Возвращает и выводит сохранение состояния модуля.
func get_save() -> Dictionary:
	_print_log()
	print('Собирается сохранение')
	var save := _buffer.duplicate(true)
	
	print('Сохранение собрано:')
	var response: Dictionary = await PythonBridge.call_function("stdout", "pretty_print", [save])
	if response.get("ok", false):
		print(response.get("result", ""))
	else:
		push_error("[GminiGame] Не удалось вывести сохранение через PythonBridge: %s" % response.get("error", "unknown error"))
	
	_end_log()
	
	return save


## Восстанавливает состояние модуля из сохранения.
func load_save(save: Dictionary) -> void:
	_print_log()
	print('loading...')
	_buffer = save.duplicate(true)
	print('loaded:')
	var response: Dictionary = await PythonBridge.call_function('stdout', 'pretty_print', [save])
	if response.get("ok", false):
		print(response.get("result", ""))
	else:
		push_error("[Core] Не удалось вывести сохранение через PythonBridge: %s" % response.get("error", "unknown error"))
	_end_log()


func _get_obj_on_buffer(k):
	"""Вернёт объект из буфера по ключу."""
	return _buffer[k]


func _get_buffer() -> Dictionary:
	"""Вернёт буффер модуля godo_visual_novel."""
	return _buffer


func _write_buffer(obj, k) -> void:
	"""Допишет в буфер информацию по ключу. Если ключ уже существует, то информация будет перезаписана."""
	_buffer[k] = obj
