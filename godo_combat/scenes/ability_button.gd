extends TextureButton

signal press(_ability: Ability)

var player: Entitie
var ability_name: String
var ability: Ability


func setup(_ability_name: String, _ability: Ability, _player: Entitie) -> void:
	player = _player
	ability_name = _ability_name
	ability = _ability
	$Label.text = _ability_name


func _pressed() -> void:
	if player.get_endurance() - ability.get_endurance() >= 0 and player.get_mana() - ability.get_mana() >= 0:
		player.endurance -= ability.get_endurance()
		player.mana -= ability.get_mana()
		press.emit(ability)
