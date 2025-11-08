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
	"max_weapon_slots": 6,
	"current_weapons": [],
	"character_type": "ranger"  # NEW: "ranger" or "swordmaiden"
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
		"poison": false, "burn": false, "aoe": 100, "distance": 300,
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
		"damage": 25, "attack_speed": 2.0, "projectiles": 0,
		"pierce": 0, "knockback": 50, "spread": 0.0,
		"poison": false, "burn": false, "aoe": 80, "distance": 100,
		"level": 0, "melee": true
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
	],
	"sword": [
		{"damage": 35, "aoe": 100, "knockback": 100},
		{"damage": 50, "aoe": 120, "attack_speed": 2.5}
	]
}

# ==============================================================
# 5. NODES
# ==============================================================
@onready var hurt_box = $HurtBox
@onready var pickup_radius = $PickupRadius
@onready var sprite = $Sprite2D

# ==============================================================
# 6. _READY
# ==============================================================
func _ready():
	# Add player to group so chests can find it
	add_to_group("player")

	player_stats.current_health = player_stats.max_health
	apply_starting_bonuses()
	apply_character_bonuses()
	run_stats.start_time = Time.get_ticks_msec() / 1000.0

	if pickup_radius:
		var collision_shape = pickup_radius.get_node("CollisionShape2D")
		if collision_shape and collision_shape.shape:
			collision_shape.shape.radius = player_stats.pickup_radius

	# Set starting weapon based on character
	if player_stats.character_type == "ranger":
		add_weapon("pistol")
	elif player_stats.character_type == "swordmaiden":
		add_weapon("sword")

func apply_character_bonuses():
	# Swordmaiden: melee specialist with tankier stats
	if player_stats.character_type == "swordmaiden":
		player_stats.max_health += 50  # 150 HP total
		player_stats.current_health = player_stats.max_health
		player_stats.armor += 5  # More armor
		player_stats.health_regen += 0.3  # Better regen
		player_stats.pickup_radius += 50  # Larger pickup radius
		print("🗡️ Swordmaiden bonus: +50 HP, +5 Armor, +0.3 Regen")

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

	const DAMAGE_RATE = 6.0
	var overlapping_mobs = hurt_box.get_overlapping_bodies()
	if overlapping_mobs.size() > 0:
		var dmg = DAMAGE_RATE * overlapping_mobs.size() * delta
		dmg = max(1.0, dmg - player_stats.armor * delta)
		player_stats.current_health -= dmg
		if player_stats.current_health <= 0:
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
# 8. XP + LEVEL UP
# ==============================================================
func pickup_xp(amount: int) -> void:
	var luck_mult = 1.0 + (player_stats.luck * 0.10)
	var final_amount = int(amount * luck_mult)
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
	sword_timer.wait_time = 1.0 / data.attack_speed
	sword_timer.timeout.connect(_on_sword_attack)
	sword_timer.autostart = true
	add_child(sword_timer)
	print("🗡️ Created Energy Sword weapon!")

