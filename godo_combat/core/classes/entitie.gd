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
	Weapon.Type.HEAD: null,
	Weapon.Type.CHEST: null,
	Weapon.Type.LEGS: null,
	Weapon.Type.BOOTS: null,
	Weapon.Type.ARMS: null,
	Weapon.Type.ARML: null,
	Weapon.Type.ARMR: null
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
			var weapon: Weapon = GCombat.get_weapon(i)
			
			equiped_weapons[weapon.get_type()] = weapon
			damage += weapon.damage
			armor += weapon.armor
	print('Экипированные предметы(_reset_weapons):     ', equiped_weapons)


## Заменяет кэш экипировки сущности. Вызывается только из GCombat
func set_equipment(weapons: Array[Weapon]) -> void:
	for slot in equiped_weapons:
		equiped_weapons[slot] = null
	
	for weapon: Weapon in weapons:
		equiped_weapons[weapon.get_type()] = weapon


## Возвращает урон с учётом экипировки и активных эффектов
func get_total_damage() -> float:
	var total: float = damage
	
	for weapon: Weapon in equiped_weapons.values():
		if weapon:
			total += weapon.get_damage()
	
	# Штраф от эффекта действует, пока эффект активен
	for effect: Effect in effects:
		if effect and effect.is_active():
			total -= effect.streeth
	
	return total


## Возвращает броню с учётом экипировки и активных эффектов
func get_total_armor() -> float:
	var total: float = armor
	
	for weapon: Weapon in equiped_weapons.values():
		if weapon:
			total += weapon.get_armor()
	
	for effect: Effect in effects:
		if effect and effect.is_active():
			total -= effect.armor
	
	return total


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
	
	if ability.get_type() == Ability.Type.MINI_GAME_LOW or ability.get_type() == Ability.Type.MINI_GAME_HIGT:
		mini_game = _mini_game
		mini_game.victory.connect(_victory)
		mini_game.defeat.connect(_defeat)
		mini_game.start()
		
		await mini_game.end
		
		if is_victory:
			var attack_effect: Array = ability.get_attack()
			
			entitie.enter_damage(get_total_damage() + attack_effect[0])
			GCombat._write_buffer(ability, 'enemy_ability')
			for i in ability.get_attack()[1]:
				entitie.add_effect(i)
		else:
			var attack_effect: Array = ability.get_attack()
			
			entitie.enter_damage(get_total_damage() + (attack_effect[0] * ability.unsuccessful_damage_percent))
			GCombat._write_buffer(ability, 'enemy_ability')
	else:
		var attack_effect: Array = ability.get_attack()
		
		entitie.enter_damage(get_total_damage() + attack_effect[0])
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
	health -= (_damage - get_total_armor())
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


## Завершает ход эффектов и убирает истёкшие
func deactivate_effects() -> void:
	# Идём по копии, так как remove_effect изменяет исходный список
	for effect: Effect in effects.duplicate():
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


## Добавляет копию эффекта, чтобы у каждой сущности был свой счётчик ходов
func add_effect(effect: Effect) -> void:
	var effect_copy: Effect = effect.duplicate()
	effect_copy.reset()
	effects.append(effect_copy)


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
