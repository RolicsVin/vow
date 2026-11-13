class_name Ability extends Resource


enum Type {FREE, MINI_GAME_LOW, MINI_GAME_HIGT}
enum EffectType {ONE, RANDOM, FULL}

@export var name: String

@export var damage: float = 10.0
@export var unsuccessful_damage_percent: float = 0.3
@export var random_damage: float = 5.0

@export var endurance: float = 0.0
@export var mana: float = 0.0

@export var effects: Array[Effect]
@export var type: Ability.Type = Ability.Type.FREE
@export var type_effects: Ability.EffectType = Ability.EffectType.FULL

@export var critical: float = 30.0
@export_range(0, 100) var critical_change: float = 10.0

@export var animation: String = 'player_attack'

@export_group('textures')
@export var normal: Texture2D
@export var hovered: Texture2D
@export var pressed: Texture2D

var unsuccessful_damage: float = 0.0 


func get_ability_icon() -> Texture2D:
	return normal


func get_ability_hovered_icon() -> Texture2D:
	return hovered


func get_ability_pressed_icon() -> Texture2D:
	return pressed


func get_effects():
	return effects


func get_ability_name() -> String:
	return name


func _get_random_damage() -> float:
	return Array(range(-random_damage, random_damage)).pick_random()


func get_attack() -> Array:
	var _effects: Array[Effect]
	
	match type_effects:
		Ability.EffectType.ONE:
			_effects.append(effects.pick_random())
		Ability.EffectType.RANDOM:
			for effect in effects:
				if Core.tools.chance(50):
					_effects.append(effect)
		Ability.EffectType.FULL:
			_effects = effects
	
	if Core.tools.chance(critical_change):
		return [critical + _get_random_damage(), _effects]
	else:
		return [damage + _get_random_damage(), _effects]


func _get_damage() -> float:
	return damage


func get_endurance() -> float:
	return endurance


func get_mana() -> float:
	return mana


func get_animation_name() -> String:
	return animation


func get_type() -> Ability.Type:
	return type
