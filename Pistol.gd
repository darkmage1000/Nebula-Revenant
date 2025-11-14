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
	var closest_target: Node2D = null
	var min_distance: float = 999999.0
	const BASE_ATTACK_RANGE: float = 800.0
	var max_attack_range = BASE_ATTACK_RANGE * player.player_stats.get("attack_range_mult", 1.0)

	# Get all targetable entities (mobs, asteroids, and flowers)
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	for target in all_targets:
		if is_instance_valid(target) and target is Node2D:
			var distance = global_position.distance_to(target.global_position)
			# Only target enemies within range
			if distance < min_distance and distance <= max_attack_range:
				min_distance = distance
				closest_target = target as Node2D

	if is_instance_valid(closest_target):
		return global_position.direction_to(closest_target.global_position)
	else:
		return Vector2.ZERO  # Don't shoot if no enemies in range

# Get N nearest targets for multi-projectile targeting
func get_nearest_targets(count: int) -> Array[Node2D]:
	const BASE_ATTACK_RANGE: float = 800.0
	var max_attack_range = BASE_ATTACK_RANGE * player.player_stats.get("attack_range_mult", 1.0)
	var targets: Array[Node2D] = []

	# Get all targetable entities
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	# Create array of [target, distance] pairs
	var target_distances: Array = []
	for target in all_targets:
		if is_instance_valid(target) and target is Node2D:
			var distance = global_position.distance_to(target.global_position)
			if distance <= max_attack_range:
				target_distances.append({"target": target, "distance": distance})

	# Sort by distance
	target_distances.sort_custom(func(a, b): return a.distance < b.distance)

	# Return N nearest targets
	for i in range(min(count, target_distances.size())):
		targets.append(target_distances[i].target as Node2D)

	return targets 

func shoot():
	if not is_instance_valid(player) or not is_instance_valid(shooting_point):
		return

	# FIXED: Use player.player_stats.projectiles
	var total_projectiles = stats.projectiles + player.player_stats.projectiles
	var final_damage = stats.damage * player.player_stats.damage_mult

	var bullet_scene = preload("res://bullet.tscn")

	# Get multiple targets for smart targeting
	var targets = get_nearest_targets(total_projectiles)

	# Don't shoot if no targets in range
	if targets.is_empty():
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

		# Smart targeting: aim at different enemies if available
		var direction: Vector2
		if i < targets.size():
			# Aim at a unique target
			direction = global_position.direction_to(targets[i].global_position)
		else:
			# More projectiles than targets - use spread from first target
			direction = global_position.direction_to(targets[0].global_position)
			var excess_index = i - targets.size()
			var total_spread_deg = 30.0
			var start_angle = -total_spread_deg / 2.0
			var excess_count = total_projectiles - targets.size()
			var step = total_spread_deg / max(1.0, float(excess_count - 1))
			var spread_angle = deg_to_rad(start_angle + (step * excess_index))
			direction = direction.rotated(spread_angle)

		new_bullet.rotation = direction.angle()

		player.get_parent().add_child(new_bullet)

		# FIXED: Report damage for lifesteal
		player.report_weapon_damage("pistol", final_damage)
