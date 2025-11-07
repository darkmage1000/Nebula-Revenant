# Pistol.gd – ORIGINAL + DAMAGE & PROJECTILE UPGRADES WORK
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null
var time_since_last_shot: float = 0.0

@onready var shooting_point: Marker2D = $ShootingPoint 

func set_player_ref(player_node: CharacterBody2D):
	player = player_node

func set_stats(new_stats: Dictionary):
	stats = new_stats

func _process(delta: float):
	if not is_instance_valid(player):
		return
		
	time_since_last_shot += delta
	
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = stats.attack_speed * attack_mult
	var shoot_cooldown = 1.0 / max(0.1, final_attack_speed)

	if time_since_last_shot >= shoot_cooldown:
		shoot()
		time_since_last_shot = 0.0

# --- AIM LOGIC WITH MAX RANGE ---
func get_direction_to_closest_enemy() -> Vector2:
	var closest_mob: Node2D = null
	var min_distance: float = 999999.0
	const BASE_ATTACK_RANGE: float = 450.0  # REDUCED from 800 to 450

	# Apply player's attack range multiplier
	var range_mult = player.player_stats.get("attack_range_mult", 1.0)
	var max_attack_range = BASE_ATTACK_RANGE * range_mult

	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")

	for mob in mobs:
		if is_instance_valid(mob) and mob is Node2D:
			var distance = global_position.distance_to(mob.global_position)
			# Only target enemies within range
			if distance < min_distance and distance <= max_attack_range:
				min_distance = distance
				closest_mob = mob as Node2D

	if is_instance_valid(closest_mob):
		return global_position.direction_to(closest_mob.global_position)
	else:
		return Vector2.ZERO  # Don't shoot if no enemies in range 

func shoot():
	if not is_instance_valid(player) or not is_instance_valid(shooting_point):
		return

	# FIXED: Use player.player_stats.projectiles
	var total_projectiles = stats.projectiles + player.player_stats.projectiles
	var final_damage = stats.damage * player.player_stats.damage_mult
	
	var bullet_scene = preload("res://bullet.tscn")
	var base_direction: Vector2 = get_direction_to_closest_enemy()
	
	# Don't shoot if no target in range
	if base_direction == Vector2.ZERO:
		return

	for i in range(total_projectiles):
		var new_bullet = bullet_scene.instantiate()
		
		new_bullet.damage = final_damage
		new_bullet.global_position = shooting_point.global_position
		
		new_bullet.pierce = stats.pierce
		new_bullet.poison_enabled = stats.poison
		if stats.poison:
			new_bullet.poison_damage = stats.damage
		new_bullet.knockback_amount = stats.get("knockback", 0.0)

		var spread_angle = 0.0
		if total_projectiles > 1:
			var total_spread_deg = 30.0
			var start_angle = -total_spread_deg / 2.0
			var step = total_spread_deg / max(1.0, float(total_projectiles - 1))
			spread_angle = deg_to_rad(start_angle + (step * i))
		
		new_bullet.rotation = base_direction.angle() + spread_angle
		
		player.get_parent().add_child(new_bullet)
		
		# FIXED: Report damage for lifesteal
		player.report_weapon_damage("pistol", final_damage)
