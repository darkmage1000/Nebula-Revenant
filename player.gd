# player.gd – NERFED SPEED + CHARACTER SYSTEM
extends CharacterBody2D

signal health_depleted

# ==============================================================
# 1. PLAYER STATS
# ==============================================================
var player_stats = {
	"level": 1,
	"current_xp": 0,
	"xp_to_next_level": 30,
	"max_health": 100.0,
	"current_health": 100.0,
	"health_regen": 0.2,
	"shield": 50.0,
	"shield_recharge_rate": 5.0,
	"lifesteal": 0.0,
	"armor": 0,
	"speed": 140.0,  # HEAVILY NERFED - just under mob base speed (150) for more challenge!
	"attack_speed_mult": 1.0,
	"attack_range_mult": 1.0,  # NEW: Multiplier for weapon attack ranges
	"damage_mult": 1.0,
	"aoe_mult": 1.0,
	"projectiles": 0,
	"crit_chance": 0.05,
	"crit_damage": 1.5,
	"pickup_radius": 100.0,
	"luck": 0,
	"max_weapon_slots": 3,  # Changed from 6 to 3 - weapon slots are now a meta-progression upgrade!
	"current_weapons": [],
	"character_type": "ranger"  # NEW: "ranger", "swordmaiden", or "alien_monk"
}

# ==============================================================
# 2. DAMAGE TRACKING (for lifesteal) + RUN STATS
# ==============================================================
var weapon_damage_dealt: Dictionary = {}

var run_stats: Dictionary = {
	"start_time": 0,
	"total_xp_gained": 0,
	"kills": 0,
	"total_damage_dealt": 0,
	"shards_collected": 0
}

# ==============================================================
# 2.5 REVIVE SYSTEM
# ==============================================================
var revives_remaining: int = 0
var revive_invincibility_timer: float = 0.0

# ==============================================================
# 2.6 POWERUP TRACKING (prevents stacking)
# ==============================================================
var active_powerups: Dictionary = {}  # Tracks active powerup IDs to prevent stacking
var powerup_id_counter: int = 0  # Unique ID for each powerup activation

# ==============================================================
# 3. WEAPON DATABASE – ALL STATS INCLUDED
# ==============================================================
var weapon_data = {
	"pistol": {
		"name": "Pistol", "scene": preload("res://Pistol.tscn"),
		"damage": 12, "attack_speed": 1.5, "projectiles": 1,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 0, "distance": 0,
		"level": 1
	},
	"shotgun": {
		"name": "Shotgun", "scene": preload("res://Shotgun.tscn"),
		"damage": 8, "attack_speed": 0.8, "projectiles": 4,
		"pierce": 0, "knockback": 50, "spread": 0.4,
		"poison": false, "burn": false, "aoe": 0, "distance": 0,
		"level": 0
	},
	"grenade": {
		"name": "Grenade", "scene": preload("res://Grenade.tscn"),
		"damage": 50, "attack_speed": 0.5, "projectiles": 1,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 150, "distance": 300,
		"level": 0
	},
	"aura": {
		"name": "Radiation Aura", "scene": preload("res://RadiationAura.tscn"),
		"damage": 8, "attack_speed": 5.0, "projectiles": 0,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 150, "distance": 0,
		"level": 0
	},
	"sword": {
		"name": "Energy Sword", "scene": null,  # Will create if doesn't exist
		"damage": 35, "attack_speed": 2.2, "projectiles": 0,  # BUFFED: 25→35 dmg, 2.0→2.2 speed
		"pierce": 0, "knockback": 75, "spread": 0.0,  # BUFFED: 50→75 knockback
		"poison": false, "burn": false, "aoe": 100, "distance": 130,  # BUFFED: 80→100 AOE, 100→130 range
		"level": 0, "melee": true
	},
	"lightning_spell": {
		"name": "Lightning Spell", "scene": preload("res://LightningSpell.tscn"),
		"damage": 15, "attack_speed": 1.2, "projectiles": 1,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 0, "distance": 600,
		"level": 0, "chain_targets": 1, "chain_range": 250  # NEW: Chain lightning mechanics
	},
	"laser_beam": {
		"name": "Laser Beam", "scene": preload("res://LaserBeam.tscn"),
		"damage": 5, "attack_speed": 1.0, "projectiles": 0,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 0, "distance": 175,
		"level": 0, "laser_width": 12, "cone_mode": false
	},
	"summon_spaceships": {
		"name": "Summon Spaceships", "scene": preload("res://SummonSpaceships.tscn"),
		"damage": 20, "attack_speed": 0.15, "projectiles": 2,  # Reduced from 0.286 - longer spawn interval
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 0, "distance": 0,
		"level": 0, "move_speed": 250, "speed_mult": 1.0, "size_mult": 1.0
	},
	"acid_pool": {
		"name": "Acid Pool", "scene": preload("res://AcidPool.tscn"),
		"damage": 10, "attack_speed": 0.67, "projectiles": 0,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 50, "distance": 0,
		"level": 0, "tick_rate": 0.4, "duration": 1.5
	}
}

