# LightningProjectile.gd – Chain Lightning Projectile with visual effects
extends Area2D

# PROJECTILE STATS
var damage: float = 15.0
var chain_targets: int = 1  # How many times it can chain
var chain_range: float = 250.0  # Max distance for chain jumps
var player: CharacterBody2D = null

# EVOLUTION FLAGS
var chain_storm: bool = false  # Infinite chains, can re-hit, -20% damage per chain
var thunder_strike: bool = false  # No chain, +300% damage, 30% stun

# CHAIN TRACKING
var hit_enemies: Array = []  # Track which enemies we've already hit
var chains_remaining: int = 0
var is_chaining: bool = false
var total_chains_done: int = 0  # For Chain Storm damage reduction

# VISUAL TRAIL
var trail_points: Array[Vector2] = []
const MAX_TRAIL_LENGTH: int = 10

func _ready():
	if not player:
		player = get_node_or_null("/root/MainGame/Player")

	chains_remaining = chain_targets

	# Create visual trail effect
	create_lightning_trail()

func _process(delta):
	if not is_chaining:
		# Move forward
		global_position += Vector2(600, 0).rotated(rotation) * delta

		# Add trail point
		trail_points.append(global_position)
		if trail_points.size() > MAX_TRAIL_LENGTH:
			trail_points.pop_front()

		# Update visual trail
		update_trail_visual()

# Handle collision with CharacterBody2D enemies
func _on_body_entered(body):
	if body.is_in_group("mob") and not hit_enemies.has(body):
		apply_hit(body)

# Handle collision with Area2D obstacles (asteroids, flowers)
func _on_area_entered(area):
	if area.is_in_group("asteroid") or area.is_in_group("flower"):
		apply_obstacle_hit(area)

func apply_hit(mob):
	if not is_instance_valid(mob):
		return

	# Mark this enemy as hit (unless Chain Storm allows re-hits)
	if not chain_storm:
		hit_enemies.append(mob)

	# CRITICAL HIT
	var is_crit: bool = false
	var final_damage: float = damage

	# CHAIN STORM: -20% damage per chain
	if chain_storm and total_chains_done > 0:
		var damage_mult = pow(0.8, total_chains_done)  # 0.8^chains
		final_damage *= damage_mult

	if player and player.player_stats:
		if randf() < player.player_stats.crit_chance:
			is_crit = true
			final_damage *= player.player_stats.crit_damage

	# APPLY DAMAGE
	mob.take_damage(final_damage, false, is_crit)

	# THUNDER STRIKE: 30% stun chance
	if thunder_strike and randf() < 0.3:
		apply_stun(mob)

	# LIFESTEAL
	if player:
		player.report_weapon_damage("lightning_spell", final_damage)

	# Create hit visual effect
	create_hit_effect(mob.global_position)

	# CHAIN LIGHTNING LOGIC
	# Chain Storm has infinite chains (always chains)
	# Thunder Strike never chains (chains_remaining already set to 0)
	if chain_storm or chains_remaining > 0:
		chain_to_next_target(mob)
	else:
		destroy_projectile()

func apply_obstacle_hit(obstacle):
	if not is_instance_valid(obstacle):
		return

	# Damage obstacle (asteroid or flower)
	if obstacle.has_method("take_damage"):
		obstacle.take_damage(damage)

	# Create hit visual
	create_hit_effect(obstacle.global_position)

	# Lightning doesn't chain off obstacles - just destroys itself
	destroy_projectile()

