# LaserBeam.gd - Auto-aiming laser that tracks nearest enemy and damages all enemies in beam
extends Node2D

var stats: Dictionary = {}
var player: CharacterBody2D = null
var tick_timer: float = 0.0
const TICK_INTERVAL: float = 0.1  # 10 ticks per second (0.1s tick rate)
var laser_length: float = 175.0
var laser_width: float = 12.0
var cone_mode: bool = false

# Evolution flags
var orbital_lasers: bool = false
var death_ray: bool = false

# Visual components
var laser_line: Line2D = null
var laser_polygon: Polygon2D = null
var damage_area: Area2D = null
var collision_shape: CollisionShape2D = null

# Orbital laser components
var orbital_laser_1: Node2D = null
var orbital_laser_2: Node2D = null
var orbital_rotation: float = 0.0
const ORBITAL_DISTANCE: float = 80.0  # Distance from center
const ORBITAL_SPEED: float = 2.0  # Rotations per second

# Additional lasers from +projectiles
var additional_lasers: Array = []

# Tracking hit enemies to avoid multiple hits per tick
var hit_enemies_this_tick: Array = []

func _ready():
	add_to_group("weapon")
	setup_visuals()
	setup_collision()

func setup_visuals():
	# Create Line2D for standard laser beam
	laser_line = Line2D.new()
	laser_line.width = laser_width
	laser_line.default_color = Color(0.0, 0.8, 1.0, 0.8)  # Bright cyan
	laser_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(Vector2(laser_length, 0))
	add_child(laser_line)

	# Create Polygon2D for cone mode (hidden by default)
	laser_polygon = Polygon2D.new()
	laser_polygon.color = Color(0.0, 0.8, 1.0, 0.6)  # Slightly transparent cyan
	laser_polygon.visible = false
	add_child(laser_polygon)

func setup_collision():
	# Create Area2D for damage detection
	damage_area = Area2D.new()
	damage_area.collision_layer = 0
	damage_area.collision_mask = 2  # Layer 2 = mobs
	add_child(damage_area)

	# Create collision shape (will update every frame)
	collision_shape = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(laser_length, laser_width)
	collision_shape.shape = shape
	collision_shape.position = Vector2(laser_length / 2, 0)
	damage_area.add_child(collision_shape)

func set_player_ref(player_node: CharacterBody2D):
	player = player_node

func set_stats(new_stats: Dictionary):
	stats = new_stats.duplicate()
	orbital_lasers = stats.get("orbital_lasers", false)
	death_ray = stats.get("death_ray", false)
	update_laser_size()

	# Create orbital lasers if evolution active
	if orbital_lasers and not orbital_laser_1:
		create_orbital_lasers()

	# Create additional lasers from +projectiles stat
	var num_projectiles = stats.get("projectiles", 0)
	if num_projectiles > additional_lasers.size():
		create_additional_lasers(num_projectiles)

func update_laser_size():
	if stats.is_empty() or not is_instance_valid(player):
		return

	# Calculate final laser properties
	var base_length = stats.get("distance", 175.0)
	var base_width = stats.get("laser_width", 12.0)
	laser_length = base_length * player.player_stats.get("attack_range_mult", 1.0)
	laser_width = base_width
	cone_mode = stats.get("cone_mode", false)

	# Update visuals based on mode
	if cone_mode:
		laser_line.visible = false
		laser_polygon.visible = true
		update_cone_polygon()
	else:
		laser_line.visible = true
		laser_polygon.visible = false
		update_line_laser()

func update_line_laser():
	if not laser_line:
		return
	laser_line.width = laser_width
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(Vector2(laser_length, 0))

	# Update collision shape for line mode
	if collision_shape and collision_shape.shape is RectangleShape2D:
		collision_shape.shape.size = Vector2(laser_length, laser_width)
		collision_shape.position = Vector2(laser_length / 2, 0)

func update_cone_polygon():
	if not laser_polygon:
		return

	# Create cone shape: narrow at base, wide at tip
	var base_width = laser_width
	var tip_width = laser_width * 3.0  # Cone is 3x wider at the tip

	var points = PackedVector2Array([
		Vector2(0, -base_width / 2),
		Vector2(laser_length, -tip_width / 2),
		Vector2(laser_length, tip_width / 2),
		Vector2(0, base_width / 2)
	])
	laser_polygon.polygon = points

	# Update collision shape for cone mode (use average width)
	if collision_shape and collision_shape.shape is RectangleShape2D:
		var avg_width = (base_width + tip_width) / 2
		collision_shape.shape.size = Vector2(laser_length, avg_width)
		collision_shape.position = Vector2(laser_length / 2, 0)