# ==============================================================
# 4. WEAPON UPGRADE PATHS (Extended to Level 10 for Evolution System)
# ==============================================================
var weapon_upgrade_paths = {
	"pistol": [
		{"damage": 16, "projectiles": 2, "pierce": 1},
		{"damage": 20, "attack_speed": 1.8, "projectiles": 3, "pierce": 1},
		{"damage": 25, "attack_speed": 2.0, "projectiles": 4, "pierce": 2},
		{"damage": 30, "attack_speed": 2.2, "projectiles": 4, "pierce": 3},  # Level 5
		{"damage": 36, "attack_speed": 2.5, "projectiles": 5, "pierce": 3},  # Level 6
		{"damage": 43, "attack_speed": 2.8, "projectiles": 5, "pierce": 4},  # Level 7
		{"damage": 51, "attack_speed": 3.2, "projectiles": 6, "pierce": 4},  # Level 8
		{"damage": 60, "attack_speed": 3.6, "projectiles": 6, "pierce": 5, "knockback": 25},  # Level 9 - Special
		{"damage": 72, "attack_speed": 4.2, "projectiles": 7, "pierce": 6, "knockback": 40}  # Level 10 - Evolution Ready
	],
	"shotgun": [
		{"damage": 10, "projectiles": 5, "pierce": 1},
		{"damage": 12, "attack_speed": 1.0, "projectiles": 6, "pierce": 2},
		{"damage": 15, "attack_speed": 1.2, "projectiles": 7, "pierce": 2},  # Level 4
		{"damage": 18, "attack_speed": 1.4, "projectiles": 8, "pierce": 3},  # Level 5
		{"damage": 22, "attack_speed": 1.6, "projectiles": 9, "pierce": 3},  # Level 6
		{"damage": 27, "attack_speed": 1.9, "projectiles": 10, "pierce": 4},  # Level 7
		{"damage": 33, "attack_speed": 2.2, "projectiles": 11, "pierce": 4},  # Level 8
		{"damage": 40, "attack_speed": 2.6, "projectiles": 12, "pierce": 5, "spread": 0.35},  # Level 9 - Tighter spread
		{"damage": 50, "attack_speed": 3.0, "projectiles": 14, "pierce": 6, "spread": 0.3, "knockback": 80}  # Level 10 - Evolution Ready
	],
	"grenade": [
		{"damage": 60, "aoe": 180},
		{"damage": 75, "aoe": 210},
		{"damage": 90, "aoe": 240, "attack_speed": 0.6},  # Level 4
		{"damage": 110, "aoe": 270, "attack_speed": 0.7},  # Level 5
		{"damage": 135, "aoe": 300, "attack_speed": 0.8},  # Level 6
		{"damage": 165, "aoe": 340, "attack_speed": 0.95},  # Level 7
		{"damage": 200, "aoe": 380, "attack_speed": 1.1},  # Level 8
		{"damage": 250, "aoe": 430, "attack_speed": 1.3, "projectiles": 1},  # Level 9 - Multi-grenade
		{"damage": 320, "aoe": 500, "attack_speed": 1.5, "projectiles": 2}  # Level 10 - Evolution Ready
	],
	"aura": [
		{"damage": 10, "aoe": 180},
		{"damage": 12, "aoe": 210},
		{"damage": 15, "aoe": 240, "attack_speed": 5.5},  # Level 4
		{"damage": 19, "aoe": 275, "attack_speed": 6.0},  # Level 5
		{"damage": 24, "aoe": 315, "attack_speed": 6.6},  # Level 6
		{"damage": 30, "aoe": 360, "attack_speed": 7.3},  # Level 7
		{"damage": 38, "aoe": 410, "attack_speed": 8.1},  # Level 8
		{"damage": 48, "aoe": 470, "attack_speed": 9.0},  # Level 9 - Powerful
		{"damage": 62, "aoe": 550, "attack_speed": 10.0}  # Level 10 - Evolution Ready
	],
	"sword": [
		{"damage": 50, "aoe": 120, "distance": 155, "attack_speed": 2.5, "knockback": 100},  # BUFFED Level 1
		{"damage": 70, "aoe": 145, "distance": 185, "attack_speed": 2.8, "projectiles": 1, "knockback": 120},  # BUFFED Level 2
		{"damage": 95, "aoe": 170, "distance": 220, "attack_speed": 3.2, "projectiles": 2, "poison": true},  # BUFFED Level 3
		{"damage": 125, "aoe": 200, "distance": 260, "attack_speed": 3.6, "projectiles": 3, "knockback": 150},  # BUFFED Level 5
		{"damage": 160, "aoe": 235, "distance": 305, "attack_speed": 4.2, "projectiles": 4, "knockback": 180},  # BUFFED Level 6
		{"damage": 205, "aoe": 275, "distance": 355, "attack_speed": 4.8, "projectiles": 5, "knockback": 215},  # BUFFED Level 7
		{"damage": 260, "aoe": 320, "distance": 410, "attack_speed": 5.5, "projectiles": 6, "knockback": 250},  # BUFFED Level 8
		{"damage": 330, "aoe": 370, "distance": 475, "attack_speed": 6.3, "projectiles": 7, "knockback": 290},  # BUFFED Level 9 - Legendary
		{"damage": 425, "aoe": 425, "distance": 550, "attack_speed": 7.2, "projectiles": 8, "knockback": 340}  # BUFFED Level 10 - Evolution Ready
	],
	"lightning_spell": [
		{"damage": 20, "chain_targets": 2, "projectiles": 1},  # +1 chain target
		{"damage": 25, "chain_targets": 2, "projectiles": 2, "attack_speed": 1.4},  # +1 projectile
		{"damage": 35, "chain_targets": 3, "projectiles": 2, "attack_speed": 1.6, "chain_range": 300},  # +1 chain, better range
		{"damage": 45, "chain_targets": 4, "projectiles": 3, "attack_speed": 1.8, "chain_range": 350},  # Level 5
		{"damage": 60, "chain_targets": 5, "projectiles": 3, "attack_speed": 2.1, "chain_range": 400},  # Level 6
		{"damage": 78, "chain_targets": 6, "projectiles": 4, "attack_speed": 2.4, "chain_range": 450},  # Level 7
		{"damage": 100, "chain_targets": 7, "projectiles": 4, "attack_speed": 2.8, "chain_range": 500},  # Level 8
		{"damage": 130, "chain_targets": 8, "projectiles": 5, "attack_speed": 3.2, "chain_range": 600},  # Level 9 - Legendary
		{"damage": 170, "chain_targets": 10, "projectiles": 6, "attack_speed": 3.7, "chain_range": 750}  # Level 10 - Evolution Ready
	],
	"laser_beam": [
		{"damage": 6, "distance": 219, "laser_width": 16},  # +25% length, +30% width
		{"damage": 8, "distance": 274, "laser_width": 20, "attack_speed": 1.2},  # +25% more length/width, faster
		{"damage": 10, "distance": 342, "laser_width": 26, "attack_speed": 1.4, "cone_mode": true},  # Cone mode unlock
		{"damage": 13, "distance": 428, "laser_width": 34, "attack_speed": 1.6},  # Level 5
		{"damage": 17, "distance": 535, "laser_width": 44, "attack_speed": 1.9},  # Level 6
		{"damage": 22, "distance": 669, "laser_width": 57, "attack_speed": 2.2},  # Level 7
		{"damage": 29, "distance": 836, "laser_width": 74, "attack_speed": 2.6},  # Level 8
		{"damage": 38, "distance": 1045, "laser_width": 96, "attack_speed": 3.0},  # Level 9 - Legendary
		{"damage": 50, "distance": 1306, "laser_width": 125, "attack_speed": 3.5}  # Level 10 - Evolution Ready
	],
	"summon_spaceships": [
		{"damage": 25, "projectiles": 3, "speed_mult": 1.2},  # +1 ship, +20% speed
		{"damage": 30, "projectiles": 4, "speed_mult": 1.4, "size_mult": 1.2, "pierce": 2},  # +1 ship, pierce upgrade
		{"damage": 40, "projectiles": 5, "speed_mult": 1.6, "size_mult": 1.4, "pierce": 3, "attack_speed": 0.3},  # More ships, reduced spawn rate
		{"damage": 50, "projectiles": 6, "speed_mult": 1.8, "size_mult": 1.6, "pierce": 4, "attack_speed": 0.4},  # Level 5
		{"damage": 65, "projectiles": 7, "speed_mult": 2.0, "size_mult": 1.8, "pierce": 5, "attack_speed": 0.5},  # Level 6
		{"damage": 85, "projectiles": 8, "speed_mult": 2.3, "size_mult": 2.0, "pierce": 6, "attack_speed": 0.6},  # Level 7
		{"damage": 110, "projectiles": 9, "speed_mult": 2.6, "size_mult": 2.3, "pierce": 7, "attack_speed": 0.7},  # Level 8
		{"damage": 145, "projectiles": 11, "speed_mult": 3.0, "size_mult": 2.6, "pierce": 8, "attack_speed": 0.85},  # Level 9 - Legendary
		{"damage": 200, "projectiles": 13, "speed_mult": 3.5, "size_mult": 3.0, "pierce": 10, "attack_speed": 1.0}  # Level 10 - Evolution Ready
	],
	"acid_pool": [
		{"damage": 13, "duration": 2.0, "aoe": 63, "tick_rate": 0.3},  # +0.5s duration, +25% size, faster ticks
		{"damage": 16, "duration": 2.5, "aoe": 78, "tick_rate": 0.2, "attack_speed": 0.8},  # +0.5s duration, +25% size, even faster ticks
		{"damage": 20, "duration": 3.0, "aoe": 98, "tick_rate": 0.1, "attack_speed": 1.0},  # Max upgrades
		{"damage": 26, "duration": 3.5, "aoe": 123, "tick_rate": 0.08, "attack_speed": 1.2},  # Level 5
		{"damage": 34, "duration": 4.0, "aoe": 154, "tick_rate": 0.06, "attack_speed": 1.45},  # Level 6
		{"damage": 45, "duration": 4.5, "aoe": 193, "tick_rate": 0.05, "attack_speed": 1.7},  # Level 7
		{"damage": 60, "duration": 5.0, "aoe": 241, "tick_rate": 0.04, "attack_speed": 2.0},  # Level 8
		{"damage": 80, "duration": 6.0, "aoe": 302, "tick_rate": 0.03, "attack_speed": 2.4},  # Level 9 - Legendary
		{"damage": 110, "duration": 7.0, "aoe": 378, "tick_rate": 0.02, "attack_speed": 2.9}  # Level 10 - Evolution Ready
	]
}

