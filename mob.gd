# mob.gd – FIXED: 20 HP = 2 PISTOL SHOTS TO KILL
extends CharacterBody2D

signal died

const XP_VIAL_SCENE = preload("res://experience_vial.tscn")
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")
const POISON_COLOR = Color(0.0, 0.8, 0.2)
const AURA_COLOR = Color(0.1, 0.6, 1.0)
const CRIT_COLOR = Color(1.0, 0.5, 0.0)
const WEAPON_COLOR = Color(1.0, 1.0, 0.0)

# BALANCED BASE STATS - 2 shots to kill with starting pistol (12 damage)
var base_speed = 150
var base_health: float = 20.0
var speed: float = 150
var health: float = 20.0
var max_health: float = 20.0
var xp_value: int = 10
var level_scaling_applied: bool = false
var is_colossus: bool = false  # Special flag for tanky enemy

var active_dots: Dictionary = {}

@onready var player = get_node("/root/MainGame/Player")

func _ready():
	add_to_group("mob")  # Important for grenades to find enemies!
	
	# Check if this is a Nebulith Colossus by node name
	if name.begins_with("NebulithColossus") or get_node_or_null("ColossusSprite"):
		is_colossus = true
		# Colossus has 3x health, slower speed, more XP
		base_health = 60.0  # 3x tankier
		base_speed = 100   # Slower
		health = base_health
		speed = base_speed
		xp_value = 30  # 3x XP reward
	
	apply_level_scaling()
	max_health = health

func apply_level_scaling():
	if level_scaling_applied or not is_instance_valid(player):
		return
	
	var player_level = player.player_stats.get("level", 1)
	
	# PHASE 3: MUCH SLOWER enemy scaling to match XP changes
	# Health scales: +4% per level (was +8%)
	# Speed scales: +1% per level (was +2%)
	# XP scales: +3% per level (was +5%)
	
	var level_mult = player_level - 1  # No scaling at level 1
	
	# Health: Moderate exponential growth
	health = base_health * pow(1.04, level_mult)
	max_health = health
	
	# Speed: Very slow linear growth
	speed = base_speed * (1.0 + (level_mult * 0.01))
	speed += randf_range(-20, 20)  # Add some variation
	
	# XP: Scales slower with level
	xp_value = int(10 * (1.0 + (level_mult * 0.03)))
	
	level_scaling_applied = true
	
	if player_level > 10:
		print("Mob spawned at player level %d: HP=%.1f Speed=%.1f XP=%d" % [player_level, health, speed, xp_value])

