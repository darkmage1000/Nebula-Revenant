# OmegaDragon.gd - Epic final boss with three attack patterns
extends "res://mob.gd"

signal health_changed(current_health, max_health)

const DRAGON_FIREBALL_SCENE = preload("res://DragonFireball.gd")
const DRAGON_LASER_SCENE = preload("res://DragonLaser.gd")

# Boss stats (set by main_game.gd based on mode)
var base_damage: float = 50.0

# Attack cooldowns
var fireball_cooldown: float = 2.5
var fireball_timer: float = 0.0

var laser_cooldown: float = 6.0
var laser_timer: float = 0.0

var charge_cooldown: float = 8.0
var charge_timer: float = 0.0

# AI behavior
var desired_distance: float = 350.0  # Kiting range
var is_charging: bool = false
var charge_duration: float = 0.5
var charge_timer_active: float = 0.0
var charge_direction: Vector2 = Vector2.ZERO
var charge_speed_mult: float = 3.0

# Visual effects
var glow_intensity: float = 0.0
var attack_telegraph: bool = false

func _ready():
	super._ready()

	# Override mob defaults
	base_speed = 120
	speed = 120

	# Visual setup - Draw dragon procedurally
	queue_redraw()

	# Start with all cooldowns ready (offset for variety)
	fireball_timer = fireball_cooldown
	laser_timer = laser_cooldown * 0.7
	charge_timer = charge_cooldown * 0.5

func _physics_process(delta):
	if not is_instance_valid(player):
		return

	# Update cooldown timers
	fireball_timer += delta
	laser_timer += delta
	charge_timer += delta

	# Handle charging behavior
	if is_charging:
		handle_charge(delta)
	else:
		handle_normal_movement(delta)

	# Process DOTs (from parent class)
	_process_dots(delta)

	# Emit health changed signal for UI
	health_changed.emit(health, max_health)

	# Update visuals
	queue_redraw()

func handle_normal_movement(delta):
	if not is_instance_valid(player):
		return

	var distance_to_player = global_position.distance_to(player.global_position)
	var direction_to_player = global_position.direction_to(player.global_position)

	# Decide on attack or movement
	var can_attack = false

	# Try attacks in priority order
	if charge_timer >= charge_cooldown and distance_to_player > 250:
		# Charge attack (prefer when player is far)
		execute_charge_attack()
		can_attack = true
	elif laser_timer >= laser_cooldown:
		# Laser attack
		execute_laser_attack()
		can_attack = true
	elif fireball_timer >= fireball_cooldown:
		# Fireball attack
		execute_fireball_attack()
		can_attack = true

	# If no attack, handle movement
	if not can_attack:
		# Kiting behavior - maintain desired distance
		if distance_to_player < desired_distance - 50:
			# Too close, move away
			velocity = -direction_to_player * speed
		elif distance_to_player > desired_distance + 100:
			# Too far, move closer
			velocity = direction_to_player * speed
		else:
			# In ideal range, strafe around player
			var strafe_direction = direction_to_player.rotated(PI / 2)
			velocity = strafe_direction * speed * 0.7

		move_and_slide()

func handle_charge(delta):
	# Move in charge direction at high speed
	charge_timer_active += delta
	velocity = charge_direction * speed * charge_speed_mult
	move_and_slide()

	# Check for player collision during charge
	check_charge_collision()

	# End charge after duration
	if charge_timer_active >= charge_duration:
		is_charging = false
		charge_timer_active = 0.0
		glow_intensity = 0.0

func check_charge_collision():
	# Check if we're overlapping with player
	if not is_instance_valid(player):
		return

	var distance = global_position.distance_to(player.global_position)
	if distance < 50:  # Collision threshold based on scale
		if player.has_method("take_damage"):
			player.take_damage(60.0)
			print("⚡ Omega Dragon charge hit player for 60 damage!")