# ==============================================================
# 4.5 WEAPON EVOLUTION SYSTEM
# ==============================================================
var weapon_evolutions: Dictionary = {
	"pistol": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"dual": {
				"name": "Dual Pistols",
				"desc": "Fires from two guns. +1 projectile, +1 pierce",
				"icon": "Dual Pistols"
			},
			"magnum": {
				"name": "Magnum Revolver",
				"desc": "Massive damage, slower fire. +150% damage, -30% speed, knockback",
				"icon": "Magnum Revolver"
			}
		}
	},
	"shotgun": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"gatling": {
				"name": "Gatling Shotgun",
				"desc": "Continuous fire. +50% attack speed, tighter spread",
				"icon": "Gatling Shotgun"
			},
			"explosive": {
				"name": "Explosive Shells",
				"desc": "Pellets explode on impact (30px AOE). -2 pellets",
				"icon": "Explosive Shells"
			}
		}
	},
	"grenade": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"cluster": {
				"name": "Cluster Bomb",
				"desc": "Splits into 3 mini-grenades. 40% damage each",
				"icon": "Cluster Bomb"
			},
			"sticky": {
				"name": "Sticky Mines",
				"desc": "Sticks to ground, explodes when enemy near. +100% damage",
				"icon": "Sticky Mines"
			}
		}
	},
	"aura": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"toxic": {
				"name": "Toxic Field",
				"desc": "Applies poison DOT + 30% slow",
				"icon": "Toxic Field"
			},
			"nuclear": {
				"name": "Nuclear Pulse",
				"desc": "Pulses every 3s. 200% damage, +100px radius",
				"icon": "Nuclear Pulse"
			}
		}
	},
	"sword": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"bladestorm": {
				"name": "Blade Storm",
				"desc": "Swings release 2 energy projectiles. 70% sword damage",
				"icon": "Blade Storm"
			},
			"berserker": {
				"name": "Berserker Blade",
				"desc": "+100% swing speed. Every 5th hit deals +200% damage",
				"icon": "Berserker Blade"
			}
		}
	},
	"lightning_spell": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"chainstorm": {
				"name": "Chain Storm",
				"desc": "Infinite chains. Can re-hit enemies. -20% damage per chain",
				"icon": "Chain Storm"
			},
			"thunderstrike": {
				"name": "Thunder Strike",
				"desc": "No chain. +300% damage. 30% stun chance",
				"icon": "Thunder Strike"
			}
		}
	},
	"laser_beam": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"orbital": {
				"name": "Orbital Lasers",
				"desc": "Main laser + 2 rotating lasers. 50% damage each",
				"icon": "Orbital Lasers"
			},
			"deathray": {
				"name": "Death Ray",
				"desc": "No tracking. +200% damage, +100% width, burn DOT",
				"icon": "Death Ray"
			}
		}
	},
	"summon_spaceships": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"carrier": {
				"name": "Carrier Fleet",
				"desc": "Ships spawn mini-drones on death. +2 base ships",
				"icon": "Carrier Fleet"
			},
			"kamikaze": {
				"name": "Kamikaze Squadron",
				"desc": "Instant dash. +100% damage, +50% speed, AOE explosion",
				"icon": "Kamikaze Squadron"
			}
		}
	},
	"acid_pool": {
		"level": 0,
		"evolved": false,
		"evolution_type": "",
		"paths": {
			"nova": {
				"name": "Corrosive Nova",
				"desc": "Pools explode after 1s. 100% damage AOE (120px)",
				"icon": "Corrosive Nova"
			},
			"lingering": {
				"name": "Lingering Death",
				"desc": "+200% duration. 40% slow. Leaves residue",
				"icon": "Lingering Death"
			}
		}
	}
}

# Evolution tracking functions
func get_weapon_level(weapon_key: String) -> int:
	if not weapon_data.has(weapon_key):
		return 0
	return weapon_data[weapon_key].get("level", 0)

func increment_weapon_level(weapon_key: String):
	if weapon_data.has(weapon_key):
		weapon_data[weapon_key]["level"] = weapon_data[weapon_key].get("level", 0) + 1
		weapon_evolutions[weapon_key]["level"] = weapon_data[weapon_key]["level"]
		print("Weapon %s upgraded to level %d" % [weapon_key, weapon_data[weapon_key]["level"]])

# ==============================================================
# 5. NODES
# ==============================================================
@onready var hurt_box = $HurtBox
@onready var pickup_radius = $PickupRadius
@onready var sprite = $HappyBoo  # Fixed: Actual sprite node name in player.tscn

# ==============================================================
# 6. _READY
# ==============================================================
func _ready():
	# Add player to group so chests can find it
	add_to_group("player")
	add_to_group("player_group")  # Also add to player_group for shard/powerup detection

	player_stats.current_health = player_stats.max_health
	apply_starting_bonuses()
	# NOTE: Character bonuses and starting weapon are now applied in set_character()
	# This is called by main_game.gd AFTER _ready() to ensure proper timing
	run_stats.start_time = Time.get_ticks_msec() / 1000.0

	if pickup_radius:
		var collision_shape = pickup_radius.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			collision_shape.shape.radius = player_stats.pickup_radius

func apply_character_bonuses():
	# Swordmaiden: melee specialist with tankier stats
	if player_stats.character_type == "swordmaiden":
		player_stats.max_health += 50  # 150 HP total
		player_stats.current_health = player_stats.max_health
		player_stats.armor += 5  # More armor
		player_stats.health_regen += 0.3  # Better regen
		player_stats.pickup_radius += 50  # Larger pickup radius
		print("🗡️ Swordmaiden bonus: +50 HP, +5 Armor, +0.3 Regen")

	# Alien Monk: balanced spellcaster with improved crit
	elif player_stats.character_type == "alien_monk":
		player_stats.max_health += 25  # 125 HP total (between Ranger and Swordmaiden)
		player_stats.current_health = player_stats.max_health
		player_stats.crit_chance += 0.05  # 10% base crit chance (doubled from 5%)
		player_stats.crit_damage += 0.25  # 1.75x crit damage (up from 1.5x)
		player_stats.attack_speed_mult *= 1.10  # 10% faster attack speed
		print("⚡ Alien Monk bonus: +25 HP, +5% Crit Chance, +0.25x Crit Damage, +10% Attack Speed")

func apply_curse_effects():
	# Get reference to main game to access curse multipliers
	var main_game = get_parent()
	if not main_game or not main_game.has_method("get_curse_multiplier"):
		return

	# Get curse multipliers
	var hp_mult = main_game.get_curse_multiplier("hp_mult")
	var armor_mult = main_game.get_curse_multiplier("armor_mult")
	var damage_mult = main_game.get_curse_multiplier("damage_mult")

	# Apply HP penalty (multiplicative)
	if hp_mult < 1.0:
		var old_max_health = player_stats.max_health
		player_stats.max_health = int(player_stats.max_health * hp_mult)
		# Adjust current health proportionally
		player_stats.current_health = min(player_stats.current_health, player_stats.max_health)
		print("🔥 Curse of Frailty: Max HP %d → %d" % [old_max_health, player_stats.max_health])

	# Apply armor penalty (multiplicative)
	if armor_mult < 1.0:
		var old_armor = player_stats.armor
		player_stats.armor = int(player_stats.armor * armor_mult)
		print("🔥 Curse of Fragility: Armor %d → %d" % [old_armor, player_stats.armor])

	# Apply damage penalty (multiplicative)
	if damage_mult < 1.0:
		player_stats.damage_mult *= damage_mult
		print("🔥 Curse of Weakness: Damage multiplier reduced by %.0f%%" % ((1.0 - damage_mult) * 100))