func _physics_process(delta):
	if not is_instance_valid(player):
		return
		
	var direction = global_position.direction_to(player.global_position)
	direction += Vector2(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	
	velocity = direction.normalized() * speed
	move_and_slide()
	
	_process_dots(delta)

func _process_dots(delta):
	var dots_to_remove = []
	
	for source_key in active_dots:
		var dot_data = active_dots[source_key]
		dot_data.tick_timer += delta
		
		take_damage(dot_data.damage_per_sec * delta, true)
		
		if dot_data.tick_timer >= 1.0:
			show_damage_number(dot_data.damage_per_sec, dot_data.color)
			
			if dot_data.ticks_remaining > 0:
				dot_data.ticks_remaining -= 1
				if dot_data.ticks_remaining == 0:
					dots_to_remove.append(source_key)
			dot_data.tick_timer = 0.0
	
	for key in dots_to_remove:
		active_dots.erase(key)

func take_damage(amount: float, is_dot: bool = false, is_crit: bool = false):
	health -= amount 
	
	if not is_dot:
		var color = WEAPON_COLOR
		if is_crit:
			color = CRIT_COLOR
		show_damage_number(amount, color)
	
	if health <= 0:
		died.emit()
		
		# PHASE 3: Track kill for player stats
		if is_instance_valid(player) and player.has_method("register_kill"):
			player.register_kill()
		
		# Drop XP vial
		var vial = XP_VIAL_SCENE.instantiate()
		vial.global_position = global_position
		vial.value = xp_value
		get_parent().add_child(vial)

		# 10% chance to drop something (shards, health pack, or powerup)
		if randf() < 0.10:
			var drop_roll = randf()
			var drop_pos = global_position + Vector2(randf_range(-20, 20), randf_range(-20, 20))

			if drop_roll < 0.75:
				# Drop shards (75% of drops = 7.5% overall) - INCREASED!
				var shard_value = 1
				if randf() < 0.1:  # 10% chance for bonus shard
					shard_value = randi_range(2, 5)

				if ResourceLoader.exists("res://NebulaShard.tscn"):
					var shard_scene = ResourceLoader.load("res://NebulaShard.tscn", "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
					if shard_scene:
						var shard = shard_scene.instantiate()
						if shard:
							if shard.has_method("set") and "value" in shard:
								shard.value = shard_value
							shard.global_position = drop_pos
							get_parent().add_child(shard)

			elif drop_roll < 0.85:
				# Drop health pack (10% of drops = 1% overall) - LOWEST! Was 3.3%
				spawn_healthpack(drop_pos)

			else:
				# Drop powerup (15% of drops = 1.5% overall) - NERFED! Was 3.3%
				spawn_powerup(drop_pos)

		queue_free()

func start_dot(source_key: String, damage_per_sec: float, num_ticks: int, color: Color):
	if damage_per_sec <= 0: return
	
	if active_dots.has(source_key):
		active_dots[source_key].ticks_remaining += num_ticks
	else:
		active_dots[source_key] = {
			"damage_per_sec": damage_per_sec,
			"ticks_remaining": num_ticks,
			"tick_timer": 0.0,
			"color": color
		}

func stop_dot(source_key: String):
	active_dots.erase(source_key)

func show_damage_number(amount: float, color: Color):
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
			var screen_pos = canvas_transform * global_position
			dmg.global_position = screen_pos
	else:
		get_parent().add_child(dmg)
		dmg.global_position = global_position

	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(amount, color)

func apply_knockback(knockback_amount: float, source_position: Vector2):
	if knockback_amount <= 0.0:
		return

	var direction = global_position.direction_to(source_position).normalized()
	const KNOCKBACK_PUSH_VELOCITY = 1500.0
	velocity = direction * -1.0 * (knockback_amount / 50.0) * KNOCKBACK_PUSH_VELOCITY

func spawn_healthpack(pos: Vector2):
	# Create health pack at drop position
	var healthpack = Area2D.new()
	healthpack.global_position = pos
	healthpack.add_to_group("healthpack")
	healthpack.collision_layer = 8
	healthpack.collision_mask = 4

	# Visual - Green plus sign
	var sprite = Sprite2D.new()
	sprite.texture = create_plus_texture(25, Color(0, 1, 0, 1))
	healthpack.add_child(sprite)

	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25
	collision.shape = shape
	healthpack.add_child(collision)

	get_parent().add_child(healthpack)

func spawn_powerup(pos: Vector2):
	# Randomly choose powerup type
	var powerup_types = ["invincible", "magnet", "attack_speed", "nuke"]
	var powerup_type = powerup_types[randi() % powerup_types.size()]

	# Create powerup
	var powerup = Area2D.new()
	powerup.global_position = pos
	powerup.add_to_group("powerup")
	powerup.set_meta("powerup_type", powerup_type)
	powerup.collision_layer = 8
	powerup.collision_mask = 4

	# Visual based on type
	var color = Color(1, 1, 0, 1)
	match powerup_type:
		"invincible":
			color = Color(1, 1, 0, 1)
		"magnet":
			color = Color(0, 1, 1, 1)
		"attack_speed":
			color = Color(1, 0, 1, 1)
		"nuke":
			color = Color(1, 0.5, 0, 1)

	var sprite = Sprite2D.new()
	sprite.texture = create_star_texture(30, color)
	powerup.add_child(sprite)

	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 30
	collision.shape = shape
	powerup.add_child(collision)

	get_parent().add_child(powerup)

func create_plus_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2.5)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)
	var thickness = radius * 0.4

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			if abs(pos.x - center.x) <= thickness or abs(pos.y - center.y) <= thickness:
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)

func create_star_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 3)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y) - center
			var angle = pos.angle()
			var dist = pos.length()

			# Create 5-pointed star
			var star_radius = radius
			for i in range(5):
				var point_angle = (i * TAU / 5.0) - PI/2
				var angle_diff = abs(angle - point_angle)
				if angle_diff > PI:
					angle_diff = TAU - angle_diff

				if angle_diff < 0.6 and dist <= star_radius * 1.3:
					img.set_pixel(x, y, color)
					break

			# Fill center
			if dist <= radius * 0.5:
				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
