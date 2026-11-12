extends Node

var _data: Node = ToolFactory.make_tool(self, "res://godo_combat/data/gc_data.gd", "Data")

var _buffer: Dictionary = {
	'player_entitie': load("res://Assets/entities/player/player.tres")
}


func get_save() -> Dictionary:
	if 'inventory' not in _buffer:
		_buffer['inventory'] = []
	if 'weapons' not in _buffer:
		_buffer['weapons'] = []
	if 'equiped_weapons' not in _buffer:
		_buffer['equiped_weapons'] = []
	if 'money' not in _buffer:
		_buffer['money'] = 0.0
	
	var abilitys: Array = []
	
	for i: Ability in _buffer['player_entitie'].get_abilitys():
		abilitys.append(i.get_ability_name())
	
	_buffer['player'] = {
		'health_max': _buffer['player_entitie'].health_max,
		'health': _buffer['player_entitie'].health,
		'armor': _buffer['player_entitie'].armor,
		'damage': _buffer['player_entitie'].damage,
		'endurance_max': _buffer['player_entitie'].endurance_max,
		'endurance': _buffer['player_entitie'].endurance,
		'mana_max': _buffer['player_entitie'].mana_max,
		'mana': _buffer['player_entitie'].mana,
		'experience': _buffer['player_entitie'].experience,
		'level': _buffer['player_entitie'].level,
		'abilitys': abilitys
	}
	
	return {
		'player': _buffer['player'],
		'inventory': _buffer['inventory'],
		'weapons': _buffer['weapons'],
		'equiped_weapons': _buffer['equiped_weapons'],
		'money': _buffer['money']
		}


func load_save(save: Dictionary):
	_buffer['inventory'] = save['inventory']
	_buffer['weapons'] = save['weapons']
	_buffer['equiped_weapons'] = save['equiped_weapons']
	_buffer['money'] = save['money']
	
	var player: Dictionary = save['player']
	var abilitys: Array[Ability] = []
	
	for i in player['abilitys']:
		abilitys.append(get_ability(i))
	
	_buffer['player_entitie'].health_max = player['health_max']
	_buffer['player_entitie'].health = player['health']
	_buffer['player_entitie'].armor = player['armor']
	_buffer['player_entitie'].damage = player['damage']
	_buffer['player_entitie'].endurance_max = player['endurance_max']
	_buffer['player_entitie'].endurance = player['endurance']
	_buffer['player_entitie'].mana_max = player['mana_max']
	_buffer['player_entitie'].mana = player['mana']
	_buffer['player_entitie'].experience = player['experience']
	_buffer['player_entitie'].level = player['level']
	_buffer['player_entitie'].abilitys = abilitys


func _get_obj_on_buffer(k):
	"""Вернёт объект из буфера по ключу."""
	return _buffer[k]


func _get_buffer() -> Dictionary:
	"""Вернёт буффер модуля godo_visual_novel."""
	return _buffer


func _write_buffer(obj, k) -> void:
	"""Допишет в буфер информацию по ключу. Если ключ уже существует, то информация будет перезаписана."""
	_buffer[k] = obj


func add_weapon_to_player_inventory(weapon_name: String) -> void:
	if 'weapons' in GCombat._get_buffer():
		_buffer['weapons'].append(weapon_name)
	else:
		_buffer['weapons'] = [weapon_name]


func remowe_weapon_to_player_inventory(weapon_name: String) -> void:
	_buffer['weapons'].remove_at(_buffer['weapons'].find(weapon_name))


func equip_weapon(weapon_name: String):
	if weapon_name not in _buffer['weapons']:
		return
	
	var weapon: Weapon = get_weapon(weapon_name)
	var type = weapon.get_type()
	
	if 'equiped_weapons' not in _buffer:
		_buffer['equiped_weapons'] = []
	
	for i: String in _buffer['equiped_weapons']:
		var _weapon: Weapon = get_weapon(i)
		if _weapon.get_type() == type:
			unequip_weapon(_weapon.get_weapon_name())
	
	remowe_weapon_to_player_inventory(weapon_name)
	_buffer['equiped_weapons'].append(weapon.get_weapon_name())


func unequip_weapon(weapon_name: String):
	if 'equiped_weapons' not in _buffer:
		return
	if weapon_name not in _buffer['equiped_weapons']:
		return
	
	_buffer['equiped_weapons'].remove_at(_buffer['equiped_weapons'].find(weapon_name))
	add_weapon_to_player_inventory(weapon_name)


## Возвращает предмет по идентификатору, не раскрывая хранилище данных модуля.
func get_item(item_name: String) -> GCItem:
	return _data.items.get(item_name) as GCItem


## Возвращает оружие по идентификатору.
func get_weapon(weapon_name: String) -> Weapon:
	return _data.weapons.get(weapon_name) as Weapon


## Возвращает способность по идентификатору.
func get_ability(ability_name: String) -> Ability:
	return _data.abilitys.get(ability_name) as Ability


## Возвращает описание уровня по его пороговому значению.
func get_level(level: float) -> Dictionary:
	return _data.levels.get(level, {})