func apply_starting_bonuses():
	if not has_node("/root/SaveManager"):
		return

	var save_manager = get_node("/root/SaveManager")
	var bonuses = save_manager.get_starting_bonuses()

	if bonuses.damage_bonus > 0:
		player_stats.damage_mult *= (1.0 + bonuses.damage_bonus)
		print("Starting bonus: +%.0f%% Damage" % (bonuses.damage_bonus * 100))

	if bonuses.health_bonus > 0:
		player_stats.max_health += bonuses.health_bonus
		player_stats.current_health = player_stats.max_health
		print("Starting bonus: +%d Max HP" % bonuses.health_bonus)

	if bonuses.speed_bonus > 0:
		player_stats.speed *= (1.0 + bonuses.speed_bonus)
		print("Starting bonus: +%.0f%% Speed" % (bonuses.speed_bonus * 100))

	if bonuses.luck_bonus > 0:
		player_stats.luck += bonuses.luck_bonus
		print("Starting bonus: +%d Luck" % bonuses.luck_bonus)

	if bonuses.extra_weapon_slot > 0:
		player_stats.max_weapon_slots += bonuses.extra_weapon_slot
		print("Starting bonus: +%d Weapon Slot" % bonuses.extra_weapon_slot)

	# NEW: Meta-progression stat bonuses
	if bonuses.attack_speed_mult > 0:
		player_stats.attack_speed_mult *= (1.0 + bonuses.attack_speed_mult)
		print("Starting bonus: +%.0f%% Attack Speed" % (bonuses.attack_speed_mult * 100))

	if bonuses.armor > 0:
		player_stats.armor += bonuses.armor
		print("Starting bonus: +%d Armor" % bonuses.armor)

	if bonuses.crit_chance > 0:
		player_stats.crit_chance += bonuses.crit_chance
		print("Starting bonus: +%.0f%% Crit Chance" % (bonuses.crit_chance * 100))

	if bonuses.crit_damage_mult > 0:
		player_stats.crit_damage *= (1.0 + bonuses.crit_damage_mult)
		print("Starting bonus: +%.0f%% Crit Damage" % (bonuses.crit_damage_mult * 100))

	if bonuses.aoe_mult > 0:
		player_stats.aoe_mult *= (1.0 + bonuses.aoe_mult)
		print("Starting bonus: +%.0f%% AOE Size" % (bonuses.aoe_mult * 100))

	# Initialize revives from bonuses
	revives_remaining = bonuses.revives
	if revives_remaining > 0:
		print("Starting bonus: %d Revive(s)" % revives_remaining)

# ==============================================================
# 7. PHYSICS + INPUT
# ==============================================================
func _physics_process(delta):
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * player_stats.speed
	move_and_slide()

	# MAP BOUNDARIES
	var main_game = get_parent()
	if main_game and main_game.has_method("get"):
		var map_width = main_game.get("MAP_WIDTH")
		var map_height = main_game.get("MAP_HEIGHT")
		if map_width and map_height:
			global_position.x = clamp(global_position.x, 0, map_width)
			global_position.y = clamp(global_position.y, 0, map_height)

	player_stats.current_health = min(
		player_stats.current_health + player_stats.health_regen * delta,
		player_stats.max_health
	)

	# Update revive invincibility timer
	if revive_invincibility_timer > 0:
		revive_invincibility_timer -= delta

	const DAMAGE_RATE = 20.0  # Increased from 6.0 - mobs now hit MUCH harder
	var overlapping_mobs = hurt_box.get_overlapping_bodies()
	if overlapping_mobs.size() > 0:
		# NEW: Calculate average damage multiplier from touching mobs
		var total_dmg_mult = 0.0
		for mob in overlapping_mobs:
			if mob.has_method("get"):
				total_dmg_mult += mob.get("damage_multiplier") if "damage_multiplier" in mob else 1.0
			else:
				total_dmg_mult += 1.0
		var avg_dmg_mult = total_dmg_mult / overlapping_mobs.size()

		# Apply revive invincibility
		var effective_armor = player_stats.armor
		if revive_invincibility_timer > 0:
			effective_armor += 1000  # Effectively invincible during revive

		var dmg = DAMAGE_RATE * overlapping_mobs.size() * delta * avg_dmg_mult
		dmg = max(0.0, dmg - effective_armor * delta)  # Allow 0 damage when armor negates everything
		player_stats.current_health -= dmg

		# Check for death or revive
		if player_stats.current_health <= 0:
			# Try to revive if available
			if revives_remaining > 0:
				trigger_revive()
			else:
				health_depleted.emit()

	for area in pickup_radius.get_overlapping_areas():
		if area.is_in_group("xp_vial") and area.has_method("start_pull"):
			area.start_pull(self)
		elif area.is_in_group("healthpack"):
			# Only pick up health pack if not at full health
			if player_stats.current_health < player_stats.max_health:
				pickup_healthpack()
				area.queue_free()
		elif area.is_in_group("powerup"):
			pickup_powerup(area)
			area.queue_free()
		elif area.is_in_group("currency"):
			# Collect shards directly (they handle their own collection)
			if area.has_method("collect"):
				area.collect(self)

# ==============================================================
# 7.5 REVIVE SYSTEM
# ==============================================================
func trigger_revive():
	# Restore health to 50%
	player_stats.current_health = player_stats.max_health * 0.5

	# Apply invincibility for 5 seconds
	revive_invincibility_timer = 5.0

	# Decrement revives
	revives_remaining -= 1

	# Show floating text "REVIVED!"
	show_powerup_text("REVIVED!", Color(1, 1, 0, 1))

	# Visual feedback - flash white effect
	create_revive_flash()

	print("⭐ REVIVED! Health restored to 50%%, invincible for 5s. Revives left: %d" % revives_remaining)

func create_revive_flash():
	# Create white flash effect on sprite
	if sprite:
		var original_modulate = sprite.modulate
		sprite.modulate = Color(2, 2, 2, 1)  # Bright white flash

		# Fade back to normal over 0.5 seconds
		var tween = create_tween()
		tween.tween_property(sprite, "modulate", original_modulate, 0.5)

		# Add pulsing glow during invincibility
		var glow_tween = create_tween()
		glow_tween.set_loops(10)  # Pulse 10 times over 5 seconds
		glow_tween.tween_property(sprite, "modulate", Color(1.5, 1.5, 1.5, 1), 0.25)
		glow_tween.tween_property(sprite, "modulate", original_modulate, 0.25)

# ==============================================================
# 8. XP + LEVEL UP
# ==============================================================
func pickup_xp(amount: int) -> void:
	var luck_mult = 1.0 + (player_stats.luck * 0.10)

	# Apply curse XP bonus
	var curse_xp_mult = 1.0
	var main_game = get_parent()
	if main_game and main_game.has_method("get_curse_multiplier"):
		curse_xp_mult = main_game.get_curse_multiplier("xp_mult")

	var final_amount = int(amount * luck_mult * curse_xp_mult)
	player_stats.current_xp += final_amount
	run_stats.total_xp_gained += final_amount
	
	while player_stats.current_xp >= player_stats.xp_to_next_level:
		player_stats.current_xp -= player_stats.xp_to_next_level
		player_stats.level += 1
		player_stats.xp_to_next_level = int(50 + pow(player_stats.level, 1.5) * 12)
		
		if get_parent().has_method("show_level_up_options"):
			get_parent().show_level_up_options()
	
	if has_node("UI/XPBar"):
		$UI/XPBar.value = player_stats.current_xp
		$UI/XPBar.max_value = player_stats.xp_to_next_level

