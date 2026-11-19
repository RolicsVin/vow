extends RefCounted
## Interface that every backend implements. Messages are the dictionaries
## described in py/bridge_worker.py (type: ready / log / response / fatal).

signal message_received(msg: Dictionary)
signal exited()


func start(_worker_dir: String, _script_dirs: PackedStringArray) -> bool:
	return false


func send(_msg: Dictionary) -> void:
	pass


## Вызывается из основного потока каждый кадр и во время синхронного ожидания ответа.
func process() -> void:
	pass


func stop() -> void:
	pass