func _process(delta: float):
	if not is_instance_valid(player):
		return

	# Update laser size in case stats changed
	update_laser_size()

	# DEATH RAY: No tracking (stays fixed)
	# NORMAL/ORBITAL: Track nearest enemy and rotate toward them
	if not death_ray:
		var target = get_nearest_enemy()
		if target:
			var direction = global_position.direction_to(target.global_position)
			rotation = direction.angle()

	# ORBITAL LASERS: Rotate orbital lasers around player
	if orbital_lasers:
		orbital_rotation += delta * ORBITAL_SPEED * TAU  # Full rotation per second
		update_orbital_positions()

	# ADDITIONAL LASERS: Update angles based on main laser rotation
	update_additional_laser_angles()

	# Damage tick
	tick_timer += delta
	if tick_timer >= TICK_INTERVAL:
		tick_timer = 0.0
		damage_enemies_in_beam()

		# Orbital lasers damage separately
		if orbital_lasers:
			damage_orbital_lasers()

		# Additional lasers damage separately
		if additional_lasers.size() > 0:
			damage_additional_lasers()

	# Visual pulsing effect
	queue_redraw()

func _draw():
	# Add glow effect around the laser
	if not cone_mode and laser_line:
		var t = Time.get_ticks_msec() * 0.001
		var pulse = 0.5 + 0.3 * sin(t * 8.0)

		# DEATH RAY: Red/orange color instead of cyan
		if death_ray:
			laser_line.default_color = Color(1.0, 0.4, 0.0, pulse)  # Orange-red
		else:
			laser_line.default_color = Color(0.0, 0.8, 1.0, pulse)  # Cyan

	elif cone_mode and laser_polygon:
		var t = Time.get_ticks_msec() * 0.001
		var pulse = 0.4 + 0.2 * sin(t * 8.0)

		# DEATH RAY: Red/orange color instead of cyan
		if death_ray:
			laser_polygon.color = Color(1.0, 0.4, 0.0, pulse)
		else:
			laser_polygon.color = Color(0.0, 0.8, 1.0, pulse)

func get_nearest_enemy() -> Node2D:
	var closest_target: Node2D = null
	var min_distance: float = 999999.0
	const MAX_TRACK_RANGE: float = 1000.0  # Track enemies up to 1000px away

	# Get all targetable entities
	var mobs: Array[Node] = get_tree().get_nodes_in_group("mob")
	var asteroids: Array[Node] = get_tree().get_nodes_in_group("asteroid")
	var flowers: Array[Node] = get_tree().get_nodes_in_group("flower")
	var all_targets = mobs + asteroids + flowers

	for target in all_targets:
		if is_instance_valid(target) and target is Node2D:
			var distance = global_position.distance_to(target.global_position)
			if distance < min_distance and distance <= MAX_TRACK_RANGE:
				min_distance = distance
				closest_target = target as Node2D

	return closest_target

func damage_enemies_in_beam():
	if not is_instance_valid(player) or stats.is_empty():
		return

	# Clear hit tracking for this tick
	hit_enemies_this_tick.clear()

	# Calculate damage per tick
	var base_damage = stats.get("damage", 5.0)
	var attack_speed = stats.get("attack_speed", 1.0)
	var attack_mult = player.player_stats.get("attack_speed_mult", 1.0)
	var final_attack_speed = attack_speed * attack_mult

	# Damage = base damage * attack speed multiplier * damage multiplier
	var tick_damage = base_damage * player.player_stats.get("damage_mult", 1.0)

	# Get all bodies overlapping the damage area
	if not damage_area:
		return

	var overlapping_bodies = damage_area.get_overlapping_bodies()

	for body in overlapping_bodies:
		if not is_instance_valid(body):
			continue

		# Check if this is a valid target
		if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
			# Check if we already hit this enemy this tick
			var body_id = body.get_instance_id()
			if body_id in hit_enemies_this_tick:
				continue

			hit_enemies_this_tick.append(body_id)

			# Apply damage with crit chance
			var is_crit = false
			var final_damage = tick_damage
			if randf() < player.player_stats.get("crit_chance", 0.0):
				is_crit = true
				final_damage *= player.player_stats.get("crit_damage", 1.5)

			# Apply damage
			if body.has_method("take_damage"):
				body.take_damage(final_damage, false, is_crit)

			# DEATH RAY: Apply burn DOT (20% damage per second for 3 seconds)
			if death_ray and body.has_method("start_dot"):
				body.start_dot("death_ray_burn", tick_damage * 0.2, 3, Color(1.0, 0.4, 0.0))

			# Report damage for lifesteal
			player.report_weapon_damage("laser_beam", final_damage)

func create_orbital_lasers():
	# Create two additional rotating lasers at 50% damage
	orbital_laser_1 = create_single_orbital_laser()
	orbital_laser_2 = create_single_orbital_laser()
	add_child(orbital_laser_1)
	add_child(orbital_laser_2)
	print("🔷 Orbital Lasers activated!")

func create_single_orbital_laser() -> Node2D:
	var orbital = Node2D.new()

	# Create visual line
	var line = Line2D.new()
	line.width = laser_width * 0.7  # Slightly thinner
	line.default_color = Color(0.5, 0.9, 1.0, 0.7)  # Light cyan
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(laser_length * 0.8, 0))  # Slightly shorter
	orbital.add_child(line)

	# Create damage area
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Layer 2 = mobs
	orbital.add_child(area)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(laser_length * 0.8, laser_width * 0.7)
	shape.shape = rect
	shape.position = Vector2(laser_length * 0.4, 0)
	area.add_child(shape)

	return orbital

