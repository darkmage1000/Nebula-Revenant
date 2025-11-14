# Spaceship.gd - Suicide bomber ship that orbits then dashes at enemies
extends Area2D

var damage: float = 20.0
var move_speed: float = 250.0
var size_mult: float = 1.0
var pierce: int = 0
var player: CharacterBody2D = null
var orbit_angle: float = 0.0

# Evolution flags
var carrier_fleet: bool = false
var kamikaze: bool = false

# State machine
enum State { ORBITING, DASHING, SEEKING }
var current_state: State = State.ORBITING
var state_timer: float = 0.0
const ORBIT_DURATION: float = 2.0  # Increased from 0.75 - ships orbit longer before dashing
const DASH_TIMEOUT: float = 1.5  # Switch to seeking after 1.5s of dashing
const ORBIT_RADIUS: float = 80.0

# Dash state
var dash_target: Node2D = null
var dash_direction: Vector2 = Vector2.ZERO
var dash_timer: float = 0.0  # Track how long we've been dashing

# Seeking state
const SEEKING_SPEED_MULT: float = 1.2  # 20% faster in seeking mode
var seeking_update_timer: float = 0.0
const SEEKING_UPDATE_INTERVAL: float = 0.1  # Update target every 0.1s

# Pierce tracking
var hit_count: int = 0
var hit_enemies: Array = []  # Track which enemies we've already hit

# Reference to sprite
var sprite: Sprite2D = null

func _ready():
	# Setup collision
	collision_layer = 0
	collision_mask = 10  # Layers 2 (mobs) + 8 (asteroids/flowers)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

	# Get sprite reference and apply size multiplier
	sprite = get_node_or_null("Sprite2D")
	if sprite:
		sprite.scale = Vector2.ONE * 0.4 * size_mult  # Base scale 0.4, adjusted by size_mult

		# KAMIKAZE: Red/orange tint for instant dash ships
		if kamikaze:
			sprite.modulate = Color(1.0, 0.5, 0.3)

	# KAMIKAZE: Skip orbiting, dash immediately
	if kamikaze:
		current_state = State.DASHING
		state_timer = 0.0
		start_dashing()

func _process(delta: float):
	if current_state == State.ORBITING:
		process_orbiting(delta)
	elif current_state == State.DASHING:
		process_dashing(delta)
	elif current_state == State.SEEKING:
		process_seeking(delta)

func process_orbiting(delta: float):
	if not is_instance_valid(player):
		queue_free()
		return

	state_timer += delta

	# Orbit around player
	orbit_angle += delta * 3.0  # Rotation speed
	var orbit_offset = Vector2(cos(orbit_angle), sin(orbit_angle)) * ORBIT_RADIUS
	global_position = player.global_position + orbit_offset

	# Point in direction of movement
	var next_angle = orbit_angle + delta * 3.0
	var next_pos = Vector2(cos(next_angle), sin(next_angle)) * ORBIT_RADIUS
	var direction = (next_pos - orbit_offset).normalized()
	rotation = direction.angle()

	# Switch to dashing state after duration
	if state_timer >= ORBIT_DURATION:
		start_dashing()

func start_dashing():
	current_state = State.DASHING
	dash_timer = 0.0  # Reset dash timer

	# Find nearest enemy
	dash_target = get_nearest_enemy()

	if dash_target:
		dash_direction = global_position.direction_to(dash_target.global_position)
		rotation = dash_direction.angle()
	else:
		# No enemies found, just dash in current facing direction
		dash_direction = Vector2.RIGHT.rotated(rotation)

func process_dashing(delta: float):
	dash_timer += delta

	# Move in dash direction
	global_position += dash_direction * move_speed * delta

	# Update direction toward target if still valid
	if is_instance_valid(dash_target):
		dash_direction = global_position.direction_to(dash_target.global_position)
		rotation = dash_direction.angle()

	# Switch to seeking mode if we've been dashing too long without hitting
	if dash_timer >= DASH_TIMEOUT:
		start_seeking()
		return

	# Despawn if too far from player (off-screen)
	if is_instance_valid(player):
		var distance_from_player = global_position.distance_to(player.global_position)
		if distance_from_player > 2000.0:
			queue_free()

func get_nearest_enemy() -> Node2D:
	var closest_target: Node2D = null
	var min_distance: float = 999999.0
	const MAX_SEARCH_RANGE: float = 1000.0

	# Get all targetable entities
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	for target in all_targets:
		if is_instance_valid(target) and target is Node2D:
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance and distance <= MAX_SEARCH_RANGE:
				min_distance = distance
				closest_target = target as Node2D

	return closest_target

func start_seeking():
	current_state = State.SEEKING
	seeking_update_timer = 0.0

	# Visual indicator: increase speed in seeking mode
	# Sprite modulation will show slightly brighter/different color
	if sprite:
		sprite.modulate = Color(1.3, 1.3, 1.5)  # Slight cyan/blue tint for seeking mode

