class_name Weapon extends Resource


enum Type {HEAD, CHEST, LEGS, BOOTS, ARMS, ARMR, ARML}

@export var weapon_name: String
@export var icon: Texture2D

@export var damage: float
@export var armor: float

@export var type: Weapon.Type = Weapon.Type.CHEST


func get_icon() -> Texture2D:
	return icon


func equip(entitie: Entitie):
	print('equip')
	entitie.damage += damage
	entitie.armor += armor


func unequip(entitie: Entitie):
	print('unequip')
	entitie.damage -= damage
	entitie.armor -= armor


func get_weapon_name() -> String:
	return weapon_name


func get_damage() -> float:
	return damage


func get_armor() -> float:
	return armor


func get_type() -> Weapon.Type:
	return type