func execute_fireball_attack():
	if not is_instance_valid(player):
		return

	fireball_timer = 0.0

	# Calculate direction to player
	var direction = global_position.direction_to(player.global_position)

	# Spawn 3-5 fireballs in spread pattern
	var num_fireballs = randi_range(3, 5)
	var spread_angle = 0.4  # Radians

	for i in range(num_fireballs):
		var fireball_scene = DRAGON_FIREBALL_SCENE.new()
		var fireball = Node2D.new()
		fireball.set_script(fireball_scene)

		# Calculate spread
		var angle_offset = 0.0
		if num_fireballs > 1:
			var t = float(i) / float(num_fireballs - 1)  # 0 to 1
			angle_offset = (t - 0.5) * spread_angle

		fireball.direction = direction.rotated(angle_offset)
		fireball.global_position = global_position
		get_parent().add_child(fireball)

	print("🔥 Omega Dragon fired %d fireballs!" % num_fireballs)

func execute_laser_attack():
	if not is_instance_valid(player):
		return

	laser_timer = 0.0

	# Calculate direction to player
	var direction = global_position.direction_to(player.global_position)

	# Spawn laser beam
	var laser_scene = DRAGON_LASER_SCENE.new()
	var laser = Node2D.new()
	laser.set_script(laser_scene)
	laser.beam_direction = direction
	laser.global_position = global_position
	get_parent().add_child(laser)

	print("⚡ Omega Dragon fired laser beam!")

func execute_charge_attack():
	if not is_instance_valid(player):
		return

	charge_timer = 0.0
	is_charging = true
	charge_timer_active = 0.0

	# Calculate charge direction (toward player)
	charge_direction = global_position.direction_to(player.global_position)

	# Visual telegraph
	glow_intensity = 1.0

	print("💨 Omega Dragon charging at player!")

func take_damage(amount: float, is_dot: bool = false, is_crit: bool = false):
	# Call parent damage handling
	super.take_damage(amount, is_dot, is_crit)

	# Flash effect on hit
	if not is_dot:
		glow_intensity = 0.5

	# Emit health changed for UI update
	health_changed.emit(health, max_health)

func _draw():
	# Draw procedural dragon shape
	var base_size = 60.0

	# Body color - red/orange gradient
	var body_color = Color(0.9, 0.3, 0.1)
	if glow_intensity > 0:
		body_color = body_color.lightened(glow_intensity * 0.5)
		glow_intensity = max(0, glow_intensity - 0.05)

	# Main body (ellipse)
	draw_circle(Vector2.ZERO, base_size * 0.8, body_color)

	# Head
	draw_circle(Vector2(base_size * 0.6, 0), base_size * 0.5, body_color.lightened(0.1))

	# Wings (triangles)
	var wing_points_left = PackedVector2Array([
		Vector2(-base_size * 0.3, 0),
		Vector2(-base_size * 1.2, -base_size * 0.8),
		Vector2(-base_size * 0.5, -base_size * 0.3)
	])
	draw_colored_polygon(wing_points_left, body_color.darkened(0.2))

	var wing_points_right = PackedVector2Array([
		Vector2(-base_size * 0.3, 0),
		Vector2(-base_size * 1.2, base_size * 0.8),
		Vector2(-base_size * 0.5, base_size * 0.3)
	])
	draw_colored_polygon(wing_points_right, body_color.darkened(0.2))

	# Tail
	var tail_points = PackedVector2Array([
		Vector2(-base_size * 0.8, 0),
		Vector2(-base_size * 1.5, -base_size * 0.2),
		Vector2(-base_size * 1.8, 0),
		Vector2(-base_size * 1.5, base_size * 0.2)
	])
	draw_colored_polygon(tail_points, body_color.darkened(0.3))

	# Eyes (glowing)
	draw_circle(Vector2(base_size * 0.7, -base_size * 0.2), base_size * 0.15, Color(1, 1, 0))
	draw_circle(Vector2(base_size * 0.7, base_size * 0.2), base_size * 0.15, Color(1, 1, 0))

	# Charge glow effect
	if is_charging:
		draw_circle(Vector2.ZERO, base_size * 1.2, Color(1, 0.8, 0, 0.3))
		draw_circle(Vector2.ZERO, base_size * 1.0, Color(1, 0.6, 0, 0.5))

	# Low health indicator (pulse red when below 25%)
	if health < max_health * 0.25:
		var pulse = sin(Time.get_ticks_msec() * 0.01) * 0.3 + 0.3
		draw_circle(Vector2.ZERO, base_size * 1.1, Color(1, 0, 0, pulse))