# ==============================================================
# 9. WEAPON MANAGEMENT
# ==============================================================
func add_weapon(weapon_key: String) -> void:
	if player_stats.current_weapons.has(weapon_key):
		print("Already have weapon: ", weapon_key)
		return
	
	if player_stats.current_weapons.size() >= player_stats.max_weapon_slots:
		print("Max weapon slots reached!")
		return
	
	if not weapon_data.has(weapon_key):
		print("ERROR: Unknown weapon: ", weapon_key)
		return
	
	var data = weapon_data[weapon_key]
	
	if data.level == 0:
		data.level = 1
	
	# Handle sword weapon (melee)
	if weapon_key == "sword":
		# Create inline sword weapon if scene doesn't exist
		if data.scene == null or not ResourceLoader.exists("res://Sword.tscn"):
			create_sword_weapon(data)
			player_stats.current_weapons.append(weapon_key)
			return
	
	var new_weapon = data.scene.instantiate()
	
	if new_weapon.has_method("set_stats"):
		new_weapon.set_stats(data)
	
	if new_weapon.has_method("set_player_ref"):
		new_weapon.set_player_ref(self)
	
	add_child(new_weapon)
	new_weapon.position = Vector2.ZERO
	player_stats.current_weapons.append(weapon_key)
	
	print("Added weapon: ", weapon_key, " | Total weapons: ", player_stats.current_weapons.size())

func create_sword_weapon(data: Dictionary):
	# Create simple melee sword system
	var sword_timer = Timer.new()
	sword_timer.name = "SwordTimer"
	# Apply attack_speed_mult to sword timer
	sword_timer.wait_time = 1.0 / (data.attack_speed * player_stats.attack_speed_mult)
	sword_timer.timeout.connect(_on_sword_attack)
	sword_timer.autostart = true
	add_child(sword_timer)
	print("🗡️ Created Energy Sword weapon!")

func _on_sword_attack():
	# Get sword data
	if not weapon_data.has("sword"):
		return

	var data = weapon_data["sword"]

	# BERSERKER BLADE: Track hits and apply bonus damage on 5th hit
	var is_berserker_hit = false
	if data.get("berserker", false):
		data["berserker_counter"] = data.get("berserker_counter", 0) + 1
		if data["berserker_counter"] >= 5:
			is_berserker_hit = true
			data["berserker_counter"] = 0
			print("💥 BERSERKER STRIKE! (+200% damage)")

	# Apply multipliers to sword stats
	var sword_range = data.distance * player_stats.attack_range_mult
	var sword_damage = data.damage * player_stats.damage_mult
	var sword_aoe = data.aoe * player_stats.aoe_mult

	# BERSERKER BLADE: Apply +200% damage on 5th hit
	if is_berserker_hit:
		sword_damage *= 3.0  # 100% base + 200% bonus = 300% total

	# Number of simultaneous swings = 1 + projectiles
	# 0 projectiles = 1 swing, 1 projectile = 2 swings, etc.
	var num_swings = 1 + data.projectiles
	
	# Max targets per swing (each swing can hit multiple enemies)
	var max_targets_per_swing = 3

	# Create multiple swings in different directions
	for swing_index in range(num_swings):
		# Calculate angle for this swing
		var base_angle = 0.0
		
		# Get direction to nearest enemy for primary swing
		var enemies = get_tree().get_nodes_in_group("mob")
		var nearest = null
		var nearest_dist = INF

		for enemy in enemies:
			if is_instance_valid(enemy):
				var dist = global_position.distance_to(enemy.global_position)
				if dist < nearest_dist:
					nearest_dist = dist
					nearest = enemy

		# Set base angle based on nearest enemy or movement
		if nearest:
			base_angle = global_position.angle_to_point(nearest.global_position)
		else:
			# Face the direction of movement, or default to right
			if velocity.length() > 0:
				base_angle = velocity.angle()
			else:
				base_angle = 0
		
		# Spread swings around in different directions
		if num_swings > 1:
			# First swing faces target, others spread out
			if swing_index > 0:
				# Spread evenly around 360 degrees
				var angle_offset = (TAU / num_swings) * swing_index
				base_angle += angle_offset
	
		# Find enemies in melee range for this swing
		var hit_enemies = []

		# Get all targetable enemies
		var mobs = get_tree().get_nodes_in_group("mob")
		var asteroids = get_tree().get_nodes_in_group("asteroid")
		var flowers = get_tree().get_nodes_in_group("flower")
		var all_targets = mobs + asteroids + flowers

		for enemy in all_targets:
			if not is_instance_valid(enemy):
				continue

			var dist = global_position.distance_to(enemy.global_position)
			if dist <= sword_range:
				# Check if enemy is within the swing arc
				var angle_to_enemy = global_position.angle_to_point(enemy.global_position)
				var angle_diff = abs(angle_to_enemy - base_angle)
				# Normalize angle difference to -PI to PI
				while angle_diff > PI:
					angle_diff -= TAU
				while angle_diff < -PI:
					angle_diff += TAU
				angle_diff = abs(angle_diff)
				
				# Only hit if within the swing arc (90 degrees = PI/2)
				if angle_diff <= PI/2:
					hit_enemies.append(enemy)

		# Hit closest enemies (based on max_targets_per_swing)
		hit_enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))

		var hits = 0
		for enemy in hit_enemies:
			if hits >= max_targets_per_swing:
				break

			if enemy.has_method("take_damage"):
				var crit = randf() < player_stats.crit_chance
				var final_dmg = sword_damage
				if crit:
					final_dmg *= player_stats.crit_damage

				# Apply poison if enabled on weapon
				var is_poisoned = data.poison and randf() < 0.3  # 30% chance if poison enabled
				
				# Take damage with poison flag
				if is_poisoned:
					# Apply poison DOT - 30% of weapon damage per second for 5 seconds
					if enemy.has_method("start_dot"):
						enemy.start_dot("sword_poison", sword_damage * 0.3, 5, Color(0, 0.8, 0.2))  # Green poison
						enemy.take_damage(final_dmg, false, crit)  # Don't pass is_poisoned to take_damage, we handle it with DOT
				else:
					enemy.take_damage(final_dmg, false, crit)
				
				report_weapon_damage("sword", final_dmg)

				# Apply knockback
				if enemy.has_method("apply_knockback"):
					enemy.apply_knockback(data.knockback, global_position)

				hits += 1

		# Create visual slash effect for this swing
		# ONLY show visuals if enemies were actually hit
		if hits > 0:
			create_slash_effect_at_angle(base_angle, sword_range, sword_aoe, data.poison, is_berserker_hit)

		# BLADE STORM: Spawn 2 energy projectiles per swing
		if data.get("blade_storm", false):
			spawn_blade_storm_projectiles(base_angle, sword_damage * 0.7)

