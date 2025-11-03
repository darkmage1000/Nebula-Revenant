# player.gd – FIXED: ALL UPGRADES WORK PROPERLY
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
	"health_regen": 0.5,          # HP per second
	"shield": 50.0,
	"shield_recharge_rate": 5.0,
	"lifesteal": 0.0,             # % of damage dealt healed back
	"armor": 0,                   # Flat damage reduction
	"speed": 600.0,
	"attack_speed_mult": 1.0,
	"damage_mult": 1.0,
	"aoe_mult": 1.0,
	"projectiles": 0,
	"crit_chance": 0.05,
	"crit_damage": 1.5,
	"pickup_radius": 100.0,       # XP collection radius
	"luck": 0,                    # Better drops & XP
	"max_weapon_slots": 6,
	"current_weapons": []  # Changed to start empty - pistol added in _ready
}

# ==============================================================
# 2. DAMAGE TRACKING (for lifesteal)
# ==============================================================
var weapon_damage_dealt: Dictionary = {}

# ==============================================================
# 3. WEAPON DATABASE – ALL STATS INCLUDED
# ==============================================================
var weapon_data = {
	"pistol": {
		"name": "Pistol", "scene": preload("res://Pistol.tscn"),
		"damage": 12, "attack_speed": 1.5, "projectiles": 1,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 0, "distance": 0,
		"level": 1  # Pistol starts at level 1
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
		"poison": false, "burn": false, "aoe": 100, "distance": 300,
		"level": 0
	},
	"aura": {
		"name": "Radiation Aura", "scene": preload("res://RadiationAura.tscn"),
		"damage": 8, "attack_speed": 5.0, "projectiles": 0,
		"pierce": 0, "knockback": 0, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 150, "distance": 0,
		"level": 0
	}
}

# ==============================================================
# 4. WEAPON UPGRADE PATHS
# ==============================================================
var weapon_upgrade_paths = {
	"pistol": [
		{"damage": 16, "projectiles": 2, "pierce": 1},
		{"damage": 20, "attack_speed": 1.8, "projectiles": 3, "pierce": 1},
		{"damage": 25, "attack_speed": 2.0, "projectiles": 4, "pierce": 2}
	],
	"shotgun": [
		{"damage": 10, "projectiles": 5, "pierce": 1},
		{"damage": 12, "attack_speed": 1.0, "projectiles": 6, "pierce": 2}
	],
	"grenade": [
		{"damage": 60, "aoe": 120},
		{"damage": 75, "aoe": 140}
	],
	"aura": [
		{"damage": 10, "aoe": 180},
		{"damage": 12, "aoe": 210}
	]
}

# ==============================================================
# 5. NODES
# ==============================================================
@onready var hurt_box = $HurtBox
@onready var pickup_radius = $PickupRadius

# ==============================================================
# 6. _READY
# ==============================================================
func _ready():
	player_stats.current_health = player_stats.max_health
	
	# Set initial pickup radius
	if pickup_radius:
		var collision_shape = pickup_radius.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			collision_shape.shape.radius = player_stats.pickup_radius
	
	# Add starting pistol
	add_weapon("pistol")

# ==============================================================
# 7. PHYSICS + INPUT
# ==============================================================
func _physics_process(delta):
	# ---------- MOVEMENT ----------
	var direction = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * player_stats.speed
	move_and_slide()

	# ---------- SCREEN BOUNDS ----------
	var new_pos = global_position
	var screen_size = get_viewport_rect().size
	const PLAYER_SIZE = 50.0
	new_pos.x = clamp(new_pos.x, PLAYER_SIZE, screen_size.x - PLAYER_SIZE)
	new_pos.y = clamp(new_pos.y, PLAYER_SIZE, screen_size.y - PLAYER_SIZE)
	global_position = new_pos

	# ---------- HEALTH REGEN ----------
	player_stats.current_health = min(
		player_stats.current_health + player_stats.health_regen * delta,
		player_stats.max_health
	)

	# ---------- MOB CONTACT DAMAGE ----------
	const DAMAGE_RATE = 6.0
	var overlapping_mobs = hurt_box.get_overlapping_bodies()
	if overlapping_mobs.size() > 0:
		var dmg = DAMAGE_RATE * overlapping_mobs.size() * delta
		# Apply armor reduction (minimum 1 damage)
		dmg = max(1.0, dmg - player_stats.armor * delta)
		player_stats.current_health -= dmg
		if player_stats.current_health <= 0:
			health_depleted.emit()

	# ---------- XP PICKUP ----------
	for area in pickup_radius.get_overlapping_areas():
		if area.is_in_group("xp_vial"):
			pickup_xp(area.value)
			area.queue_free()

