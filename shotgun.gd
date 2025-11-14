# shotgun.gd – FIXED: AUTO-AIMS AT CLOSEST ENEMY LIKE PISTOL!
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null
var time_since_last_shot: float = 0.0

const BULLET_SCENE = preload("res://bullet.tscn")
@onready var shooting_point: Marker2D = $ShootingPoint

func _ready():
	add_to_group("weapon")

func set_player_ref(p: CharacterBody2D):
	player = p

func set_stats(new_stats: Dictionary):
	stats = new_stats.duplicate()

func _process(delta: float):
	if not is_instance_valid(player) or stats.is_empty():
		return
	
	time_since_last_shot += delta
	
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = stats.attack_speed * attack_mult
	var shoot_cooldown = 1.0 / max(0.1, final_attack_speed)

	if time_since_last_shot >= shoot_cooldown:
		shoot()
		time_since_last_shot = 0.0

# Find closest enemy within range
func get_direction_to_closest_enemy() -> Vector2:
	var closest_target: Node2D = null
	var min_distance: float = 999999.0
	const BASE_ATTACK_RANGE: float = 600.0  # Shotgun has shorter range than pistol
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

func shoot():
	if not is_instance_valid(player) or not is_instance_valid(shooting_point):
		return
	
	var projectile_count = stats.projectiles + player.player_stats.projectiles
	var final_damage = stats.damage * player.player_stats.damage_mult
	var angle_spread = stats.get("spread", 0.4)
	
	# Get direction to closest enemy
	var base_direction = get_direction_to_closest_enemy()
	
	# Don't shoot if no target in range
	if base_direction == Vector2.ZERO:
		return
	
	for i in range(projectile_count):
		var new_bullet = BULLET_SCENE.instantiate()
		
		new_bullet.global_position = shooting_point.global_position
		
		new_bullet.damage = final_damage
		new_bullet.pierce = stats.get("pierce", 0)
		new_bullet.poison_enabled = stats.get("poison", false)
		if stats.get("poison", false):
			new_bullet.poison_damage = stats.damage
		new_bullet.burn_enabled = stats.get("burn", false)
		if stats.get("burn", false):
			new_bullet.burn_damage = stats.damage * 0.5
		new_bullet.knockback_amount = stats.get("knockback", 50.0)
		new_bullet.player = player
		
		# Random spread from the base direction
		var spread_angle = randf_range(-angle_spread / 2, angle_spread / 2)
		new_bullet.rotation = base_direction.angle() + spread_angle
		
		player.get_parent().add_child(new_bullet)
		
		player.report_weapon_damage("shotgun", final_damage)