func create_slash_effect_at_angle(angle: float, sword_range: float, sword_aoe: float, is_poison: bool, is_berserker: bool = false):
	# Create energy slash visual at specific angle
	var slash = Node2D.new()
	slash.global_position = global_position
	slash.rotation = angle
	get_parent().add_child(slash)

	# Choose color based on poison or berserker
	var slash_color: Color
	var outline_color: Color

	if is_berserker:
		# Red/orange berserker energy (more intense!)
		slash_color = Color(1.0, 0.3, 0.0, 0.9)  # Bright red-orange
		outline_color = Color(1.0, 0.5, 0.0, 1.0)  # Bright orange outline
		sword_range *= 1.2  # Slightly larger visual for berserker
	elif is_poison:
		# Green poison energy
		slash_color = Color(0.2, 1, 0.3, 0.7)  # Bright green
		outline_color = Color(0.4, 1, 0.5, 0.9)  # Brighter green outline
	else:
		# Pink energy (default)
		slash_color = Color(1, 0.4, 0.8, 0.7)  # Bright pink
		outline_color = Color(1, 0.6, 0.9, 0.9)  # Brighter pink outline

	# Create visual slash arc using Polygon2D
	var slash_visual = Polygon2D.new()
	slash_visual.color = slash_color

	# Create arc shape representing sword slash range
	# Arc width is based on sword_aoe
	var arc_points = PackedVector2Array()
	var num_points = 20
	var arc_width = (sword_aoe / 80.0) * (PI/4)  # Scale arc width based on AOE
	var start_angle = -arc_width
	var end_angle = arc_width

	# Add center point
	arc_points.append(Vector2.ZERO)

	# Add arc points at sword range
	for i in range(num_points + 1):
		var t = float(i) / num_points
		var arc_angle = start_angle + (end_angle - start_angle) * t
		var point = Vector2(cos(arc_angle), sin(arc_angle)) * sword_range
		arc_points.append(point)

	# Close the arc back to center
	arc_points.append(Vector2.ZERO)

	slash_visual.polygon = arc_points
	slash.add_child(slash_visual)

	# Add outline for better visibility
	var outline = Line2D.new()
	outline.default_color = outline_color
	outline.width = 3
	for point in arc_points:
		outline.add_point(point)
	slash.add_child(outline)

	# Add poison particle effect if poison
	if is_poison:
		var poison_particles = Node2D.new()
		for i in range(5):
			var particle = ColorRect.new()
			particle.size = Vector2(4, 4)
			particle.color = Color(0, 1, 0.3, 0.8)
			particle.position = Vector2(randf_range(0, sword_range), 0).rotated(randf_range(start_angle, end_angle))
			poison_particles.add_child(particle)
			
			# Animate poison particles
			var particle_tween = create_tween()
			particle_tween.tween_property(particle, "position", particle.position * 1.5, 0.3)
			particle_tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.3)
		
		slash.add_child(poison_particles)

	# Fade out
	var tween = create_tween()
	tween.tween_property(slash_visual, "color:a", 0.0, 0.25)
	tween.parallel().tween_property(outline, "default_color:a", 0.0, 0.25)
	tween.tween_callback(slash.queue_free)

func spawn_blade_storm_projectiles(base_angle: float, projectile_damage: float):
	# BLADE STORM: Spawn 2 energy projectiles per swing
	const BULLET_SCENE = preload("res://bullet.tscn")

	# Spawn 2 projectiles with slight spread
	for i in range(2):
		var bullet = BULLET_SCENE.instantiate()
		bullet.global_position = global_position

		# Spread projectiles ±15° from sword angle
		var angle_offset = deg_to_rad(-15 + (i * 30))  # -15° and +15°
		var direction = Vector2.RIGHT.rotated(base_angle + angle_offset)

		bullet.rotation = direction.angle()
		bullet.damage = projectile_damage
		bullet.speed = 500  # Fast energy projectiles
		bullet.pierce = 2  # Can hit 2 enemies
		bullet.max_distance = 400  # Medium range
		bullet.player = self

		# Visual: Make them pink/cyan energy color
		if bullet.has_node("Sprite2D"):
			bullet.get_node("Sprite2D").modulate = Color(1.0, 0.5, 0.9, 1.0) if i == 0 else Color(0.5, 0.9, 1.0, 1.0)

		get_parent().add_child(bullet)

# ==============================================================
# 10. DAMAGE REPORTING + LIFESTEAL
# ==============================================================
func report_weapon_damage(weapon_key: String, amount: float) -> void:
	if not weapon_damage_dealt.has(weapon_key):
		weapon_damage_dealt[weapon_key] = 0
	weapon_damage_dealt[weapon_key] += amount
	run_stats.total_damage_dealt += int(amount)
	
	if player_stats.lifesteal > 0:
		var heal = amount * player_stats.lifesteal
		player_stats.current_health = min(
			player_stats.current_health + heal,
			player_stats.max_health
		)

# ==============================================================
# 11. UPGRADE: PLAYER STATS
# ==============================================================
func upgrade_player_stat(stat_key: String, value: float) -> void:
	if not player_stats.has(stat_key):
		print("ERROR: Unknown stat: ", stat_key)
		return
	
	var old_value = player_stats[stat_key]
	
	match stat_key:
		"max_health":
			player_stats.max_health += value
			player_stats.current_health += value
		"health_regen", "lifesteal", "crit_chance", "projectiles", "max_weapon_slots", "armor", "luck":
			player_stats[stat_key] += value
		"pickup_radius":
			player_stats.pickup_radius += value
			if pickup_radius:
				var collision_shape = pickup_radius.get_node("CollisionShape2D")
				if collision_shape and collision_shape.shape:
					collision_shape.shape.radius = player_stats.pickup_radius
		"speed", "attack_speed_mult", "damage_mult", "aoe_mult", "crit_damage":
			player_stats[stat_key] *= (1.0 + value)
	
	print("Upgraded stat '%s': %.2f → %.2f" % [stat_key, old_value, player_stats[stat_key]])
	_update_all_weapons()

# ==============================================================
# 12. UPGRADE: WEAPONS
# ==============================================================
func upgrade_weapon(weapon_key: String, upgrade_key: String, value) -> void:
	if not weapon_data.has(weapon_key):
		print("ERROR: Unknown weapon: ", weapon_key)
		return

	var data = weapon_data[weapon_key]

	if data.has(upgrade_key):
		var old_value = data[upgrade_key]

		match upgrade_key:
			"damage", "projectiles", "pierce", "knockback", "aoe", "distance", "chain_targets", "chain_range":
				data[upgrade_key] += value
			"attack_speed", "spread":
				data[upgrade_key] *= (1.0 + value)
			"poison", "burn":
				data[upgrade_key] = true

		# Increment weapon level for tracking upgrades and evolution
		increment_weapon_level(weapon_key)

		print("Upgraded weapon '%s' %s: %s → %s (Level %d)" % [weapon_key, upgrade_key, str(old_value), str(data[upgrade_key]), data["level"]])
	else:
		print("ERROR: Weapon '%s' doesn't have stat '%s'" % [weapon_key, upgrade_key])
	
	# Update sword timer if upgrading sword attack speed
	if weapon_key == "sword" and upgrade_key == "attack_speed":
		var sword_timer = get_node_or_null("SwordTimer")
		if sword_timer:
			# FIXED: Apply attack_speed_mult to sword timer
			sword_timer.wait_time = 1.0 / (data.attack_speed * player_stats.attack_speed_mult)

	_update_weapon_instance(weapon_key, data)

func _update_all_weapons() -> void:
	for weapon_key in player_stats.current_weapons:
		if weapon_data.has(weapon_key):
			_update_weapon_instance(weapon_key, weapon_data[weapon_key])

func _update_weapon_instance(weapon_key: String, data: Dictionary) -> void:
	# Special handling for sword (timer-based weapon)
	if weapon_key == "sword":
		var sword_timer = get_node_or_null("SwordTimer")
		if sword_timer:
			# Update timer with current attack speed and multiplier
			sword_timer.wait_time = 1.0 / (data.attack_speed * player_stats.attack_speed_mult)
			print("Updated sword timer: ", sword_timer.wait_time)
		return

	# Handle other weapons with set_stats method
	for child in get_children():
		if child.has_method("set_stats") and child.get("stats"):
			var weapon_stats = child.get("stats")
			if weapon_stats and weapon_stats.get("name") == data.name:
				child.set_stats(data)
				print("Updated live weapon: ", weapon_key)

