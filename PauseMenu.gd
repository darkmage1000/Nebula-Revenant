# PauseMenu.gd – PAUSE MENU WITH STATS PAGE
extends Control

var player: CharacterBody2D = null
var main_game: Node2D = null

@onready var stats_label = $Panel/StatsLabel
@onready var resume_button = $Panel/ResumeButton
@onready var quit_button = $Panel/QuitButton

func _ready():
	resume_button.pressed.connect(_on_resume_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	update_stats()

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_on_resume_pressed()

func update_stats():
	if not is_instance_valid(player) or not is_instance_valid(main_game):
		return
	
	var stats_text = ""
	stats_text += "=== GAME STATS ===\n\n"
	
	# Time
	var time = main_game.game_time
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	stats_text += "Time: %02d:%02d\n" % [minutes, seconds]
	stats_text += "Level: %d\n\n" % player.player_stats.level
	
	# Player Stats
	stats_text += "=== PLAYER STATS ===\n"
	stats_text += "HP: %d / %d\n" % [int(player.player_stats.current_health), int(player.player_stats.max_health)]
	stats_text += "Damage: +%.0f%%\n" % ((player.player_stats.damage_mult - 1.0) * 100)
	stats_text += "Speed: %.0f\n" % player.player_stats.speed
	stats_text += "Attack Speed: +%.0f%%\n" % ((player.player_stats.attack_speed_mult - 1.0) * 100)
	stats_text += "Lifesteal: %.1f%%\n" % (player.player_stats.lifesteal * 100)
	stats_text += "Health Regen: %.1f HP/sec\n\n" % player.player_stats.health_regen
	
	# Weapons
	stats_text += "=== WEAPONS ===\n"
	for weapon_key in player.player_stats.current_weapons:
		if player.weapon_data.has(weapon_key):
			var weapon = player.weapon_data[weapon_key]
			stats_text += "%s (Lvl %d)\n" % [weapon.name, weapon.level]
			stats_text += "  Damage: %.0f\n" % weapon.damage
			stats_text += "  Fire Rate: %.1f/sec\n" % weapon.attack_speed
			if weapon.projectiles > 1:
				stats_text += "  Projectiles: %d\n" % weapon.projectiles
			if weapon.pierce > 0:
				stats_text += "  Pierce: %d\n" % weapon.pierce
	
	stats_text += "\n"
	
	# Weapon Damage Dealt
	stats_text += "=== DAMAGE DEALT ===\n"
	if player.weapon_damage_dealt.size() > 0:
		for weapon_key in player.weapon_damage_dealt:
			stats_text += "%s: %.0f\n" % [weapon_key.capitalize(), player.weapon_damage_dealt[weapon_key]]
	else:
		stats_text += "No damage tracked yet\n"
	
	stats_text += "\n"
	
	# Enemies Killed - use direct access since we defined these variables
	stats_text += "=== COMBAT ===\n"
	stats_text += "Enemies Killed: %d\n" % main_game.enemies_killed
	stats_text += "Bosses Defeated: %d\n" % main_game.bosses_defeated
	
	stats_text += "\n"
	
	# Boss Items - use direct access
	stats_text += "=== ITEMS COLLECTED ===\n"
	if main_game.items_collected.size() > 0:
		# Group by tier
		var by_tier = {"purple": [], "green": [], "blue": [], "yellow": []}
		for item in main_game.items_collected:
			by_tier[item.tier].append(item)
		
		# Show legendaries first
		for tier in ["purple", "green", "blue", "yellow"]:
			for item in by_tier[tier]:
				var tier_icon = {"purple": "★", "green": "◆", "blue": "●", "yellow": "○"}
				stats_text += "%s [%s] %s\n" % [tier_icon[tier], tier.to_upper(), item.name]
	else:
		stats_text += "No items collected yet\n"
	
	stats_label.text = stats_text

func _on_resume_pressed():
	get_tree().paused = false
	queue_free()

func _on_quit_pressed():
	get_tree().paused = false
	get_tree().quit()
