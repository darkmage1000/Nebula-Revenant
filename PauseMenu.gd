# PauseMenu.gd – PAUSE MENU WITH STATS PAGE
extends Control

var player: CharacterBody2D = null
var main_game: Node2D = null

@onready var stats_label = $Panel/VBoxContainer/ScrollContainer/StatsLabel
@onready var resume_button = $Panel/VBoxContainer/ButtonsContainer/ResumeButton
@onready var quit_button = $Panel/VBoxContainer/ButtonsContainer/QuitButton

func _ready():
	# Make sure we're visible
	visible = true
	
	# Connect buttons
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	# Update stats
	call_deferred("update_stats")
	
	print("✅ Pause menu loaded!")

func _input(event):
	if event.is_action_pressed("ui_cancel"):  # ESC key
		_on_resume_pressed()
		get_viewport().set_input_as_handled()

func update_stats():
	if not is_instance_valid(player) or not is_instance_valid(main_game):
		stats_label.text = "Loading stats..."
		return
	
	var stats_text = ""
	stats_text += "═══════════════════════════\n"
	stats_text += "     NEBULA REVENANT     \n"
	stats_text += "═══════════════════════════\n\n"
	
	# Time
	var time = main_game.game_time
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	stats_text += "⏱️  Time: %02d:%02d\n" % [minutes, seconds]
	stats_text += "📊 Level: %d\n" % player.player_stats.level
	stats_text += "💎 XP: %d / %d\n" % [player.player_stats.current_xp, player.player_stats.xp_to_next_level]
	stats_text += "\n"
	
	# Player Stats
	stats_text += "═══════════════════════════\n"
	stats_text += "      PLAYER STATS      \n"
	stats_text += "═══════════════════════════\n"
	stats_text += "❤️  HP: %d / %d\n" % [int(player.player_stats.current_health), int(player.player_stats.max_health)]
	stats_text += "⚡ Damage: +%.0f%%\n" % ((player.player_stats.damage_mult - 1.0) * 100)
	stats_text += "🏃 Speed: %.0f\n" % player.player_stats.speed
	stats_text += "⚔️  Attack Speed: +%.0f%%\n" % ((player.player_stats.attack_speed_mult - 1.0) * 100)
	stats_text += "🩸 Lifesteal: %.1f%%\n" % (player.player_stats.lifesteal * 100)
	stats_text += "💚 Health Regen: %.1f HP/sec\n" % player.player_stats.health_regen
	stats_text += "🎯 Crit Chance: %.1f%%\n" % (player.player_stats.crit_chance * 100)
	stats_text += "💥 Crit Damage: %.0fx\n" % player.player_stats.crit_damage
	stats_text += "🛡️  Armor: %d\n" % player.player_stats.armor
	stats_text += "🧲 Pickup Radius: %.0f\n" % player.player_stats.pickup_radius
	stats_text += "🍀 Luck: %d\n" % player.player_stats.luck
	stats_text += "\n"
	
	# Weapons
	stats_text += "═══════════════════════════\n"
	stats_text += "        WEAPONS        \n"
	stats_text += "═══════════════════════════\n"
	if player.player_stats.current_weapons.size() > 0:
		for weapon_key in player.player_stats.current_weapons:
			if player.weapon_data.has(weapon_key):
				var weapon = player.weapon_data[weapon_key]
				stats_text += "\n🔫 %s (Lvl %d)\n" % [weapon.name, weapon.level]
				stats_text += "   • Damage: %.0f\n" % weapon.damage
				stats_text += "   • Fire Rate: %.1f/sec\n" % weapon.attack_speed
				if weapon.projectiles > 1:
					stats_text += "   • Projectiles: %d\n" % weapon.projectiles
				if weapon.pierce > 0:
					stats_text += "   • Pierce: %d\n" % weapon.pierce
				if weapon.knockback > 0:
					stats_text += "   • Knockback: %.0f\n" % weapon.knockback
				if weapon.aoe > 0:
					stats_text += "   • AOE Radius: %.0f\n" % weapon.aoe
	else:
		stats_text += "No weapons equipped\n"
	
	stats_text += "\n"
	
	# Weapon Damage Dealt
	stats_text += "═══════════════════════════\n"
	stats_text += "     DAMAGE BREAKDOWN     \n"
	stats_text += "═══════════════════════════\n"
	if player.weapon_damage_dealt.size() > 0:
		var total_damage = 0
		for weapon_key in player.weapon_damage_dealt:
			total_damage += player.weapon_damage_dealt[weapon_key]
		
		# Merge "bullet" into "pistol" for display
		var merged_damage = {}
		for weapon_key in player.weapon_damage_dealt:
			var display_key = weapon_key
			if weapon_key == "bullet":
				display_key = "pistol"
			
			if not merged_damage.has(display_key):
				merged_damage[display_key] = 0
			merged_damage[display_key] += player.weapon_damage_dealt[weapon_key]
		
		for weapon_key in merged_damage:
			var dmg = merged_damage[weapon_key]
			var percent = (dmg / float(total_damage)) * 100 if total_damage > 0 else 0
			stats_text += "💢 %s: %.0f (%.1f%%)\n" % [weapon_key.capitalize(), dmg, percent]
		
		stats_text += "\n📈 TOTAL DAMAGE: %.0f\n" % total_damage
	else:
		stats_text += "No damage tracked yet\n"
	
	stats_text += "\n"
	
	# Combat Stats
	stats_text += "═══════════════════════════\n"
	stats_text += "       COMBAT STATS      \n"
	stats_text += "═══════════════════════════\n"
	stats_text += "💀 Enemies Killed: %d\n" % main_game.enemies_killed
	stats_text += "👹 Bosses Defeated: %d\n" % main_game.bosses_defeated
	# Check if property exists properly
	if "current_enemy_count" in main_game:
		stats_text += "🎯 Enemies On Screen: %d / %d\n" % [main_game.current_enemy_count, main_game.MAX_ENEMIES_ON_SCREEN]
	
	stats_text += "\n"
	
	# Items Collected
	stats_text += "═══════════════════════════\n"
	stats_text += "    ITEMS COLLECTED     \n"
	stats_text += "═══════════════════════════\n"
	if main_game.items_collected.size() > 0:
		# Group by tier
		var by_tier = {"purple": [], "green": [], "blue": [], "yellow": []}
		for item in main_game.items_collected:
			by_tier[item.tier].append(item)
		
		# Count by tier
		var tier_counts = {
			"purple": by_tier["purple"].size(),
			"green": by_tier["green"].size(),
			"blue": by_tier["blue"].size(),
			"yellow": by_tier["yellow"].size()
		}
		
		stats_text += "Total Items: %d\n" % main_game.items_collected.size()
		stats_text += "  ★ Legendary: %d\n" % tier_counts["purple"]
		stats_text += "  ◆ Rare: %d\n" % tier_counts["green"]
		stats_text += "  ● Uncommon: %d\n" % tier_counts["blue"]
		stats_text += "  ○ Common: %d\n\n" % tier_counts["yellow"]
		
		# Show all items with details
		for tier in ["purple", "green", "blue", "yellow"]:
			if by_tier[tier].size() > 0:
				var tier_icon = {"purple": "★", "green": "◆", "blue": "●", "yellow": "○"}
				
				for item in by_tier[tier]:
					stats_text += "%s %s\n" % [tier_icon[tier], item.name]
					stats_text += "   %s\n" % item.description
	else:
		stats_text += "No items collected yet\n"
	
	stats_text += "\n═══════════════════════════\n"
	
	stats_label.text = stats_text
	print("✅ Stats updated! Lines: %d" % stats_text.count("\n"))

func _on_resume_pressed():
	print("▶️ Resuming game...")
	get_tree().paused = false
	queue_free()

func _on_quit_pressed():
	print("🚪 Quitting game...")
	get_tree().paused = false
	get_tree().quit()
