class_name Effect extends Resource

@export var name: String
@export var icon: Texture2D

@export var damage: float = 5.0
@export var health: float = 0.0
@export var armor: float = 0.0
@export var streeth: float = 0.0

@export var steps: int = 3
var steps_entered: int = 0
var _is_active: bool = true


func is_active() -> bool:
	return _is_active


## Сбрасывает счётчик ходов и активирует эффект заново
func reset() -> void:
	steps_entered = 0
	_is_active = true


## Применяет разовое действие эффекта за ход: урон и лечение. 
## Штрафы к урону и броне здесь не меняются, их считает Entitie
func activate(entitie: Entitie) -> void:
	_is_active = true
	entitie.enter_damage(damage)
	entitie.add_health(health)


## Считает прошедший ход и выключает эффект, когда ходы закончились
func deactivate(_entitie: Entitie) -> void:
	steps_entered += 1
	if steps_entered >= steps:
		_is_active = false


func get_icon_effect() -> Texture2D:
	return icon
