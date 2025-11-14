# Chest.gd \u2013 FIXED: Shows rarity animation and only gives 1 item
extends Area2D

signal chest_opened(item_data: Dictionary)

# Chest tier - set by main_game when spawning
var tier: String = "yellow"  # yellow, blue, green, purple

# Rarity probabilities for the roll animation
var rarity_weights = {
	"yellow": 50,  # 50% chance
	"blue": 30,    # 30% chance  
	"green": 15,   # 15% chance
	"purple": 5    # 5% chance
}

# Item database with all tiers
var item_pool = {
	"yellow": [  # COMMON - Basic stat boosts
		{
			"name": "Rusty Compass",
			"description": "+15% Move Speed",
			"effect_type": "stat",
			"stat": "speed",
			"value": 0.15,
			"icon_color": Color(1.0, 0.9, 0.3)
		},
		{
			"name": "Old Bandage",
			"description": "+0.5 HP/sec Regeneration",
			"effect_type": "stat",
			"stat": "health_regen",
			"value": 0.5,
			"icon_color": Color(1.0, 0.9, 0.3)
		},
		{
			"name": "Worn Gloves",
			"description": "+5% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.05,
			"icon_color": Color(1.0, 0.9, 0.3)
		},
		{
			"name": "Tattered Armor",
			"description": "+30 Max HP",
			"effect_type": "stat",
			"stat": "max_health",
			"value": 30,
			"icon_color": Color(1.0, 0.9, 0.3)
		},
		{
			"name": "Cracked Lens",
			"description": "+5% Damage",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 0.05,
			"icon_color": Color(1.0, 0.9, 0.3)
		}
	],
	"blue": [  # UNCOMMON - Better boosts + special effects
		{
			"name": "Vampire Fang",
			"description": "+1.5% Lifesteal",  # HEAVILY NERFED - was 3%, now 1.5%
			"effect_type": "stat",
			"stat": "lifesteal",
			"value": 0.015,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Energy Drink",
			"description": "+12% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.12,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Reinforced Vest",
			"description": "+75 Max HP",
			"effect_type": "stat",
			"stat": "max_health",
			"value": 75,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Precision Scope",
			"description": "+5% Crit Chance",
			"effect_type": "stat",
			"stat": "crit_chance",
			"value": 0.05,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Explosive Rounds",
			"description": "+20% AOE Size",
			"effect_type": "stat",
			"stat": "aoe_mult",
			"value": 0.2,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Piercing Ammo",
			"description": "+1 Projectile Pierce",
			"effect_type": "all_weapons",
			"upgrade": "pierce",
			"value": 1,
			"icon_color": Color(0.3, 0.6, 1.0)
		}
	],
	"green": [  # RARE - Powerful effects
		{
			"name": "Phoenix Feather",
			"description": "+1 HP/sec Regeneration",  # HEAVILY NERFED - was 2, now 1
			"effect_type": "stat",
			"stat": "health_regen",
			"value": 1.0,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Berserker's Rage",
			"description": "+25% Damage",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 0.25,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Titan's Heart",
			"description": "+150 Max HP",
			"effect_type": "stat",
			"stat": "max_health",
			"value": 150,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Time Warp Crystal",
			"description": "+20% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.2,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Multi-Shot Module",
			"description": "+2 Projectiles (All Weapons)",
			"effect_type": "stat",
			"stat": "projectiles",
			"value": 2,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Critical Strike Core",
			"description": "+15% Crit Chance",
			"effect_type": "stat",
			"stat": "crit_chance",
			"value": 0.15,
			"icon_color": Color(0.2, 1.0, 0.3)
		}
	],
	"purple": [  # LEGENDARY - Game-changing items
		{
			"name": "God Slayer's Wrath",
			"description": "+50% Damage",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 0.5,  # NERFED - was 1.0 (x2), now 0.5 (+50%)
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Immortal's Blessing",
			"description": "+300 HP + 2 HP/sec Regen",  # HEAVILY NERFED - was 4, now 2
			"effect_type": "multi",
			"effects": [
				{"stat": "max_health", "value": 300},
				{"stat": "health_regen", "value": 2.0}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Infinity Gauntlet",
			"description": "+5 Projectiles + +3 Pierce",
			"effect_type": "multi",
			"effects": [
				{"stat": "projectiles", "value": 5},
			],
			"weapon_effect": {"upgrade": "pierce", "value": 3},
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Chrono Accelerator",
			"description": "+50% Attack Speed + +50% Move Speed",
			"effect_type": "multi",
			"effects": [
				{"stat": "attack_speed_mult", "value": 0.5},  # +50%
				{"stat": "speed", "value": 0.5}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Soul Reaper",
			"description": "+5% Lifesteal + +50% Damage",  # HEAVILY NERFED - lifesteal 10→5%, damage 100→50%
			"effect_type": "multi",
			"effects": [
				{"stat": "lifesteal", "value": 0.05},
				{"stat": "damage_mult", "value": 0.5}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Apocalypse Engine",
			"description": "+40% Damage, +35% Other Stats",
			"effect_type": "multi",
			"effects": [
				{"stat": "damage_mult", "value": 0.40},
				{"stat": "attack_speed_mult", "value": 0.35},
				{"stat": "speed", "value": 0.35},
				{"stat": "aoe_mult", "value": 0.35}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		}
	]
}

var selected_item: Dictionary = {}
var is_opened: bool = false
var rolled_rarity: String = ""

# Store tween references so we can properly clean them up
var bob_tween: Tween = null
var glow_tween: Tween = null

@onready var sprite = $Sprite2D
@onready var glow = $Glow

func _ready():
	add_to_group("chest")
	
	# Ensure chest can detect player
	collision_layer = 1
	collision_mask = 1
	monitoring = true
	monitorable = true
	
	# Set chest color based on tier
	update_chest_visual()
	
	# Animate chest (bobbing + glow)
	animate_chest()
	
	# Connect signal if not already connected
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func update_chest_visual():
	var tier_colors = {
		"yellow": Color(1.0, 0.9, 0.3),
		"blue": Color(0.3, 0.6, 1.0),
		"green": Color(0.2, 1.0, 0.3),
		"purple": Color(0.8, 0.3, 1.0)
	}

	if is_instance_valid(sprite):
		sprite.modulate = tier_colors.get(tier, Color.WHITE)
	else:
		print("WARNING: Chest sprite node not found!")

	if is_instance_valid(glow):
		glow.modulate = tier_colors.get(tier, Color.WHITE)
	else:
		print("WARNING: Chest glow node not found!")

func animate_chest():
	# Bobbing animation
	bob_tween = create_tween()
	bob_tween.set_loops()
	bob_tween.tween_property(self, "position:y", position.y - 10, 1.0)
	bob_tween.tween_property(self, "position:y", position.y, 1.0)

	# Glow pulse
	if is_instance_valid(glow):
		glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.8)
		glow_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.8)

func _on_body_entered(body: Node2D):
	# Check if body is the player using group membership instead of name
	if body.is_in_group("player") and not is_opened:
		# Immediately disable monitoring to prevent double-triggers
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
		open_chest(body)

func open_chest(player: Node2D):
	print("🎁 OPEN CHEST CALLED")
	print("   Game paused: %s" % get_tree().paused)
	print("   Is opened: %s" % is_opened)

	if is_opened:
		return

	is_opened = true

	# Disable processing (collision already disabled via set_deferred in _on_body_entered)
	set_physics_process(false)
	set_process(false)

	# Roll for rarity first
	rolled_rarity = roll_rarity()

	# Select item from rolled rarity
	select_item_from_rarity(rolled_rarity)

	# Validate selected_item before applying
	if selected_item.is_empty():
		print("ERROR: No item was selected from chest!")
		play_open_animation()
		return

	# Check for eligible evolutions BEFORE applying item
	print("🔍 Checking for eligible evolutions...")
	var eligible_evolutions = get_eligible_evolutions(player)
	print("✅ Found %d eligible evolutions" % eligible_evolutions.size())

	if eligible_evolutions.size() > 0:
		print("📋 Showing evolution menu...")
		# Show evolution menu (it will pause the game after physics frame completes)
		show_evolution_menu(player, eligible_evolutions)
		print("📋 show_evolution_menu() returned")
	else:
		# No evolutions available - show item UI
		print("📦 No evolutions, applying item normally...")
		apply_item_to_player()
		track_item_collection()
		play_open_animation()
		show_item_ui()

func track_item_collection():
	# Track in main game
	var main_game = get_tree().root.get_node_or_null("MainGame")
	if is_instance_valid(main_game) and "items_collected" in main_game:
		if selected_item.has("name") and selected_item.has("description"):
			main_game.items_collected.append({
				"name": selected_item.name,
				"tier": rolled_rarity,
				"description": selected_item.description
			})
			print("✨ Collected [%s] %s: %s" % [rolled_rarity.to_upper(), selected_item.name, selected_item.description])

func get_eligible_evolutions(player: Node2D) -> Array:
	var eligible = []

	if not player or not player.has_method("get_weapon_level"):
		print("⚠️ Evolution check: player invalid or missing get_weapon_level method")
		return eligible

	# Only check weapons the player currently has
	var current_weapons = player.player_stats.get("current_weapons", [])
	print("🔍 Checking evolutions for %d weapons: %s" % [current_weapons.size(), current_weapons])

	for weapon_key in current_weapons:
		# Skip if weapon doesn't have evolution data
		if not player.weapon_evolutions.has(weapon_key):
			print("   ⚠️ %s: No evolution data" % weapon_key)
			continue

		var weapon_level = player.get_weapon_level(weapon_key)
		var already_evolved = player.weapon_evolutions[weapon_key]["evolved"]

		print("   🔸 %s: Level %d, Evolved: %s" % [weapon_key, weapon_level, already_evolved])

		if weapon_level >= 10 and not already_evolved:
			# This weapon can evolve
			var paths = player.weapon_evolutions[weapon_key]["paths"]
			print("   ✅ %s eligible for evolution! (%d paths)" % [weapon_key, paths.size()])
			for path_id in paths.keys():
				eligible.append({
					"weapon_key": weapon_key,
					"evolution_id": path_id,
					"data": paths[path_id]
				})

	print("🎯 Total eligible evolutions: %d" % eligible.size())
	return eligible

func show_evolution_menu(player: Node2D, eligible: Array):
	# Randomly pick up to 3 evolution options
	eligible.shuffle()
	var selected_options = eligible.slice(0, min(3, eligible.size()))

	print("📋 Creating evolution menu with %d options" % selected_options.size())

	# Create evolution menu UI
	var evolution_menu = preload("res://EvolutionMenu.tscn").instantiate()
	evolution_menu.player = player

	# Connect signals
	evolution_menu.evolution_selected.connect(func(weapon_key, evolution_id):
		print("✅ Evolution selected: %s -> %s" % [weapon_key, evolution_id])
		player.evolve_weapon(weapon_key, evolution_id)
		apply_item_to_player()
		track_item_collection()
		evolution_menu.queue_free()
		get_tree().paused = false
		play_open_animation()
	)

	evolution_menu.skip_pressed.connect(func():
		print("⏭️ Evolution skipped")
		apply_item_to_player()
		track_item_collection()
		evolution_menu.queue_free()
		get_tree().paused = false
		play_open_animation()
	)

	# Add to UILayer so it renders on top of everything
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if not ui_layer:
		print("⚠️ ERROR: UILayer not found! Trying root instead...")
		get_tree().root.add_child(evolution_menu)
	else:
		ui_layer.add_child(evolution_menu)
		print("✅ Evolution menu added to UILayer")

	print("   Visible: %s" % evolution_menu.visible)
	print("   Layer: %s" % evolution_menu.layer)
	print("   Parent: %s" % evolution_menu.get_parent().name)

	# Set available evolutions - menu will pause AFTER rendering
	print("⏸️ Setting available evolutions...")
	evolution_menu.set_available_evolutions(selected_options)

	# CanvasLayer handles rendering layer automatically
	print("   Layer: %d (CanvasLayer always renders on top)" % evolution_menu.layer)
	print("✅ Setup complete - menu will pause when ready")

func roll_rarity() -> String:
	# Calculate total weight
	var total_weight = 0
	for weight in rarity_weights.values():
		total_weight += weight
	
	# Roll
	var roll = randf() * total_weight
	var current_weight = 0
	
	for rarity in ["yellow", "blue", "green", "purple"]:
		current_weight += rarity_weights[rarity]
		if roll <= current_weight:
			return rarity
	
	return "yellow"  # Fallback

func select_item_from_rarity(rarity: String):
	var items = item_pool.get(rarity, item_pool["yellow"])
	if items.size() > 0:
		selected_item = items[randi() % items.size()].duplicate()
		print("Chest rolled %s rarity: %s" % [rarity.to_upper(), selected_item.name])

func apply_item_to_player():
	# Find player with multiple safety checks
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		print("ERROR: Could not find player in 'player' group!")
		return

	# Validate player has required methods
	if not player.has_method("upgrade_player_stat"):
		print("ERROR: Player is missing upgrade_player_stat method!")
		return

	# Validate selected_item has effect_type
	if not selected_item.has("effect_type"):
		print("ERROR: Selected item has no effect_type!")
		return

	match selected_item.effect_type:
		"stat":
			if selected_item.has("stat") and selected_item.has("value"):
				player.upgrade_player_stat(selected_item.stat, selected_item.value)
			else:
				print("ERROR: Stat item missing 'stat' or 'value' field!")
		"multi":
			if selected_item.has("effects"):
				for effect in selected_item.effects:
					if effect.has("stat") and effect.has("value"):
						player.upgrade_player_stat(effect.stat, effect.value)
					else:
						print("WARNING: Multi-effect missing 'stat' or 'value' field, skipping")
			if selected_item.has("weapon_effect") and "player_stats" in player and "current_weapons" in player.player_stats:
				# Apply to all weapons
				if player.has_method("upgrade_weapon"):
					for weapon_key in player.player_stats.current_weapons:
						if selected_item.weapon_effect.has("upgrade") and selected_item.weapon_effect.has("value"):
							player.upgrade_weapon(
								weapon_key,
								selected_item.weapon_effect.upgrade,
								selected_item.weapon_effect.value
							)
		"all_weapons":
			if "player_stats" in player and "current_weapons" in player.player_stats:
				if player.has_method("upgrade_weapon"):
					for weapon_key in player.player_stats.current_weapons:
						if selected_item.has("upgrade") and selected_item.has("value"):
							player.upgrade_weapon(
								weapon_key,
								selected_item.upgrade,
								selected_item.value
							)
				else:
					print("ERROR: Player is missing upgrade_weapon method!")

	if selected_item.has("name"):
		print("✨ Applied item: ", selected_item.name)
	else:
		print("✨ Applied item (unnamed)")

func play_open_animation():
	# CRITICAL: Stop the looping animation tweens first to prevent crash
	if bob_tween and bob_tween.is_valid():
		bob_tween.kill()
		bob_tween = null

	if glow_tween and glow_tween.is_valid():
		glow_tween.kill()
		glow_tween = null

	# Disconnect all signals to prevent issues during cleanup
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	# Create simple fade-out animation
	var tween = create_tween()
	if not tween:
		# If tween creation fails, just free immediately
		call_deferred("queue_free")
		return

	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)

	# Use call_deferred to ensure cleanup happens after physics
	tween.finished.connect(func():
		if is_instance_valid(self):
			call_deferred("queue_free")
	)

	print("🎬 Chest animation started, will free in 0.3s")

func show_item_ui():
	# Show the ItemUI to display what the player got
	const ITEM_UI_SCENE = preload("res://ItemUI.tscn")

	# PAUSE GAME to show item
	get_tree().paused = true

	# Get UILayer
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if not ui_layer:
		print("ERROR: Could not find UILayer for ItemUI!")
		get_tree().paused = false  # Unpause if we can't show UI
		return

	# Create item UI
	var item_ui = ITEM_UI_SCENE.instantiate()
	item_ui.process_mode = Node.PROCESS_MODE_ALWAYS  # Allow UI to work while paused
	item_ui.set_item(selected_item, rolled_rarity)

	# Connect take button to unpause
	if item_ui.has_node("Panel/TakeButton"):
		var take_button = item_ui.get_node("Panel/TakeButton")
		take_button.pressed.connect(func():
			get_tree().paused = false
			print("⏸️ Game unpaused after taking item")
		)

	ui_layer.add_child(item_ui)
	print("✨ Showing item UI for: %s" % selected_item.get("name", "Unknown"))
