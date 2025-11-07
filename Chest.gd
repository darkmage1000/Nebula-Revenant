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
			"description": "+1 HP/sec Regeneration",
			"effect_type": "stat",
			"stat": "health_regen",
			"value": 1.0,
			"icon_color": Color(1.0, 0.9, 0.3)
		},
		{
			"name": "Worn Gloves",
			"description": "+10% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.1,
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
			"description": "+10% Damage",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 0.1,
			"icon_color": Color(1.0, 0.9, 0.3)
		}
	],
	"blue": [  # UNCOMMON - Better boosts + special effects
		{
			"name": "Vampire Fang",
			"description": "+3% Lifesteal",  # REDUCED from 8% - was too strong
			"effect_type": "stat",
			"stat": "lifesteal",
			"value": 0.03,
			"icon_color": Color(0.3, 0.6, 1.0)
		},
		{
			"name": "Energy Drink",
			"description": "+25% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.25,
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
			"description": "+2 HP/sec Regeneration",  # REDUCED from 5 - was too strong
			"effect_type": "stat",
			"stat": "health_regen",
			"value": 2.0,
			"icon_color": Color(0.2, 1.0, 0.3)
		},
		{
			"name": "Berserker's Rage",
			"description": "+50% Damage",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 0.5,
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
			"description": "+40% Attack Speed",
			"effect_type": "stat",
			"stat": "attack_speed_mult",
			"value": 0.4,
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
			"description": "x2 Damage Forever",
			"effect_type": "stat",
			"stat": "damage_mult",
			"value": 1.0,  # Multiplies by 2
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Immortal's Blessing",
			"description": "+300 HP + 4 HP/sec Regen",  # REDUCED regen from 10
			"effect_type": "multi",
			"effects": [
				{"stat": "max_health", "value": 300},
				{"stat": "health_regen", "value": 4.0}
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
			"description": "x2 Attack Speed + +50% Move Speed",
			"effect_type": "multi",
			"effects": [
				{"stat": "attack_speed_mult", "value": 1.0},  # x2
				{"stat": "speed", "value": 0.5}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Soul Reaper",
			"description": "+10% Lifesteal + +100% Damage",  # REDUCED lifesteal from 25%
			"effect_type": "multi",
			"effects": [
				{"stat": "lifesteal", "value": 0.10},
				{"stat": "damage_mult", "value": 1.0}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		},
		{
			"name": "Apocalypse Engine",
			"description": "+75% All Stats",
			"effect_type": "multi",
			"effects": [
				{"stat": "damage_mult", "value": 0.75},
				{"stat": "attack_speed_mult", "value": 0.75},
				{"stat": "speed", "value": 0.75},
				{"stat": "aoe_mult", "value": 0.75}
			],
			"icon_color": Color(0.8, 0.3, 1.0)
		}
	]
}

var selected_item: Dictionary = {}
var is_opened: bool = false
var rolled_rarity: String = ""

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
	
	if sprite:
		sprite.modulate = tier_colors.get(tier, Color.WHITE)
	if glow:
		glow.modulate = tier_colors.get(tier, Color.WHITE)

func animate_chest():
	# Bobbing animation
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "position:y", position.y - 10, 1.0)
	tween.tween_property(self, "position:y", position.y, 1.0)
	
	# Glow pulse
	if glow:
		var glow_tween = create_tween()
		glow_tween.set_loops()
		glow_tween.tween_property(glow, "scale", Vector2(1.2, 1.2), 0.8)
		glow_tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.8)

func _on_body_entered(body: Node2D):
	if body.name == "Player" and not is_opened:
		open_chest()

func open_chest():
	if is_opened:
		return
	
	is_opened = true
	
	# DON'T PAUSE - just apply item directly
	# Roll for rarity first
	rolled_rarity = roll_rarity()
	
	# Select item from rolled rarity
	select_item_from_rarity(rolled_rarity)
	
	# Apply item immediately
	apply_item_to_player()
	
	# Track in main game
	var main_game = get_tree().root.get_node_or_null("MainGame")
	if main_game and "items_collected" in main_game:
		if selected_item.has("name") and selected_item.has("description"):
			main_game.items_collected.append({
				"name": selected_item.name,
				"tier": rolled_rarity,
				"description": selected_item.description
			})
			print("✨ Collected [%s] %s: %s" % [rolled_rarity.to_upper(), selected_item.name, selected_item.description])
	
	# Visual feedback
	play_open_animation()

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
	var player = get_tree().get_first_node_in_group("player")
	if not is_instance_valid(player):
		print("ERROR: Could not find player!")
		return
	
	match selected_item.effect_type:
		"stat":
			if selected_item.has("stat") and selected_item.has("value"):
				player.upgrade_player_stat(selected_item.stat, selected_item.value)
		"multi":
			if selected_item.has("effects"):
				for effect in selected_item.effects:
					if effect.has("stat") and effect.has("value"):
						player.upgrade_player_stat(effect.stat, effect.value)
			if selected_item.has("weapon_effect") and "player_stats" in player and "current_weapons" in player.player_stats:
				# Apply to all weapons
				for weapon_key in player.player_stats.current_weapons:
					if selected_item.weapon_effect.has("upgrade") and selected_item.weapon_effect.has("value"):
						player.upgrade_weapon(
							weapon_key,
							selected_item.weapon_effect.upgrade,
							selected_item.weapon_effect.value
						)
		"all_weapons":
			if "player_stats" in player and "current_weapons" in player.player_stats:
				for weapon_key in player.player_stats.current_weapons:
					if selected_item.has("upgrade") and selected_item.has("value"):
						player.upgrade_weapon(
							weapon_key,
							selected_item.upgrade,
							selected_item.value
						)
	
	print("\u2728 Applied item: ", selected_item.name)

func play_open_animation():
	# Chest opens and disappears
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.5, 1.5), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func(): queue_free())
