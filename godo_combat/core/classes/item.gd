class_name GCItem extends Resource

@export var name: String
@export var icon: Texture2D

@export var effects: Array[Effect]
@export var effects_change: int = 50
@export var type_effects: GcEnum.ability_effect_type = GcEnum.ability_effect_type.FULL

@export_group('textures')
@export var hover: Texture2D
@export var pressed: Texture2D


func get_item_name() -> String:
	return name


func get_item_icon() -> Texture2D:
	return icon


func get_item_icon_hover() -> Texture2D:
	return hover


func get_item_icon_pressed() -> Texture2D:
	return pressed


func get_item_effects() -> Array[Effect]:
	var _effects: Array[Effect] = []
	match type_effects:
		GcEnum.ability_effect_type.ONE:
			_effects.append(effects.pick_random())
		GcEnum.ability_effect_type.RANDOM:
			for effect in effects:
				if GodoTools.chance(effects_change):
					_effects.append(effect)
		GcEnum.ability_effect_type.FULL:
			_effects = effects
	return _effects


func get_item_type_effects() -> GcEnum.ability_effect_type:
	return type_effects
