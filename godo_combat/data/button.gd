extends TextureButton

signal press(ability: Ability)
var ability: Ability


func _ready() -> void:
	pressed.connect(pressed_button)


func setup(text: String, _ability: Ability):
	$Label.text = text
	ability = _ability
	
	if ability.get_ability_icon():
		texture_normal = ability.get_ability_icon()
	if ability.get_ability_hovered_icon():
		texture_normal = ability.get_ability_hovered_icon()
	if ability.get_ability_pressed_icon():
		texture_normal = ability.get_ability_pressed_icon()


func pressed_button():
	get_parent().hide()
	press.emit(ability)
