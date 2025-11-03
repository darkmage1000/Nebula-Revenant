# level_up_screen.gd – FIXED: WORKING LEVEL UP WITH PROPER PAUSING
extends Control

# SIGNAL: Sent when player picks an upgrade
signal upgrade_selected(data: Dictionary)

# Reference to player (set by main_game.gd)
var player: CharacterBody2D = null

# Example upgrade options (you can customize)
var upgrade_options: Array = [
	{"type": "unlock", "weapon": "shotgun", "label": "Unlock Shotgun", "desc": "Fires a spread of 4 pellets"},
	{"type": "unlock", "weapon": "grenade", "label": "Unlock Grenade", "desc": "Explosive area damage"},
	{"type": "unlock", "weapon": "aura", "label": "Unlock Radiation Aura", "desc": "Constant damage around you"},
	{"type": "stat", "key": "damage_mult", "value": 0.25, "label": "+25% Damage", "desc": "All weapons deal more damage"},
	{"type": "stat", "key": "max_health", "value": 50, "label": "+50 Max HP", "desc": "Increases maximum health"},
	{"type": "stat", "key": "lifesteal", "value": 0.1, "label": "+10% Lifesteal", "desc": "Heal from damage dealt"},
	{"type": "stat", "key": "attack_speed_mult", "value": 0.2, "label": "+20% Attack Speed", "desc": "Weapons fire faster"},
	{"type": "stat", "key": "speed", "value": 0.15, "label": "+15% Move Speed", "desc": "Move faster"},
	{"type": "stat", "key": "health_regen", "value": 1.0, "label": "+1 HP/sec Regen", "desc": "Regenerate health over time"},
	{"type": "weapon", "weapon": "pistol", "key": "damage", "value": 5, "label": "Pistol: +5 Damage", "desc": "Increase pistol damage"},
	{"type": "weapon", "weapon": "pistol", "key": "attack_speed", "value": 0.2, "label": "Pistol: +20% Fire Rate", "desc": "Pistol shoots faster"},
	{"type": "weapon", "weapon": "shotgun", "key": "damage", "value": 3, "label": "Shotgun: +3 Damage", "desc": "Each pellet deals more damage"},
	{"type": "weapon", "weapon": "grenade", "key": "aoe", "value": 20, "label": "Grenade: +20 Blast Radius", "desc": "Bigger explosions"},
]

# UI Nodes - now using correct paths from the scene
@onready var title_label: Label = $Label
@onready var button_container: VBoxContainer = $CenterContainer/OptionsContainer

func _ready() -> void:
	# Set title
	if title_label:
		title_label.text = "LEVEL UP! Choose One:"
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.add_theme_font_size_override("font_size", 32)
	
	# Clear old buttons
	for child in button_container.get_children():
		child.queue_free()
	
	# Filter upgrade options based on what player has
	var available_pool = _filter_available_upgrades()
	
	# Randomly pick 3 upgrades
	var selected = []
	var pool = available_pool.duplicate()
	while selected.size() < 3 and pool.size() > 0:
		var idx = randi() % pool.size()
		selected.append(pool[idx])
		pool.remove_at(idx)
	
	# Create buttons for each upgrade
	for opt in selected:
		var btn = Button.new()
		btn.text = opt.label
		if opt.has("desc"):
			btn.tooltip_text = opt.desc
		btn.custom_minimum_size = Vector2(400, 80)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_on_upgrade_pressed.bind(opt))
		button_container.add_child(btn)

# Filter upgrades based on what weapons player has unlocked
func _filter_available_upgrades() -> Array:
	var filtered = []
	
	for opt in upgrade_options:
		# Check if this is a weapon unlock
		if opt.type == "unlock":
			# Only offer if player doesn't have this weapon yet
			if player and not player.player_stats.current_weapons.has(opt.weapon):
				filtered.append(opt)
		# Check if this is a weapon-specific upgrade
		elif opt.type == "weapon":
			# Only offer if player HAS this weapon
			if player and player.player_stats.current_weapons.has(opt.weapon):
				filtered.append(opt)
		# Stat upgrades are always available
		elif opt.type == "stat":
			filtered.append(opt)
	
	return filtered

# Called when a button is pressed
func _on_upgrade_pressed(option: Dictionary) -> void:
	var data: Dictionary = {}
	
	match option.type:
		"unlock":
			data["unlock_weapon"] = option.weapon
		"stat":
			data["stat_key"] = option.key
			data["value"] = option.value
		"weapon":
			data["weapon_key"] = option.weapon
			data["upgrade_key"] = option.key
			data["value"] = option.value
	
	# Emit signal → main_game handles upgrade
	upgrade_selected.emit(data)
	
	# Remove self from scene
	queue_free()
