# GameHUD.gd – COMPLETE UI: TIMER + HEALTH + XP + LEVEL
extends CanvasLayer

# References set by main_game
var player: CharacterBody2D = null
var main_game: Node2D = null

# UI Elements
@onready var timer_label = $TimerLabel
@onready var health_bar = $HealthBar
@onready var health_label = $HealthBar/HealthLabel
@onready var xp_bar = $XPBar
@onready var level_label = $LevelLabel
@onready var weapon_levels_container = $WeaponLevelsPanel/WeaponLevelsContainer

# Track weapon labels for updates
var weapon_labels: Dictionary = {}

func _ready():
	# Will be set by main_game
	pass

func _process(delta: float):
	# Hide HUD when game is paused
	if get_tree().paused:
		visible = false
		return
	else:
		visible = true
	
	if not is_instance_valid(player) or not is_instance_valid(main_game):
		return
	
	update_timer()
	update_health()
	update_xp()
	update_level()
	update_weapon_levels()

# Update timer display (00:00 format)
func update_timer():
	var time = main_game.game_time
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# Change color as time progresses
	if time >= 1500:  # 25+ min
		timer_label.modulate = Color(1.0, 0.3, 0.3)  # Red
	elif time >= 900:  # 15+ min
		timer_label.modulate = Color(1.0, 0.8, 0.3)  # Orange
	else:
		timer_label.modulate = Color(1.0, 1.0, 1.0)  # White

# Update health bar and label
func update_health():
	var current = player.player_stats.current_health
	var max_hp = player.player_stats.max_health
	
	health_bar.max_value = max_hp
	health_bar.value = current
	health_label.text = "%d / %d" % [int(current), int(max_hp)]
	
	# Color based on health percentage
	var health_percent = current / max_hp
	if health_percent > 0.6:
		health_bar.modulate = Color(0.2, 1.0, 0.2)  # Green
	elif health_percent > 0.3:
		health_bar.modulate = Color(1.0, 0.8, 0.2)  # Yellow
	else:
		health_bar.modulate = Color(1.0, 0.2, 0.2)  # Red

# Update XP bar
func update_xp():
	var current_xp = player.player_stats.current_xp
	var xp_needed = player.player_stats.xp_to_next_level
	
	xp_bar.max_value = xp_needed
	xp_bar.value = current_xp

# Update level display
func update_level():
	if not player:
		level_label.text = "Level ?"
		return
	level_label.text = "Level %d" % player.player_stats.level

# Update weapon levels display
func update_weapon_levels():
	# Safety checks to prevent crashes
	if not is_instance_valid(player):
		return

	if not player.has("weapon_data") or not player.weapon_data:
		return

	if not player.has("player_stats") or not player.player_stats:
		return

	# Get current weapons from player
	var current_weapons = player.player_stats.get("current_weapons", [])
	if not current_weapons or current_weapons.size() == 0:
		return

	# Update or create labels for each weapon
	for weapon_key in current_weapons:
		if not player.weapon_data.has(weapon_key):
			continue

		var weapon_data = player.weapon_data[weapon_key]
		if not weapon_data:
			continue

		var weapon_name = weapon_data.get("name", "Unknown")
		var weapon_level = weapon_data.get("level", 0)

		# Check if label already exists
		if not weapon_labels.has(weapon_key):
			# Create new label for this weapon
			if not is_instance_valid(weapon_levels_container):
				return

			var label = Label.new()
			label.name = weapon_key + "_label"
			label.add_theme_font_size_override("font_size", 16)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			weapon_levels_container.add_child(label)
			weapon_labels[weapon_key] = label

		# Update label text
		var label = weapon_labels[weapon_key]
		if weapon_level > 0:
			label.text = "%s  Lv%d" % [get_weapon_icon(weapon_key), weapon_level]
		else:
			label.text = "%s  Lv0" % get_weapon_icon(weapon_key)

		# Color based on level
		if weapon_level >= 3:
			label.modulate = Color(1.0, 0.6, 1.0)  # Purple for max level
		elif weapon_level >= 2:
			label.modulate = Color(0.4, 0.8, 1.0)  # Blue for level 2
		elif weapon_level >= 1:
			label.modulate = Color(0.4, 1.0, 0.6)  # Green for level 1
		else:
			label.modulate = Color(1.0, 1.0, 1.0)  # White for level 0

	# Remove labels for weapons no longer equipped
	var keys_to_remove = []
	for weapon_key in weapon_labels:
		if not current_weapons.has(weapon_key):
			keys_to_remove.append(weapon_key)

	for key in keys_to_remove:
		if weapon_labels[key]:
			weapon_labels[key].queue_free()
		weapon_labels.erase(key)

func get_weapon_icon(weapon_key: String) -> String:
	match weapon_key:
		"pistol":
			return "🔫"
		"shotgun":
			return "💥"
		"grenade":
			return "💣"
		"aura":
			return "☢️"
		"sword":
			return "⚔️"
		_:
			return "🔸"
