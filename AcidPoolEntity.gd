# AcidPoolEntity.gd - Acid pool that applies unique DOT to enemies (no stacking)
extends Area2D

var damage_per_tick: float = 10.0
var tick_rate: float = 0.4
var duration: float = 1.5
var radius: float = 50.0
var player: CharacterBody2D = null

# Evolution flags
var corrosive_nova: bool = false
var lingering_death: bool = false

var lifetime_timer: float = 0.0
var tick_timer: float = 0.0
var pool_key: String = ""  # Unique identifier for this pool's DOT

# Track enemies currently in the pool
var enemies_in_pool: Dictionary = {}

# Corrosive Nova timing
const NOVA_EXPLOSION_DELAY: float = 1.0
var has_exploded: bool = false

func _ready():
	# Generate unique pool key for DOT tracking
	pool_key = "acid_pool_" + str(get_instance_id())

	# Setup collision
	collision_layer = 0
	collision_mask = 2  # Layer 2 = mobs

	# Create collision shape
	var collision_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape
	add_child(collision_shape)

	# Setup visual
	setup_visual()

	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func setup_visual():
	# Create acid pool visual using Polygon2D for a circle
	var pool_visual = Node2D.new()
	add_child(pool_visual)

	# Draw acid pool as filled circle
	pool_visual.draw.connect(func():
		# Draw outer glow
		pool_visual.draw_circle(Vector2.ZERO, radius, Color(0.8, 1.0, 0.3, 0.3))
		# Draw main pool
		pool_visual.draw_circle(Vector2.ZERO, radius * 0.8, Color(0.7, 0.95, 0.2, 0.5))
		# Draw inner highlight
		pool_visual.draw_circle(Vector2.ZERO, radius * 0.5, Color(0.9, 1.0, 0.6, 0.4))
	)
	pool_visual.queue_redraw()

func _process(delta: float):
	# Update lifetime
	lifetime_timer += delta

	# CORROSIVE NOVA: Explode after 1 second
	if corrosive_nova and not has_exploded and lifetime_timer >= NOVA_EXPLOSION_DELAY:
		explode_nova()
		has_exploded = true

	if lifetime_timer >= duration:
		despawn()
		return

	# Update tick timer
	tick_timer += delta
	if tick_timer >= tick_rate:
		tick_timer = 0.0
		damage_enemies()

	# Pulsing visual effect
	queue_redraw()

func _draw():
	# Add pulsing glow effect
	var t = Time.get_ticks_msec() * 0.001
	var pulse = 0.3 + 0.2 * sin(t * 5.0)

	# Outer glow
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0.8, 1.0, 0.3, pulse * 0.2))
	# Main pool
	draw_circle(Vector2.ZERO, radius, Color(0.7, 0.95, 0.2, 0.4 + pulse * 0.1))
	# Bubbling effect - small circles
	for i in range(3):
		var bubble_offset = Vector2(
			cos(t * 3.0 + i * 2.0) * radius * 0.5,
			sin(t * 3.0 + i * 2.0) * radius * 0.5
		)
		draw_circle(bubble_offset, radius * 0.15, Color(0.95, 1.0, 0.4, pulse))

func _on_body_entered(body: Node):
	# Enemy entered pool
	if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
		var body_id = body.get_instance_id()
		enemies_in_pool[body_id] = body

		# Apply initial DOT
		apply_dot_to_enemy(body)

func _on_body_exited(body: Node):
	# Enemy exited pool
	if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
		var body_id = body.get_instance_id()
		enemies_in_pool.erase(body_id)

		# Remove this pool's DOT from enemy
		if is_instance_valid(body) and body.has_method("stop_dot"):
			body.stop_dot(pool_key)

		# LINGERING DEATH: Restore original speed
		if lingering_death and is_instance_valid(body):
			restore_enemy_speed(body)

func damage_enemies():
	# Apply damage tick to all enemies in pool
	for enemy_id in enemies_in_pool:
		var enemy = enemies_in_pool[enemy_id]
		if is_instance_valid(enemy):
			apply_dot_to_enemy(enemy)

func apply_dot_to_enemy(enemy: Node):
	if not is_instance_valid(enemy):
		return

	# Apply damage directly and show damage number immediately
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage_per_tick, true)  # is_dot = true

	# LINGERING DEATH: Apply 40% slow
	if lingering_death and enemy.has_method("get") and enemy.has_method("set"):
		var original_speed = enemy.get("base_speed")
		if original_speed == null:
			# Store base speed if not already stored
			original_speed = enemy.get("speed")
			if original_speed != null:
				enemy.set("base_speed", original_speed)

		if original_speed != null:
			enemy.speed = original_speed * 0.6  # 40% slow = 60% speed

	# Show damage number with bright lime-green color
	if enemy.has_method("show_damage_number"):
		enemy.show_damage_number(damage_per_tick, Color(0.7, 0.95, 0.2))

	# Report damage for lifesteal (per tick)
	if is_instance_valid(player):
		player.report_weapon_damage("acid_pool", damage_per_tick)

func despawn():
	# Remove DOTs from all enemies in pool
	for enemy_id in enemies_in_pool:
		var enemy = enemies_in_pool[enemy_id]
		if is_instance_valid(enemy):
			if enemy.has_method("stop_dot"):
				enemy.stop_dot(pool_key)

			# LINGERING DEATH: Restore speed on despawn
			if lingering_death:
				restore_enemy_speed(enemy)

	queue_free()

func explode_nova():
	# CORROSIVE NOVA: Explode after 1s dealing 100% damage in 120px radius
	const EXPLOSION_RADIUS: float = 120.0

	# Visual explosion
	var explosion = Node2D.new()
	explosion.global_position = global_position
	get_parent().add_child(explosion)

	# Create explosion circles (green acid explosion)
	for i in range(3):
		var circle_drawer = Node2D.new()
		explosion.add_child(circle_drawer)

		var circle_size = EXPLOSION_RADIUS * (1.0 + i * 0.2)
		var circle_color = Color(0.7, 0.95, 0.2, 0.6 - i * 0.15)  # Lime green

		circle_drawer.draw.connect(func():
			circle_drawer.draw_circle(Vector2.ZERO, circle_size, circle_color)
		)
		circle_drawer.queue_redraw()

		var tween = explosion.create_tween()
		tween.tween_property(circle_drawer, "scale", Vector2(1.2, 1.2), 0.3)
		tween.parallel().tween_property(circle_drawer, "modulate:a", 0.0, 0.3)

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
			# Explosion damage = 100% of pool's damage per tick
			var explosion_damage = damage_per_tick
			var is_crit = false

			if is_instance_valid(player) and player.player_stats:
				if randf() < player.player_stats.get("crit_chance", 0.0):
					is_crit = true
					explosion_damage *= player.player_stats.get("crit_damage", 1.5)

			if enemy.has_method("take_damage"):
				enemy.take_damage(explosion_damage, false, is_crit)

			if is_instance_valid(player):
				player.report_weapon_damage("acid_pool", explosion_damage)

	# Delete explosion visual
	get_tree().create_timer(0.35).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

func restore_enemy_speed(enemy: Node):
	# Restore enemy to original speed
	if enemy.has_method("get"):
		var base_speed = enemy.get("base_speed")
		if base_speed != null:
			enemy.speed = base_speed