func update_orbital_positions():
	if not orbital_laser_1 or not orbital_laser_2:
		return

	# Position orbital lasers 180° apart
	var angle1 = orbital_rotation
	var angle2 = orbital_rotation + PI

	orbital_laser_1.position = Vector2(cos(angle1), sin(angle1)) * ORBITAL_DISTANCE
	orbital_laser_1.rotation = angle1

	orbital_laser_2.position = Vector2(cos(angle2), sin(angle2)) * ORBITAL_DISTANCE
	orbital_laser_2.rotation = angle2

func damage_orbital_lasers():
	if not is_instance_valid(player) or stats.is_empty():
		return

	# Calculate damage per tick (50% of main laser)
	var base_damage = stats.get("damage", 5.0) * 0.5
	var tick_damage = base_damage * player.player_stats.get("damage_mult", 1.0)

	# Damage enemies hit by each orbital laser
	for orbital in [orbital_laser_1, orbital_laser_2]:
		if not orbital:
			continue

		var area = orbital.get_node_or_null("Area2D")
		if not area:
			continue

		var overlapping_bodies = area.get_overlapping_bodies()

		for body in overlapping_bodies:
			if not is_instance_valid(body):
				continue

			if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
				var body_id = body.get_instance_id()
				if body_id in hit_enemies_this_tick:
					continue

				hit_enemies_this_tick.append(body_id)

				# Apply damage with crit
				var is_crit = false
				var final_damage = tick_damage
				if randf() < player.player_stats.get("crit_chance", 0.0):
					is_crit = true
					final_damage *= player.player_stats.get("crit_damage", 1.5)

				if body.has_method("take_damage"):
					body.take_damage(final_damage, false, is_crit)

				player.report_weapon_damage("laser_beam", final_damage)


func create_additional_lasers(num_projectiles: int):
	# Create additional lasers spread at angles (like multi-shot)
	# Clear existing additional lasers
	for laser in additional_lasers:
		if is_instance_valid(laser):
			laser.queue_free()
	additional_lasers.clear()

	# Spread angle: 15 degrees per laser
	for i in range(num_projectiles):
		var laser_node = create_single_additional_laser()
		additional_lasers.append(laser_node)
		add_child(laser_node)

	print("✨ Created %d additional laser beams (+projectiles)" % num_projectiles)

func create_single_additional_laser() -> Node2D:
	var laser = Node2D.new()

	# Create visual line
	var line = Line2D.new()
	line.width = laser_width * 0.8  # Slightly thinner than main
	line.default_color = Color(0.3, 0.8, 1.0, 0.7)  # Light cyan
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.add_point(Vector2.ZERO)
	line.add_point(Vector2(laser_length * 0.9, 0))  # Slightly shorter
	laser.add_child(line)

	# Create damage area
	var area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2  # Layer 2 = mobs
	laser.add_child(area)

	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(laser_length * 0.9, laser_width * 0.8)
	shape.shape = rect
	shape.position = Vector2(laser_length * 0.45, 0)
	area.add_child(shape)

	return laser

func update_additional_laser_angles():
	if additional_lasers.is_empty():
		return

	# Spread lasers at angles around main laser
	const SPREAD_ANGLE: float = deg_to_rad(15.0)
	var num_lasers = additional_lasers.size()

	for i in range(num_lasers):
		var laser = additional_lasers[i]
		if not is_instance_valid(laser):
			continue

		# Alternate left and right: -15°, +15°, -30°, +30°, etc.
		var side = 1 if i % 2 == 0 else -1  # Alternate left/right
		var magnitude = int((i + 1) / 2)  # 0, 1, 1, 2, 2, 3, 3...
		var angle_offset = side * SPREAD_ANGLE * magnitude

		laser.rotation = angle_offset

func damage_additional_lasers():
	if not is_instance_valid(player) or stats.is_empty():
		return

	# Calculate damage per tick (80% of main laser)
	var base_damage = stats.get("damage", 5.0) * 0.8
	var tick_damage = base_damage * player.player_stats.get("damage_mult", 1.0)

	# Damage enemies hit by each additional laser
	for laser in additional_lasers:
		if not is_instance_valid(laser):
			continue

		var area = laser.get_node_or_null("Area2D")
		if not area:
			continue

		var overlapping_bodies = area.get_overlapping_bodies()

		for body in overlapping_bodies:
			if not is_instance_valid(body):
				continue

			if body.is_in_group("mob") or body.is_in_group("asteroid") or body.is_in_group("flower"):
				var body_id = body.get_instance_id()
				if body_id in hit_enemies_this_tick:
					continue

				hit_enemies_this_tick.append(body_id)

				# Apply damage with crit
				var is_crit = false
				var final_damage = tick_damage
				if randf() < player.player_stats.get("crit_chance", 0.0):
					is_crit = true
					final_damage *= player.player_stats.get("crit_damage", 1.5)

				if body.has_method("take_damage"):
					body.take_damage(final_damage, false, is_crit)

				player.report_weapon_damage("laser_beam", final_damage)