func process_seeking(delta: float):
	seeking_update_timer += delta

	# Update target periodically for performance
	if seeking_update_timer >= SEEKING_UPDATE_INTERVAL:
		seeking_update_timer = 0.0

		var nearest = get_nearest_enemy()
		if nearest:
			dash_direction = global_position.direction_to(nearest.global_position)
			rotation = dash_direction.angle()
		# If no enemies, keep current direction

	# Move at increased speed in seeking mode
	global_position += dash_direction * move_speed * SEEKING_SPEED_MULT * delta

	# Despawn if too far from player (off-screen)
	if is_instance_valid(player):
		var distance_from_player = global_position.distance_to(player.global_position)
		if distance_from_player > 2000.0:
			queue_free()

func _on_body_entered(body: Node):
	# Hit a mob (CharacterBody2D)
	if body.is_in_group("mob"):
		apply_damage_to_target(body)

func _on_area_entered(area: Area2D):
	# Hit an obstacle (asteroid or flower - Area2D)
	if area.is_in_group("asteroid") or area.is_in_group("flower"):
		apply_damage_to_target(area)

func apply_damage_to_target(target: Node):
	if not is_instance_valid(target):
		return

	# Check if we already hit this enemy (for pierce)
	var target_id = target.get_instance_id()
	if target_id in hit_enemies:
		return

	hit_enemies.append(target_id)

	# Apply damage with crit calculation
	var is_crit = false
	var final_damage = damage

	if is_instance_valid(player) and player.player_stats:
		if randf() < player.player_stats.get("crit_chance", 0.0):
			is_crit = true
			final_damage *= player.player_stats.get("crit_damage", 1.5)

	# Apply damage to target
	if target.has_method("take_damage"):
		target.take_damage(final_damage, false, is_crit)

	# Report damage for lifesteal
	if is_instance_valid(player):
		player.report_weapon_damage("spaceship", final_damage)

	# Increment hit count
	hit_count += 1

	# KAMIKAZE: Create AOE explosion on hit
	if kamikaze:
		create_kamikaze_explosion()

	# Despawn if we've hit our pierce limit
	if pierce == 0:
		# No pierce - despawn immediately
		despawn_ship()
	elif hit_count > pierce:
		# Hit more enemies than pierce allows
		despawn_ship()

func despawn_ship():
	# CARRIER FLEET: Spawn mini-drones on death
	if carrier_fleet:
		spawn_mini_drones()

	queue_free()

func create_kamikaze_explosion():
	# Create AOE explosion (80px radius)
	const EXPLOSION_RADIUS: float = 80.0

	# Visual explosion effect
	var explosion = Node2D.new()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	# Create explosion circles
	for i in range(2):
		var circle_drawer = Node2D.new()
		explosion.add_child(circle_drawer)

		var circle_size = EXPLOSION_RADIUS * (1.0 + i * 0.3)
		var circle_color = Color(1.0, 0.4 - i * 0.1, 0.0, 0.7 - i * 0.2)  # Orange-red

		circle_drawer.draw.connect(func():
			circle_drawer.draw_circle(Vector2.ZERO, circle_size, circle_color)
		)
		circle_drawer.queue_redraw()

		var tween = explosion.create_tween()
		tween.tween_property(circle_drawer, "scale", Vector2(1.3, 1.3), 0.2)
		tween.parallel().tween_property(circle_drawer, "modulate:a", 0.0, 0.2)

	# Damage enemies in explosion radius
	var enemies = get_tree().get_nodes_in_group("mob")
	var asteroids = get_tree().get_nodes_in_group("asteroid")
	var flowers = get_tree().get_nodes_in_group("flower")
	var all_targets = enemies + asteroids + flowers

	for enemy in all_targets:
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue

		var dist = global_position.distance_to(enemy.global_position)
		if dist <= EXPLOSION_RADIUS:
			# Skip the initial target (already damaged)
			var enemy_id = enemy.get_instance_id()
			if enemy_id in hit_enemies:
				continue

			# Apply explosion damage (50% of ship damage)
			var explosion_damage = damage * 0.5
			var is_crit = false

			if is_instance_valid(player) and player.player_stats:
				if randf() < player.player_stats.get("crit_chance", 0.0):
					is_crit = true
					explosion_damage *= player.player_stats.get("crit_damage", 1.5)

			if enemy.has_method("take_damage"):
				enemy.take_damage(explosion_damage, false, is_crit)

			if is_instance_valid(player):
				player.report_weapon_damage("spaceship", explosion_damage)

	# Delete explosion visual
	get_tree().create_timer(0.25).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

func spawn_mini_drones():
	# Spawn 2 mini-drones that seek enemies
	const SPACESHIP_SCENE = preload("res://Spaceship.tscn")

	for i in range(2):
		var drone = SPACESHIP_SCENE.instantiate()
		drone.global_position = global_position

		# Mini-drones: 30% damage, faster, smaller, no evolutions
		drone.damage = damage * 0.3
		drone.move_speed = move_speed * 1.5
		drone.size_mult = 0.6
		drone.pierce = 0
		drone.player = player
		drone.carrier_fleet = false  # Don't recursively spawn
		drone.kamikaze = false

		# Start in seeking mode (skip orbit)
		drone.current_state = State.SEEKING
		drone.dash_direction = Vector2.RIGHT.rotated(randf() * TAU)  # Random direction

		# Visual: Cyan tint for mini-drones
		await get_tree().process_frame  # Wait for drone to be ready
		if drone.sprite:
			drone.sprite.modulate = Color(0.5, 1.0, 1.0)

		get_parent().add_child(drone)