# ==============================================================
# 8. XP + LEVEL UP
# ==============================================================
func pickup_xp(amount: int) -> void:
	# Apply luck bonus (each point of luck = +10% XP)
	var luck_mult = 1.0 + (player_stats.luck * 0.10)
	var final_amount = int(amount * luck_mult)
	player_stats.current_xp += final_amount
	
	while player_stats.current_xp >= player_stats.xp_to_next_level:
		player_stats.current_xp -= player_stats.xp_to_next_level
		player_stats.level += 1
		
		# XP SCALING: Designed to reach ~Level 85 at 30 min
		# Formula: Base + (Level^1.15 * Multiplier)
		# This creates exponential growth that slows progression nicely
		player_stats.xp_to_next_level = int(25 + pow(player_stats.level, 1.15) * 8)
		
		# Call parent's level up function
		if get_parent().has_method("show_level_up_options"):
			get_parent().show_level_up_options()
	
	# optional XP bar
	if has_node("UI/XPBar"):
		$UI/XPBar.value = player_stats.current_xp
		$UI/XPBar.max_value = player_stats.xp_to_next_level

# ==============================================================
# 9. WEAPON MANAGEMENT
# ==============================================================
func add_weapon(weapon_key: String) -> void:
	# Check if we already have this weapon
	if player_stats.current_weapons.has(weapon_key):
		print("Already have weapon: ", weapon_key)
		return
	
	# Check max weapon slots
	if player_stats.current_weapons.size() >= player_stats.max_weapon_slots:
		print("Max weapon slots reached!")
		return
	
	# Get weapon data
	if not weapon_data.has(weapon_key):
		print("ERROR: Unknown weapon: ", weapon_key)
		return
	
	var data = weapon_data[weapon_key]
	
	# Set level to 1 if unlocking
	if data.level == 0:
		data.level = 1
	
	# Instantiate weapon
	var new_weapon = data.scene.instantiate()
	
	# Set stats on weapon
	if new_weapon.has_method("set_stats"):
		new_weapon.set_stats(data)
	
	# Set player reference if weapon needs it
	if new_weapon.has_method("set_player_ref"):
		new_weapon.set_player_ref(self)
	
	# Add to scene
	add_child(new_weapon)
	new_weapon.position = Vector2.ZERO
	
	# Track weapon
	player_stats.current_weapons.append(weapon_key)
	
	print("Added weapon: ", weapon_key, " | Total weapons: ", player_stats.current_weapons.size())

# ==============================================================
# 10. DAMAGE REPORTING + LIFESTEAL
# ==============================================================
func report_weapon_damage(weapon_key: String, amount: float) -> void:
	if not weapon_damage_dealt.has(weapon_key):
		weapon_damage_dealt[weapon_key] = 0
	weapon_damage_dealt[weapon_key] += amount
	
	# LIFESTEAL – heal for % of *any* damage dealt
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
			player_stats.current_health += value  # Also gain the health
		"health_regen", "lifesteal", "crit_chance", "projectiles", "max_weapon_slots", "armor", "luck":
			player_stats[stat_key] += value
		"pickup_radius":
			player_stats.pickup_radius += value
			# Update the pickup radius collision shape
			if pickup_radius:
				var collision_shape = pickup_radius.get_node("CollisionShape2D")
				if collision_shape and collision_shape.shape:
					collision_shape.shape.radius = player_stats.pickup_radius
		"speed", "attack_speed_mult", "damage_mult", "aoe_mult", "crit_damage":
			player_stats[stat_key] *= (1.0 + value)
	
	print("Upgraded stat '%s': %.2f → %.2f" % [stat_key, old_value, player_stats[stat_key]])
	
	# Update all active weapons to apply new stats
	_update_all_weapons()

# ==============================================================
# 12. UPGRADE: WEAPONS
# ==============================================================
func upgrade_weapon(weapon_key: String, upgrade_key: String, value) -> void:
	if not weapon_data.has(weapon_key):
		print("ERROR: Unknown weapon: ", weapon_key)
		return
	
	var data = weapon_data[weapon_key]
	
	# Apply the upgrade to the weapon data
	if data.has(upgrade_key):
		var old_value = data[upgrade_key]
		
		match upgrade_key:
			"damage", "projectiles", "pierce", "knockback", "aoe", "distance":
				data[upgrade_key] += value
			"attack_speed", "spread":
				data[upgrade_key] *= (1.0 + value)
			"poison", "burn":
				data[upgrade_key] = true
		
		print("Upgraded weapon '%s' %s: %s → %s" % [weapon_key, upgrade_key, str(old_value), str(data[upgrade_key])])
	else:
		print("ERROR: Weapon '%s' doesn't have stat '%s'" % [weapon_key, upgrade_key])
	
	# Update the live weapon instance
	_update_weapon_instance(weapon_key, data)

# Update all weapon instances with new data
func _update_all_weapons() -> void:
	for weapon_key in player_stats.current_weapons:
		if weapon_data.has(weapon_key):
			_update_weapon_instance(weapon_key, weapon_data[weapon_key])

# Update a specific weapon instance
func _update_weapon_instance(weapon_key: String, data: Dictionary) -> void:
	for child in get_children():
		if child.has_method("set_stats") and child.get("stats"):
			var weapon_stats = child.get("stats")
			if weapon_stats and weapon_stats.get("name") == data.name:
				child.set_stats(data)
				print("Updated live weapon: ", weapon_key)

# ==============================================================
# 14. STATS UI (optional)
# ==============================================================
func get_active_weapons_data() -> Dictionary:
	var active = {}
	for key in player_stats.current_weapons:
		if weapon_data.has(key):
			active[key] = weapon_data[key]
	return active

func get_all_stats() -> Array:
	return [player_stats, get_active_weapons_data()]
