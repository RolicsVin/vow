class_name Entitie extends Resource

signal dead
signal healed
signal damaget
signal attacks

@export var name: String
@export var icon: Texture2D

@export var health_max: float = 100.0

var health: float = health_max:
	set(value):
		health = clamp(value, 0, health_max)

@export var armor: float = 0.0
@export var damage: float = 10.0

@export var endurance_max: float = 10.0
@export var mana_max: float = 10.0

@export var endurance_recovery: float = 4.0
@export var mana_recovery: float = 4.0

var endurance: float = endurance_max:
	set(value):
		endurance = clamp(value, 0, endurance_max)

var mana: float = mana_max:
	set(value):
		mana = clamp(value, 0, mana_max)

@export var abilitys: Array[Ability]
@export var effects: Array[Effect]

@export var equiped_weapons: Dictionary = {
	GcEnum.weapon_type.HEAD: null,
	GcEnum.weapon_type.CHEST: null,
	GcEnum.weapon_type.LEGS: null,
	GcEnum.weapon_type.BOOTS: null,
	GcEnum.weapon_type.ARMS: null,
	GcEnum.weapon_type.ARML: null,
	GcEnum.weapon_type.ARMR: null
}

@export var experience: float = 10.0

var level: int = 0

var mini_game: MiniGame
var is_victory: bool = false


func _reset_weapons() -> void:
	print('Сброс предметов игрока!')
	for i in equiped_weapons:
		if equiped_weapons[i]:
			damage -= equiped_weapons[i].damage
			armor -= equiped_weapons[i].armor
			equiped_weapons[i] = null
	
	if 'equiped_weapons' in GCombat._get_buffer():
		for i in GCombat._get_buffer()['equiped_weapons']:
			var weapon: Weapon = GcData.weapons[i]
			
			equiped_weapons[weapon.get_type()] = weapon
			damage += weapon.damage
			armor += weapon.armor
	print('Экипированные предметы(_reset_weapons):     ', equiped_weapons)


func equip_weapon(weapon_name: String) -> void:
	GCombat.remowe_weapon_to_player_inventory(weapon_name)
	var weapon: Weapon = GcData.weapons[weapon_name]
	
	if not equiped_weapons[weapon.get_type()]:
		equiped_weapons[weapon.get_type()] = weapon
	else:
		GCombat.add_weapon_to_player_inventory(equiped_weapons[weapon.get_type()].get_weapon_name())
		equiped_weapons[weapon.get_type()] = weapon
	
	if 'equiped_weapons' in GCombat._get_buffer():
		GCombat._get_buffer()['equiped_weapons'].append(weapon.get_weapon_name())
	else:
		GCombat._get_buffer()['equiped_weapons'] = [weapon.get_weapon_name()]
	
	damage += equiped_weapons[weapon.get_type()].damage
	armor += equiped_weapons[weapon.get_type()].armor
	
	print('Предмет экипирован')
	print('Экипированные предметы(equip_weapon):     ', equiped_weapons)


func unequip_weapon(weapon_name: String) -> void:
	GCombat.add_weapon_to_player_inventory(weapon_name)
	GCombat._get_buffer()['equiped_weapons'].remove_at(GCombat._get_buffer()['equiped_weapons'].find(weapon_name))
	
	var weapon: Weapon = GcData.weapons[weapon_name]
	
	damage -= equiped_weapons[weapon.get_type()].damage
	armor -= equiped_weapons[weapon.get_type()].armor
	
	equiped_weapons[weapon.get_type()] = null
	
	print('Предмет убран')
	print('Экипированные предметы(anequip_weapon):     ', equiped_weapons)


func attack(entitie: Entitie, ability: Ability = null, _mini_game: MiniGame = null) -> void:
	
	if health <= 0:
		return
	is_victory = false
	
	append_effects()
	
	if not ability:
		while true:
			ability = abilitys.pick_random()
			
			if endurance - ability.get_endurance() >= 0 and mana - ability.get_mana() >= 0:
				endurance -= ability.get_endurance()
				mana -= ability.get_mana()
				break
	
	if ability.get_type() == GcEnum.ability_type.MINI_GAME_LOW or ability.get_type() == GcEnum.ability_type.MINI_GAME_HIGT:
		mini_game = _mini_game
		mini_game.victory.connect(_victory)
		mini_game.defeat.connect(_defeat)
		mini_game.start()
		
		await mini_game.end
		
		if is_victory:
			var attack_effect: Array = ability.get_attack()
			
			entitie.enter_damage(damage + attack_effect[0])
			GCombat._write_buffer(ability, 'enemy_ability')
			for i in ability.get_attack()[1]:
				entitie.add_effect(i)
		else:
			var attack_effect: Array = ability.get_attack()
			
			entitie.enter_damage(damage + (attack_effect[0] * ability.unsuccessful_damage_percent))
			GCombat._write_buffer(ability, 'enemy_ability')
	else:
		var attack_effect: Array = ability.get_attack()
		
		entitie.enter_damage(damage + attack_effect[0])
		GCombat._write_buffer(ability, 'enemy_ability')
		for i in ability.get_attack()[1]:
			entitie.add_effect(i)
	
	attacks.emit()
	
	deactivate_effects()


func _victory():
	is_victory = true


func _defeat():
	is_victory = false


func enter_damage(_damage: float):
	health -= (_damage - armor)
	print(name, ':     ', health)
	if health <= 0:
		dead.emit()
	damaget.emit()


func add_health(point: float):
	health += point
	healed.emit()


func append_effects() -> void:
	if not effects:
		return
	for effect in effects:
		if effect:
			effect.activate(self)


func deactivate_effects() -> void:
	for effect: Effect in effects:
		if effect:
			effect.deactivate(self)
			if not effect.is_active():
				remove_effect(effect)


func add_ability(ability: Ability):
	abilitys.append(ability)


func remove_ability(ability: Ability):
	abilitys.remove_at(abilitys.find(ability))


func get_icon() -> Texture2D:
	return icon


func get_abilitys() -> Array[Ability]:
	return abilitys


func add_effect(effect: Effect):
	effects.append(effect)


func remove_effect(effect: Effect):
	effects.remove_at(effects.find(effect))


func get_effects() -> Array[Effect]:
	return effects


func get_attack() -> float:
	return damage


func get_endurance() -> float:
	return endurance


func get_mana() -> float:
	return mana


func get_health() -> float:
	return health


func get_experience() -> float:
	return experience