func _on_sword_attack():
	# Get sword data
	if not weapon_data.has("sword"):
		return
	
	var data = weapon_data["sword"]
	var sword_range = data.distance
	var sword_damage = data.damage * player_stats.damage_mult
	var sword_aoe = data.aoe
	
	# Find enemies in melee range
	var enemies = get_tree().get_nodes_in_group("mob")
	var hit_enemies = []
	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
			
		var dist = global_position.distance_to(enemy.global_position)
		if dist <= sword_range:
			hit_enemies.append(enemy)
	
	# Hit closest enemies (up to 3)
	hit_enemies.sort_custom(func(a, b): return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	
	var hits = 0
	for enemy in hit_enemies:
		if hits >= 3:  # Max 3 enemies per swing
			break
			
		if enemy.has_method("take_damage"):
			var crit = randf() < player_stats.crit_chance
			var final_dmg = sword_damage
			if crit:
				final_dmg *= player_stats.crit_damage
			
			enemy.take_damage(final_dmg, false, crit)
			report_weapon_damage("sword", final_dmg)
			
			# Apply knockback
			if enemy.has_method("apply_knockback"):
				var knockback_dir = (enemy.global_position - global_position).normalized()
				enemy.apply_knockback(knockback_dir * data.knockback)
			
			hits += 1
	
	if hits > 0:
		# Visual feedback - sword slash effect (optional)
		create_slash_effect()

func create_slash_effect():
	# Simple pink energy slash visual
	var slash = Node2D.new()
	slash.global_position = global_position
	get_parent().add_child(slash)
	
	# Get direction to nearest enemy
	var enemies = get_tree().get_nodes_in_group("mob")
	var nearest = null
	var nearest_dist = INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist = global_position.distance_to(enemy.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = enemy
	
	if nearest:
		slash.rotation = global_position.angle_to_point(nearest.global_position) + PI/2
	
	slash.modulate = Color(1, 0.4, 0.8, 0.8)  # Pink energy color
	
	# Fade out
	var tween = create_tween()
	tween.tween_property(slash, "modulate:a", 0.0, 0.3)
	tween.tween_callback(slash.queue_free)

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
			"damage", "projectiles", "pierce", "knockback", "aoe", "distance":
				data[upgrade_key] += value
			"attack_speed", "spread":
				data[upgrade_key] *= (1.0 + value)
			"poison", "burn":
				data[upgrade_key] = true
		
		print("Upgraded weapon '%s' %s: %s → %s" % [weapon_key, upgrade_key, str(old_value), str(data[upgrade_key])])
	else:
		print("ERROR: Weapon '%s' doesn't have stat '%s'" % [weapon_key, upgrade_key])
	
	# Update sword timer if upgrading sword attack speed
	if weapon_key == "sword" and upgrade_key == "attack_speed":
		var sword_timer = get_node_or_null("SwordTimer")
		if sword_timer:
			sword_timer.wait_time = 1.0 / data.attack_speed
	
	_update_weapon_instance(weapon_key, data)

func _update_all_weapons() -> void:
	for weapon_key in player_stats.current_weapons:
		if weapon_data.has(weapon_key):
			_update_weapon_instance(weapon_key, weapon_data[weapon_key])

func _update_weapon_instance(weapon_key: String, data: Dictionary) -> void:
	for child in get_children():
		if child.has_method("set_stats") and child.get("stats"):
			var weapon_stats = child.get("stats")
			if weapon_stats and weapon_stats.get("name") == data.name:
				child.set_stats(data)
				print("Updated live weapon: ", weapon_key)

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
	var powerup_type = powerup.get_meta("powerup_type", "unknown")
	
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
	print("⭐ INVINCIBLE for 10 seconds!")
	show_powerup_text("INVINCIBLE!", Color(1, 1, 0, 1))
	create_powerup_display("invincible", 10.0)
	player_stats.armor += 1000
	await get_tree().create_timer(10.0).timeout
	player_stats.armor = max(0, player_stats.armor - 1000)

func activate_magnet():
	print("🧲 MAGNET activated!")
	show_powerup_text("MAGNET!", Color(0, 1, 1, 1))
	# Pull all XP vials visually to player
	var vials = get_tree().get_nodes_in_group("xp_vial")
	for vial in vials:
		if is_instance_valid(vial) and vial.has_method("start_pull"):
			vial.start_pull(self)
			# Vials will move to player and collect automatically

func activate_triple_attack_speed():
	print("⚡ TRIPLE ATTACK SPEED for 10 seconds!")
	show_powerup_text("RAPID FIRE!", Color(1, 0, 1, 1))
	create_powerup_display("attack_speed", 10.0)

	# Multiply attack speed by 3x
	player_stats.attack_speed_mult *= 3.0
	_update_all_weapons()

	# Update sword timer too
	if has_node("SwordTimer") and weapon_data.has("sword"):
		var sword_timer = get_node("SwordTimer")
		sword_timer.wait_time = 1.0 / (weapon_data["sword"].attack_speed * 3.0)

	await get_tree().create_timer(10.0).timeout

	# Divide by 3x to remove this powerup's effect (handles stacking correctly)
	player_stats.attack_speed_mult /= 3.0
	_update_all_weapons()

	# Reset sword timer
	if has_node("SwordTimer") and weapon_data.has("sword"):
		var sword_timer = get_node("SwordTimer")
		sword_timer.wait_time = 1.0 / weapon_data["sword"].attack_speed

func activate_nuke():
	print("💣 NUKE!")
	show_powerup_text("NUKE!", Color(1, 0.5, 0, 1))
	var enemies = get_tree().get_nodes_in_group("mob")
	var killed = 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_in_group("boss"):
			if enemy.has_method("take_damage"):
				enemy.take_damage(99999)
				killed += 1
	print("💣 Nuke killed %d enemies!" % killed)

# ==============================================================
# 16. CHARACTER SELECTION
# ==============================================================
func set_character(char_type: String):
	player_stats.character_type = char_type

	# Update sprite if it exists
	if sprite and ResourceLoader.exists("res://female_hero.png") and char_type == "swordmaiden":
		sprite.texture = load("res://female_hero.png")
		sprite.scale = Vector2(1.5, 1.5)
	elif sprite and char_type == "ranger":
		# Keep default player sprite
		pass

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

	var display = POWERUP_DISPLAY_SCENE.instantiate()
	display.setup(powerup_type, duration)

	# Position in top-right corner
	display.position = Vector2(get_viewport().get_visible_rect().size.x - 60, 80)

	# Offset down for multiple active powerups
	var existing_powerups = 0
	for child in ui_layer.get_children():
		if child.has_method("setup"):  # Check if it's a PowerupDisplay
			existing_powerups += 1

	display.position.y += existing_powerups * 60

	ui_layer.add_child(display)
