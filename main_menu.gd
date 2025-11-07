# main_menu.gd - UPDATED: Better unlock info!
extends Control

@onready var start_button = $VBoxContainer/StartButton
@onready var upgrades_button = $VBoxContainer/UpgradesButton
@onready var stats_button = $VBoxContainer/StatsButton
@onready var quit_button = $VBoxContainer/QuitButton
@onready var currency_label = $CurrencyPanel/CurrencyLabel

@onready var upgrade_panel = $UpgradePanel
@onready var stats_panel = $StatsPanel

# Reference to SaveManager autoload
var save_manager

func _ready():
	# Get SaveManager reference
	if has_node("/root/SaveManager"):
		save_manager = get_node("/root/SaveManager")
	
	# Hide panels initially
	if upgrade_panel:
		upgrade_panel.hide()
	if stats_panel:
		stats_panel.hide()
	
	# Connect buttons
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if upgrades_button:
		upgrades_button.pressed.connect(_on_upgrades_pressed)
	if stats_button:
		stats_button.pressed.connect(_on_stats_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	update_currency_display()

func update_currency_display():
	if currency_label and save_manager:
		var shards = save_manager.get_shards()
		currency_label.text = "💎 Nebula Shards: %d" % shards

func _on_start_pressed():
	# NEW: Go to character select instead of directly to game
	get_tree().change_scene_to_file("res://CharacterSelect.tscn")

func _on_upgrades_pressed():
	if upgrade_panel:
		upgrade_panel.show()
		populate_upgrades()

func _on_stats_pressed():
	if stats_panel:
		stats_panel.show()
		populate_stats()

func _on_quit_pressed():
	get_tree().quit()

func populate_upgrades():
	if not upgrade_panel or not save_manager:
		return
	
	# This will be filled with upgrade buttons
	var upgrade_list = upgrade_panel.get_node_or_null("ScrollContainer/UpgradeList")
	if not upgrade_list:
		return
	
	# Clear existing upgrades
	for child in upgrade_list.get_children():
		child.queue_free()
	
	# Define all upgrades with costs
	var upgrade_definitions = [
		{
			"id": "starting_damage",
			"name": "Starting Damage",
			"desc": "+5% Damage at start",
			"base_cost": 50,
			"max_level": 10
		},
		{
			"id": "starting_health",
			"name": "Starting Health",
			"desc": "+20 Max HP at start",
			"base_cost": 40,
			"max_level": 10
		},
		{
			"id": "starting_speed",
			"name": "Starting Speed",
			"desc": "+5% Move Speed at start",
			"base_cost": 60,
			"max_level": 10
		},
		{
			"id": "starting_luck",
			"name": "Starting Luck",
			"desc": "+1 Luck at start",
			"base_cost": 100,
			"max_level": 5
		},
		{
			"id": "xp_boost",
			"name": "XP Gain",
			"desc": "+10% XP from all sources",
			"base_cost": 80,
			"max_level": 5
		},
		{
			"id": "currency_boost",
			"name": "Shard Drop Rate",
			"desc": "+20% more Shards",
			"base_cost": 70,
			"max_level": 5
		},
		{
			"id": "starting_weapon_slot",
			"name": "Extra Weapon Slot",
			"desc": "Start with 7 weapon slots",
			"base_cost": 500,
			"max_level": 1
		},
		{
			"id": "reroll_count",
			"name": "Level Up Reroll",
			"desc": "Reroll upgrade choices",
			"base_cost": 200,
			"max_level": 3
		},
	]
	
	# Create upgrade buttons
	for upgrade_def in upgrade_definitions:
		var current_level = save_manager.get_upgrade_level(upgrade_def.id)
		var cost = int(upgrade_def.base_cost * pow(1.5, current_level))
		
		var upgrade_button = create_upgrade_button(
			upgrade_def.name,
			upgrade_def.desc,
			upgrade_def.id,
			current_level,
			upgrade_def.max_level,
			cost
		)
		
		upgrade_list.add_child(upgrade_button)

func create_upgrade_button(title: String, description: String, upgrade_id: String, 
							current_level: int, max_level: int, cost: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(500, 80)
	
	# Check if maxed
	if current_level >= max_level:
		button.text = "%s [MAXED]\nLevel: %d/%d" % [title, current_level, max_level]
		button.disabled = true
	else:
		var can_afford = save_manager.get_shards() >= cost
		button.text = "%s (Level %d/%d)\n%s\nCost: %d 💎" % [title, current_level, max_level, description, cost]
		button.disabled = not can_afford
	
	button.pressed.connect(_on_upgrade_button_pressed.bind(upgrade_id, cost))
	
	return button

func _on_upgrade_button_pressed(upgrade_id: String, cost: int):
	if save_manager.purchase_upgrade(upgrade_id, cost):
		update_currency_display()
		populate_upgrades()  # Refresh the list
		print("✅ Upgrade purchased: %s" % upgrade_id)
	else:
		print("❌ Not enough shards!")

func populate_stats():
	if not stats_panel or not save_manager:
		return
	
	var stats_list = stats_panel.get_node_or_null("ScrollContainer/StatsList")
	if not stats_list:
		return
	
	# Clear existing
	for child in stats_list.get_children():
		child.queue_free()
	
	# Add stat labels
	var data = save_manager.save_data
	
	add_stat_label(stats_list, "=== Career Stats ===", 24, Color(1, 0.9, 0.3))
	add_stat_label(stats_list, "Total Runs: %d" % data.runs_completed, 18)
	add_stat_label(stats_list, "Lifetime Shards: %d" % data.lifetime_shards, 18)
	add_stat_label(stats_list, "Total Kills: %d" % data.total_kills, 18)
	
	var minutes = int(data.best_time / 60)
	var seconds = int(data.best_time) % 60
	add_stat_label(stats_list, "Best Time: %d:%02d" % [minutes, seconds], 18)
	add_stat_label(stats_list, "Highest Level: %d" % data.highest_level, 18)
	
	# Character unlock status - IMPROVED!
	add_stat_label(stats_list, "", 12)  # Spacer
	add_stat_label(stats_list, "=== Unlockable Characters ===", 24, Color(1, 0.4, 0.8))
	add_stat_label(stats_list, "", 8)  # Small spacer
	
	if data.has("unlocks"):
		var unlocks = data.unlocks
		
		# Swordmaiden status with detailed info
		if unlocks.swordmaiden_unlocked:
			add_stat_label(stats_list, "⚔️ SWORDMAIDEN", 22, Color(1, 0.4, 0.8))
			add_stat_label(stats_list, "✅ UNLOCKED!", 18, Color(0.4, 1, 0.4))
			add_stat_label(stats_list, "Melee warrior with 150 HP", 16, Color(0.8, 0.8, 0.8))
		else:
			var progress = unlocks.swordmaiden_challenge_best
			add_stat_label(stats_list, "⚔️ SWORDMAIDEN", 22, Color(1, 0.4, 0.8))
			
			if progress >= 30:
				# Challenge complete, ready to buy
				add_stat_label(stats_list, "🏆 Challenge Complete!", 18, Color(0.4, 1, 0.4))
				add_stat_label(stats_list, "Ready to purchase for 5000 Shards", 16, Color(1, 0.9, 0.3))
				add_stat_label(stats_list, "Go to Character Select to unlock!", 16, Color(1, 0.9, 0.3))
			else:
				# Still working on challenge
				add_stat_label(stats_list, "🔒 LOCKED", 18, Color(0.8, 0.5, 0.5))
				add_stat_label(stats_list, "Challenge: Reach Level 30", 16, Color(0.8, 0.8, 0.8))
				add_stat_label(stats_list, "Progress: %d/30" % progress, 16, Color(0.9, 0.9, 0.9))
				add_stat_label(stats_list, "Then purchase for 5000 Shards", 14, Color(0.7, 0.7, 0.7))
		
		add_stat_label(stats_list, "", 8)  # Small spacer
		add_stat_label(stats_list, "───────────────", 16, Color(0.5, 0.5, 0.5))
		add_stat_label(stats_list, "", 8)
		
		# Coming soon section
		add_stat_label(stats_list, "🔮 COMING SOON", 20, Color(0.6, 0.6, 0.8))
		add_stat_label(stats_list, "More characters will be added!", 14, Color(0.7, 0.7, 0.7))
	else:
		# Fallback if unlocks data doesn't exist
		add_stat_label(stats_list, "⚔️ Swordmaiden: Coming Soon!", 18, Color(0.8, 0.5, 0.5))

func add_stat_label(parent: Node, text: String, font_size: int = 18, color: Color = Color.WHITE):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
