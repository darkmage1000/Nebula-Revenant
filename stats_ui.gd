extends Control

# --- THESE PATHS ARE NOW CORRECTED ---
@onready var player_level_label = $MarginContainer/VBoxContainer/PlayerLevelLabel
@onready var stats_label = $MarginContainer/VBoxContainer/StatsLabel
@onready var weapons_label = $MarginContainer/VBoxContainer/WeaponsLabel

func _ready():
	# Start hidden
	hide()

func update_stats(player_stats, weapon_data):
	# Update Player Level
	player_level_label.text = "Player Level: %s" % player_stats.level
	
	# Update Player Stats
	var stat_text = "[Player Stats]\n"
	stat_text += "Max Health: %s\n" % player_stats.max_health
	stat_text += "Health Regen: %s/s\n" % player_stats.health_regen
	stat_text += "Lifesteal: %s%%\n" % (player_stats.lifesteal * 100)
	stat_text += "Move Speed: %s\n" % player_stats.speed
	stat_text += "Atk Speed: %s%%\n" % (player_stats.attack_speed_mult * 100)
	stat_text += "Damage: %s%%\n" % (player_stats.damage_mult * 100)
	stat_text += "AoE: %s%%\n" % (player_stats.aoe_mult * 100)
	stat_text += "Crit Chance: %s%%\n" % (player_stats.crit_chance * 100)
	stat_text += "Crit Damage: %s%%\n" % (player_stats.crit_damage * 100)
	stats_label.text = stat_text
	
	# Update Weapon Stats
	var weapon_text = "[Weapons]\n"
	for weapon_name in weapon_data:
		var data = weapon_data[weapon_name]
		if data.level > 0:
			weapon_text += "%s - Lvl %s\n" % [weapon_name.capitalize(), data.level]
			weapon_text += "  Dmg: %s, Atk Spd: %s\n" % [data.damage, data.attack_speed]
	weapons_label.text = weapon_text
