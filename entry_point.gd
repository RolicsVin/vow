## Скрипт: точка входа во всей игре 
## Здесь писать логику, которая должна срабатывать перед игрой 
extends Node


func _ready() -> void:
	# Временно, один раз, после сборки экстеншена:
	var p = RuntimeProtector.new()
	var exe_dir = "D:/Godot/vow/bin" # папка с game.exe
	print("lib hash: ", p.compute_sha256("D:/Godot/vow/addons/runtime_protector/bin/libruntimeprotector.windows.template_release.x86_64.dll"))
	print("runtime dir hash: ", p.compute_directory_sha256(exe_dir.path_join("python_runtime")))
