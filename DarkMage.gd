# DarkMage.gd - Ranged enemy that shoots blue fireballs
extends "res://mob.gd"

const PROJECTILE_SCENE = preload("res://DarkMageProjectile.tscn")

var attack_cooldown: float = 2.0  # Shoots every 2 seconds
var attack_timer: float = 0.0
var attack_range: float = 500.0  # Only attacks within this range
var min_distance: float = 200.0  # Tries to keep this distance from player

func _ready():
	# Call parent _ready
	super._ready()

	# Dark Mage specific stats
	base_health = 30.0  # Slightly tankier than normal mob (20 HP)
	base_speed = 120     # Slower than normal mob (150)
	health = base_health
	speed = base_speed
	xp_value = 15       # More XP than normal mob (10)

	# Reapply scaling after setting base stats
	apply_level_scaling()
	max_health = health

	# Start with random attack timer so they don't all shoot at once
	attack_timer = randf_range(0, attack_cooldown)

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction = global_position.direction_to(player.global_position)

	# Movement behavior: maintain distance from player
	if distance_to_player < min_distance:
		# Too close - back away
		direction = -direction
		velocity = direction.normalized() * speed * 0.8  # Move slower when retreating
	elif distance_to_player > attack_range:
		# Too far - move closer
		velocity = direction.normalized() * speed
	else:
		# In attack range - move slowly or stand still
		direction += Vector2(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		velocity = direction.normalized() * speed * 0.3  # Slow movement

	move_and_slide()

	# Attack logic
	attack_timer -= delta
	if attack_timer <= 0 and distance_to_player <= attack_range:
		shoot_at_player()
		attack_timer = attack_cooldown

	# Process DoTs from parent
	_process_dots(delta)

func shoot_at_player():
	if not is_instance_valid(player):
		return

	# Create projectile
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.global_position = global_position

	# Calculate direction to player with slight lead prediction
	var player_velocity = player.velocity if player.has("velocity") else Vector2.ZERO
	var time_to_hit = global_position.distance_to(player.global_position) / projectile.speed
	var predicted_pos = player.global_position + (player_velocity * time_to_hit * 0.3)

	projectile.direction = global_position.direction_to(predicted_pos).normalized()
	projectile.rotation = projectile.direction.angle()

	# Scale damage with difficulty
	var main_game = get_tree().root.get_node_or_null("MainGame")
	if main_game and main_game.has("difficulty_mult"):
		projectile.damage = 8.0 * main_game.difficulty_mult

	# Add to scene
	get_parent().add_child(projectile)

	# Visual feedback - flash
	modulate = Color(1.5, 1.5, 2.0, 1)  # Blue flash
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)
