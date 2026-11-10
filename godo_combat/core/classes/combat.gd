class_name Combat extends Control

signal is_victory
signal is_defeat
signal end_combat
signal _selected_ability
signal _player_attacked

@export var player: Entitie
@export var enemy: Entitie

@export var money: float = 0.0

@export_group('ui')
@export var player_health: TextureProgressBar
@export var player_endurance: TextureProgressBar
@export var player_mana: TextureProgressBar
@export var player_effect: HBoxContainer

@export var enemy_health: TextureProgressBar
@export var enemy_effect: HBoxContainer

@export_group('dependencies')
@export var inventory: GridContainer

@export var button: PackedScene
@export var inventory_button: PackedScene

@export var button_box: VBoxContainer
@export var animation: AnimationPlayer

@export var mini_game_root: Control
@export var mini_game_low: Array[PackedScene]
@export var mini_game_hight: Array[PackedScene]

@export_group('adventure')
@export var time: float = 0.5
@export var combat_type: GcEnum.combat_types = GcEnum.combat_types.AT_THE_SAME_TIME

var is_combat: bool = true

var call_back_victory
var call_back_defeat


func _ready() -> void:
	inventory.hide()
	button_box.hide()


func _add_effects_to_player(effects: Array[Effect]) -> void:
	for i in effects:
		player.add_effect(i)
	reset_player_effects()
	reset_inventory()


func reset_inventory() -> void:
	for i in inventory.get_children():
		i.queue_free()
	
	if 'inventory' in GCombat._buffer:
		for item_str: String in GCombat._get_buffer()['inventory']:
			var item: GCItem = GcData.items[item_str]
			var _button: TextureButton = inventory_button.instantiate()
			_button.setup(GcData.items[item.get_item_name()], _add_effects_to_player)
			inventory.add_child(_button)


func reset_player_effects() -> void:
	for child in player_effect.get_children():
			child.queue_free()
		
	if player.get_effects():
		for effect in player.get_effects():
			if not effect.get_icon_effect():
				continue
			var effect_icon = TextureRect.new()
			effect_icon.texture = effect.get_icon_effect()
			effect_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			effect_icon.stretch_mode = TextureRect.STRETCH_SCALE
			effect_icon.custom_minimum_size.y = player_effect.size.y
			effect_icon.custom_minimum_size.x = effect_icon.custom_minimum_size.y
			player_effect.add_child(effect_icon)


func start_combat(_player: Entitie = null, _enemy: Entitie = null, _money: float = 0.0, _call_victory = null, _call_defeat = null):
	if _player:
		player = _player
	if not player:
		player = GCombat._get_buffer()['player_entitie']
	if _enemy:
		enemy = _enemy
	if _money:
		money = _money
	if _call_victory:
		call_back_victory = _call_victory
	if _call_defeat:
		call_back_defeat = _call_defeat
	
	for child in button_box.get_children():
		button_box.remove_child(child)
	
	for ability in player.get_abilitys():
		var _button: TextureButton = button.instantiate()
		_button.setup(ability.get_ability_name(), ability, player)
		_button.press.connect(select_ability)
		button_box.add_child(_button)
	
	reset_inventory()
	player._reset_weapons()
	
	enemy.dead.connect(victory)
	player.dead.connect(defeat)
	
	while is_combat:
		print('   ')
		print('        ')
		
		print('while is_combat ------------------------------------------------------------')
		
		button_box.show()
		inventory.show()
		
		player.endurance = clamp(player.endurance + player.endurance_recovery, 0, player.endurance_max)
		player.mana = clamp(player.mana + player.mana_recovery, 0, player.mana_max)
		
		enemy.endurance = clamp(enemy.endurance + enemy.endurance_recovery, 0, enemy.endurance_max)
		enemy.mana = clamp(enemy.mana + enemy.mana_recovery, 0, enemy.mana_max)
		
		if player_endurance:
			player_endurance.value = player.get_endurance()
		if player_mana:
			player_mana.value = player.get_mana()
		
		attack_player()
		
		await _player_attacked
		
		button_box.hide()
		inventory.hide()
		
		reset_inventory()
		
		for child in enemy_effect.get_children():
			child.queue_free()
		
		if enemy.get_effects():
			for effect in enemy.get_effects():
				if not effect.get_icon_effect():
					continue
				var effect_icon = TextureRect.new()
				effect_icon.texture = effect.get_icon_effect()
				effect_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				effect_icon.stretch_mode = TextureRect.STRETCH_SCALE
				effect_icon.custom_minimum_size.y = player_effect.size.y
				effect_icon.custom_minimum_size.x = effect_icon.custom_minimum_size.y
				enemy_effect.add_child(effect_icon)
		
		if enemy_health:
			enemy_health.value = enemy.get_health()
		if animation:
			animation.play(GCombat._get_obj_on_buffer('ability').get_animation_name())
			await animation.animation_finished
		
		print('эффекты противника:   ', enemy.get_effects())
		
		await get_tree().create_timer(time).timeout
		attack_enemy()
		
		if player_health:
			player_health.value = player.get_health()
		
		reset_player_effects()
		
		if animation:
			animation.play(GCombat._get_obj_on_buffer('enemy_ability').get_animation_name())
			await animation.animation_finished
		
		print('эффекты игрока:   ', player.get_effects())
		await get_tree().create_timer(time).timeout


func attack_player():
	print('     ')
	print('   ')
	print('------------------------------------------------------------')
	button_box.show()
	await _selected_ability
	if GCombat._get_obj_on_buffer('ability').get_type() == GcEnum.ability_type.MINI_GAME_LOW:
		var mini_game = mini_game_low.pick_random().instantiate()
		mini_game_root.add_child(mini_game)
		player.attack(enemy, GCombat._get_obj_on_buffer('ability'), mini_game)
		await player.attacks
		_player_attacked.emit()
	elif GCombat._get_obj_on_buffer('ability').get_type() == GcEnum.ability_type.MINI_GAME_HIGT:
		var mini_game = mini_game_hight.pick_random().instantiate()
		mini_game_root.add_child(mini_game)
		player.attack(enemy, GCombat._get_obj_on_buffer('ability'), mini_game)
		await player.attacks
		_player_attacked.emit()
	elif GCombat._get_obj_on_buffer('ability').get_type() == GcEnum.ability_type.FREE:
		player.attack(enemy, GCombat._get_obj_on_buffer('ability'))
		_player_attacked.emit()
	print('     ')
	print('   ')


func select_ability(ability: Ability):
	GCombat._write_buffer(ability, 'ability')
	
	if player_endurance:
		player_endurance.value = player.get_endurance()
	if player_mana:
		player_mana.value = player.get_mana()
	
	_selected_ability.emit()


func attack_enemy():
	enemy.attack(player)


func victory():
	if 'money' in GCombat._get_buffer():
		GCombat._get_buffer()['money'] += money
	else:
		GCombat._get_buffer()['money'] = money
	
	is_combat = false
	button_box.hide()
	is_victory.emit()
	
	if call_back_victory:
		call_back_victory.call()
	
	player.experience += enemy.get_experience()
	
	end()


func defeat():
	button_box.hide()
	is_combat = false
	is_defeat.emit()
	
	if call_back_defeat:
		call_back_defeat.call()
	
	end()


func end():
	call_back_defeat = null
	call_back_victory = null
	end_combat.emit()


func get_player() -> Entitie:
	return player