# ==============================================================
# 13. WEAPON EVOLUTION
# ==============================================================
func evolve_weapon(weapon_key: String, evolution_id: String):
	print("EVOLVING %s → %s" % [weapon_key, evolution_id])

	# Mark as evolved
	weapon_evolutions[weapon_key]["evolved"] = true
	weapon_evolutions[weapon_key]["evolution_type"] = evolution_id

	# Get evolution data
	var evo_data = weapon_evolutions[weapon_key]["paths"][evolution_id]

	# Update weapon name
	weapon_data[weapon_key]["name"] = evo_data["name"]

	# Apply evolution-specific bonuses
	match weapon_key:
		"pistol":
			if evolution_id == "dual":
				weapon_data["pistol"]["projectiles"] += 1
				weapon_data["pistol"]["pierce"] += 1
				weapon_data["pistol"]["dual_pistols"] = true
			elif evolution_id == "magnum":
				weapon_data["pistol"]["damage"] *= 2.5
				weapon_data["pistol"]["attack_speed"] *= 0.7
				weapon_data["pistol"]["knockback"] = 50
				weapon_data["pistol"]["magnum"] = true

		"shotgun":
			if evolution_id == "gatling":
				weapon_data["shotgun"]["attack_speed"] *= 1.5
				weapon_data["shotgun"]["spread"] *= 0.7
				weapon_data["shotgun"]["gatling"] = true
			elif evolution_id == "explosive":
				weapon_data["shotgun"]["projectiles"] -= 2
				weapon_data["shotgun"]["explosive_shells"] = true

		"grenade":
			if evolution_id == "cluster":
				weapon_data["grenade"]["cluster_bomb"] = true
			elif evolution_id == "sticky":
				weapon_data["grenade"]["damage"] *= 2.0
				weapon_data["grenade"]["sticky_mines"] = true

		"aura":
			if evolution_id == "toxic":
				weapon_data["aura"]["toxic_field"] = true
			elif evolution_id == "nuclear":
				weapon_data["aura"]["nuclear_pulse"] = true

		"sword":
			if evolution_id == "bladestorm":
				weapon_data["sword"]["blade_storm"] = true
			elif evolution_id == "berserker":
				weapon_data["sword"]["attack_speed"] *= 2.0
				weapon_data["sword"]["berserker"] = true
				weapon_data["sword"]["berserker_counter"] = 0

		"lightning_spell":
			if evolution_id == "chainstorm":
				weapon_data["lightning_spell"]["chain_storm"] = true
			elif evolution_id == "thunderstrike":
				weapon_data["lightning_spell"]["damage"] *= 4.0
				weapon_data["lightning_spell"]["chain_targets"] = 0
				weapon_data["lightning_spell"]["thunder_strike"] = true

		"laser_beam":
			if evolution_id == "orbital":
				weapon_data["laser_beam"]["orbital_lasers"] = true
			elif evolution_id == "deathray":
				weapon_data["laser_beam"]["damage"] *= 3.0
				weapon_data["laser_beam"]["laser_width"] *= 2.0
				weapon_data["laser_beam"]["death_ray"] = true
				weapon_data["laser_beam"]["cone_mode"] = false  # Disable tracking

		"summon_spaceships":
			if evolution_id == "carrier":
				weapon_data["summon_spaceships"]["projectiles"] += 2
				weapon_data["summon_spaceships"]["carrier_fleet"] = true
			elif evolution_id == "kamikaze":
				weapon_data["summon_spaceships"]["damage"] *= 2.0
				weapon_data["summon_spaceships"]["speed_mult"] *= 1.5
				weapon_data["summon_spaceships"]["kamikaze"] = true

		"acid_pool":
			if evolution_id == "nova":
				weapon_data["acid_pool"]["corrosive_nova"] = true
			elif evolution_id == "lingering":
				weapon_data["acid_pool"]["duration"] *= 3.0
				weapon_data["acid_pool"]["lingering_death"] = true

	# Refresh weapon instance
	_update_weapon_instance(weapon_key, weapon_data[weapon_key])

	# Show notification
	show_powerup_text("EVOLVED: " + evo_data["name"], Color(1.0, 0.5, 0.0, 1))

# ==============================================================
# 14. STATS UI (optional) + GAME OVER STATS
# ==============================================================
func get_active_weapons_data() -> Dictionary:
	var active = {}
	for key in player_stats.current_weapons:
		if weapon_data.has(key):
			active[key] = weapon_data[key]
	return active

func get_all_stats() -> Array:
	return [player_stats, get_active_weapons_data()]

func get_run_stats() -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	var time_survived = current_time - run_stats.start_time
	
	var weapon_names = []
	for key in player_stats.current_weapons:
		if weapon_data.has(key):
			weapon_names.append(weapon_data[key].name)
	
	return {
		"time_survived": time_survived,
		"level": player_stats.level,
		"total_xp": run_stats.total_xp_gained,
		"kills": run_stats.kills,
		"damage_dealt": run_stats.total_damage_dealt,
		"shards_collected": run_stats.shards_collected,
		"max_health": player_stats.max_health,
		"damage_mult": player_stats.damage_mult,
		"attack_speed_mult": player_stats.attack_speed_mult,
		"speed": player_stats.speed,
		"crit_chance": player_stats.crit_chance,
		"luck": player_stats.luck,
		"weapons": weapon_names
	}

func register_kill():
	run_stats.kills += 1

func collect_currency(amount: int):
	var multiplier = 1.0
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		var bonuses = save_manager.get_starting_bonuses()
		multiplier = bonuses.currency_multiplier
	
	var final_amount = int(amount * multiplier)
	run_stats.shards_collected += final_amount

# ==============================================================
# 14. PICKUP SIGNAL HANDLER (redundant with _physics_process but good to have)
# ==============================================================
func _on_pickup_radius_area_entered(area: Area2D):
	# This provides instant pickup on first contact
	if area.is_in_group("healthpack"):
		# Only pick up health pack if not at full health
		if player_stats.current_health < player_stats.max_health:
			pickup_healthpack()
			area.queue_free()
	elif area.is_in_group("powerup"):
		pickup_powerup(area)
		area.queue_free()
	elif area.is_in_group("currency") and area.has_method("collect"):
		area.collect(self)

# ==============================================================
# 15. POWERUPS FROM ASTEROIDS
# ==============================================================
func pickup_healthpack():
	player_stats.current_health = min(
		player_stats.current_health + 25,
		player_stats.max_health
	)
	print("❤️ Picked up health pack! +25 HP")

func pickup_powerup(powerup: Area2D):
	# Read powerup_type property directly (not metadata)
	var powerup_type = powerup.powerup_type if "powerup_type" in powerup else "unknown"

	print("✨ Picked up powerup: ", powerup_type)
	
	match powerup_type:
		"invincible":
			activate_invincibility()
		"magnet":
			activate_magnet()
		"attack_speed":
			activate_triple_attack_speed()
		"nuke":
			activate_nuke()
		_:
			print("⚠️ Unknown powerup type: ", powerup_type)

func activate_invincibility():
	const DURATION = 10.0

	# Generate unique ID for this activation
	powerup_id_counter += 1
	var this_id = powerup_id_counter

	# Check if invincibility is already active
	if active_powerups.has("invincible"):
		print("⭐ INVINCIBLE refreshed!")
		show_powerup_text("INVINCIBLE REFRESHED!", Color(1, 1, 0, 1))
		# Update to new ID (old timer will complete but won't remove effect)
		active_powerups["invincible"] = this_id
	else:
		print("⭐ INVINCIBLE for 10 seconds!")
		show_powerup_text("INVINCIBLE!", Color(1, 1, 0, 1))
		# Apply effect for first time
		player_stats.armor += 1000
		active_powerups["invincible"] = this_id

	create_powerup_display("invincible", DURATION)

	# Wait for duration
	await get_tree().create_timer(DURATION).timeout

	# Only remove effect if this is still the active ID (not refreshed)
	if active_powerups.get("invincible") == this_id:
		player_stats.armor = max(0, player_stats.armor - 1000)
		active_powerups.erase("invincible")