func chain_to_next_target(from_mob: Node):
	if not chain_storm:
		chains_remaining -= 1

	total_chains_done += 1

	# Chain Storm safety: stop after 50 chains to prevent infinite loops
	if chain_storm and total_chains_done > 50:
		destroy_projectile()
		return

	# Find nearest enemy within chain range
	var nearest_target: Node2D = null
	var nearest_dist: float = chain_range
	var last_target = from_mob  # Track last target to avoid immediate re-hit

	# Get all targetable entities
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	for target in all_targets:
		if not is_instance_valid(target):
			continue

		# Don't immediately re-hit the same target (prevents bouncing on one enemy)
		if target == last_target:
			continue

		# Don't hit same enemy twice (unless Chain Storm)
		if not chain_storm and hit_enemies.has(target):
			continue

		var dist = from_mob.global_position.distance_to(target.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_target = target

	# Chain to next target if found
	if nearest_target:
		is_chaining = true
		create_chain_beam(from_mob.global_position, nearest_target.global_position)

		# Move to next target and hit it
		global_position = nearest_target.global_position

		if nearest_target.is_in_group("mob"):
			apply_hit(nearest_target)
		else:
			# Hit obstacle (asteroid/flower)
			apply_obstacle_hit(nearest_target)
	else:
		# No more targets in range
		destroy_projectile()

func destroy_projectile():
	# Immediately stop all processing and visuals
	set_process(false)
	visible = false

	# Clear trail
	var trail = get_node_or_null("LightningTrail")
	if trail:
		trail.queue_free()

	# Disable collision
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

	queue_free()

func create_lightning_trail():
	# Create lightning trail visual using Line2D
	var trail = Line2D.new()
	trail.name = "LightningTrail"
	trail.width = 3
	trail.default_color = Color(0.7, 0.7, 1.0, 0.8)  # Light blue
	trail.z_index = -1
	add_child(trail)

func update_trail_visual():
	var trail = get_node_or_null("LightningTrail")
	if trail and trail is Line2D:
		trail.clear_points()
		for point in trail_points:
			# Convert to local coordinates
			trail.add_point(to_local(point))

func create_hit_effect(pos: Vector2):
	# Create lightning hit effect
	var effect = Node2D.new()
	effect.global_position = pos
	get_parent().add_child(effect)

	# Create electric burst particles
	for i in range(8):
		var particle = Line2D.new()
		particle.width = 2
		particle.default_color = Color(0.8, 0.8, 1.0, 1.0)

		var angle = (TAU / 8.0) * i
		var length = randf_range(15, 30)
		var end_point = Vector2(cos(angle), sin(angle)) * length

		particle.add_point(Vector2.ZERO)
		particle.add_point(end_point)

		effect.add_child(particle)

	# Fade out and remove - create tween on the effect itself, not the projectile
	var tween = effect.create_tween()
	tween.tween_property(effect, "modulate:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

func create_chain_beam(from_pos: Vector2, to_pos: Vector2):
	# Create visual chain lightning beam
	var beam = Line2D.new()
	beam.width = 3
	beam.default_color = Color(0.9, 0.9, 1.0, 1.0)  # Bright blue-white
	beam.z_index = 10

	# Add zigzag points for lightning effect
	var direction = (to_pos - from_pos).normalized()
	var distance = from_pos.distance_to(to_pos)
	var segments = int(distance / 30.0)  # Segment every 30 pixels

	beam.add_point(from_pos)

	for i in range(1, segments):
		var t = float(i) / float(segments)
		var mid_point = from_pos.lerp(to_pos, t)

		# Add random perpendicular offset for zigzag effect
		var perpendicular = Vector2(-direction.y, direction.x)
		var offset = perpendicular * randf_range(-15, 15)
		mid_point += offset

		beam.add_point(mid_point)

	beam.add_point(to_pos)

	get_parent().add_child(beam)

	# Fade out and remove beam - create tween on the beam itself, not the projectile
	var tween = beam.create_tween()
	tween.tween_property(beam, "modulate:a", 0.0, 0.2)
	tween.tween_callback(beam.queue_free)

func apply_stun(mob):
	# Thunder Strike stun: 1.5 second freeze
	if not is_instance_valid(mob) or not mob.has_method("set_physics_process"):
		return

	# Store original speed
	var original_speed = mob.get("speed")
	if original_speed == null:
		original_speed = 150  # Default mob speed

	# Freeze enemy
	mob.speed = 0

	# Visual indicator (yellow tint)
	var original_modulate = mob.modulate
	mob.modulate = Color(1.0, 1.0, 0.5, 1.0)  # Yellow tint

	# Restore after 1.5 seconds
	get_tree().create_timer(1.5).timeout.connect(func():
		if is_instance_valid(mob):
			mob.speed = original_speed
			mob.modulate = original_modulate
	)