func activate_magnet():
	print("🧲 MAGNET activated!")
	show_powerup_text("MAGNET!", Color(0, 1, 1, 1))

	# Pull all XP vials to player
	var vials = get_tree().get_nodes_in_group("xp_vial")
	for vial in vials:
		if is_instance_valid(vial) and vial.has_method("start_pull"):
			vial.start_pull(self)

	# Pull all Nebula Shards to player
	var shards = get_tree().get_nodes_in_group("currency")
	for shard in shards:
		if is_instance_valid(shard) and shard.has_method("start_pull"):
			shard.start_pull(self)

	# Pull all powerups to player (but NOT health - it despawns on its own)
	var powerups = get_tree().get_nodes_in_group("powerup")
	for powerup in powerups:
		if is_instance_valid(powerup) and powerup.has_method("start_pull"):
			powerup.start_pull(self)

func activate_triple_attack_speed():
	const DURATION = 10.0

	# Generate unique ID for this activation
	powerup_id_counter += 1
	var this_id = powerup_id_counter

	# Check if attack speed boost is already active
	if active_powerups.has("attack_speed"):
		print("⚡ RAPID FIRE refreshed!")
		show_powerup_text("RAPID FIRE REFRESHED!", Color(1, 0, 1, 1))
		# Update to new ID (old timer will complete but won't remove effect)
		active_powerups["attack_speed"] = this_id
	else:
		print("⚡ TRIPLE ATTACK SPEED for 10 seconds!")
		show_powerup_text("RAPID FIRE!", Color(1, 0, 1, 1))
		# Apply effect for first time
		player_stats.attack_speed_mult *= 3.0
		_update_all_weapons()

		# Update sword timer too
		if has_node("SwordTimer") and weapon_data.has("sword"):
			var sword_timer = get_node("SwordTimer")
			sword_timer.wait_time = 1.0 / (weapon_data["sword"].attack_speed * 3.0)

		active_powerups["attack_speed"] = this_id

	create_powerup_display("attack_speed", DURATION)

	# Wait for duration
	await get_tree().create_timer(DURATION).timeout

	# Only remove effect if this is still the active ID (not refreshed)
	if active_powerups.get("attack_speed") == this_id:
		player_stats.attack_speed_mult /= 3.0
		_update_all_weapons()

		# Reset sword timer
		if has_node("SwordTimer") and weapon_data.has("sword"):
			var sword_timer = get_node("SwordTimer")
			sword_timer.wait_time = 1.0 / weapon_data["sword"].attack_speed

		active_powerups.erase("attack_speed")

func activate_nuke():
	print("💣 NUKE!")
	show_powerup_text("NUKE!", Color(1, 0.5, 0, 1))
	var enemies = get_tree().get_nodes_in_group("mob")
	var killed = 0
	var bosses_skipped = 0
	for enemy in enemies:
		# Exclude ALL boss types: regular bosses, mega bosses, and mini-bosses
		if not is_instance_valid(enemy):
			continue

		# Debug: Check if this is a boss
		var is_boss = enemy.is_in_group("boss")
		var is_mini = enemy.is_in_group("mini_boss")
		var enemy_name = enemy.name if enemy.has_method("get_name") else "Unknown"

		if is_boss or is_mini:
			print("💣 NUKE: Skipping %s (boss=%s, mini=%s)" % [enemy_name, is_boss, is_mini])
			bosses_skipped += 1
			continue

		if enemy.has_method("take_damage"):
			enemy.take_damage(99999)
			killed += 1

	print("💣 Nuke killed %d enemies, skipped %d bosses!" % [killed, bosses_skipped])

# ==============================================================
# 16. CHARACTER SELECTION
# ==============================================================
func set_character(char_type: String):
	player_stats.character_type = char_type

	# Apply character-specific bonuses
	apply_character_bonuses()

	# Apply curse effects (penalties)
	apply_curse_effects()

	# Update sprite if it exists
	if sprite and char_type == "swordmaiden":
		if ResourceLoader.exists("res://female hero.png"):
			sprite.texture = load("res://female hero.png")
			sprite.scale = Vector2(0.35, 0.35)  # Match Ranger's size (~0.33)
			print("✅ Sword Maiden sprite loaded successfully!")
		else:
			print("⚠️ WARNING: 'female hero.png' not found!")
	elif sprite and char_type == "alien_monk":
		if ResourceLoader.exists("res://alien monk.png"):
			sprite.texture = load("res://alien monk.png")
			sprite.scale = Vector2(0.35, 0.35)  # Match other character sizes
			print("✅ Alien Monk sprite loaded successfully!")
		else:
			print("⚠️ WARNING: 'alien monk.png' not found!")
	elif sprite and char_type == "ranger":
		# Keep default player sprite
		print("✅ Using default Ranger sprite")

	# Add starting weapon based on character type
	# This happens AFTER character_type is set, ensuring correct weapon
	if char_type == "ranger":
		add_weapon("pistol")
		print("🔫 Ranger starts with: Pistol")
	elif char_type == "swordmaiden":
		add_weapon("sword")
		print("🗡️ Sword Maiden starts with: Energy Sword")
	elif char_type == "alien_monk":
		add_weapon("lightning_spell")
		print("⚡ Alien Monk starts with: Lightning Spell")

# ==============================================================
# 17. POWERUP UI
# ==============================================================
func show_powerup_text(text: String, color: Color):
	# Show floating text above player
	const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")
	if not FLOATING_DMG_SCENE:
		return

	var dmg = FLOATING_DMG_SCENE.instantiate()
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if ui_layer:
		ui_layer.add_child(dmg)
		# Convert world position to screen position for CanvasLayer
		var viewport = get_viewport()
		if viewport:
			var canvas_transform = viewport.get_canvas_transform()
			var world_pos = global_position - Vector2(0, 60)
			var screen_pos = canvas_transform * world_pos
			dmg.global_position = screen_pos
	else:
		get_parent().add_child(dmg)
		dmg.global_position = global_position - Vector2(0, 60)

	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(text, color)

func create_powerup_display(powerup_type: String, duration: float):
	# Create powerup display in top-right corner
	const POWERUP_DISPLAY_SCENE = preload("res://PowerupDisplay.tscn")
	if not POWERUP_DISPLAY_SCENE:
		return

	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if not ui_layer:
		return

	# Check if a display for this powerup type already exists
	for child in ui_layer.get_children():
		if child.has_method("setup") and child.get("powerup_type") == powerup_type:
			# Found existing display - just refresh its timer
			child.time_remaining = duration
			# Reset flash effect
			child.modulate.a = 1.0
			return

	# No existing display found - create a new one
	var display = POWERUP_DISPLAY_SCENE.instantiate()
	display.setup(powerup_type, duration)

	# Count existing powerups
	var existing_powerups = 0
	for child in ui_layer.get_children():
		if child.has_method("setup"):  # Check if it's a PowerupDisplay
			existing_powerups += 1

	# Position in middle-right area, stacked vertically and centered
	var screen_size = get_viewport().get_visible_rect().size

	# Each powerup needs 70 pixels of vertical space (40px icon + 12px label + 18px padding)
	const POWERUP_SPACING = 70
	var x_position: float = screen_size.x * 0.85  # 85% across screen (middle-right)

	# Add to UILayer first so we can reposition all powerups
	ui_layer.add_child(display)

	# Count total powerups to center them vertically
	var total_powerups = 0
	for child in ui_layer.get_children():
		if child.has_method("setup"):
			total_powerups += 1

	# Calculate starting Y to center all powerups vertically
	var total_height: float = total_powerups * POWERUP_SPACING
	var start_y: float = (screen_size.y / 2.0) - (total_height / 2.0)

	# Reposition ALL powerup displays to maintain proper spacing
	var powerup_index = 0
	for child in ui_layer.get_children():
		if child.has_method("setup"):  # Check if it's a PowerupDisplay
			child.position = Vector2(x_position, start_y + (powerup_index * POWERUP_SPACING))
			powerup_index += 1
