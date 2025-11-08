# Asteroid.gd - Destructible space rocks with GUARANTEED powerup drops!
extends Area2D

signal destroyed

var health: float = 15.0
var max_health: float = 15.0

# Drop chances (mutually exclusive)
const DROP_SHARD_CHANCE = 0.80  # 80% drop shards
const DROP_HEALTHPACK_CHANCE = 0.05  # 5% drop health pack
const DROP_POWERUP_CHANCE = 0.15  # 15% drop powerup (INCREASED from 8%)

# Preload scenes
var NEBULA_SHARD_SCENE = null
var POWERUP_SCENE = null

var rotation_speed: float = 0.0

func _ready():
	add_to_group("asteroid")
	collision_layer = 8
	collision_mask = 1
	
	# Try to load scenes
	if ResourceLoader.exists("res://NebulaShard.tscn"):
		NEBULA_SHARD_SCENE = load("res://NebulaShard.tscn")
		print("✅ NebulaShard scene loaded")
	else:
		print("❌ NebulaShard scene not found")
	
	if ResourceLoader.exists("res://Powerup.tscn"):
		POWERUP_SCENE = load("res://Powerup.tscn")
		print("✅ Powerup scene loaded")
	else:
		print("❌ Powerup scene not found")
	
	# Create visual sprite if doesn't exist
	if not has_node("Sprite2D"):
		var sprite = Sprite2D.new()
		var texture = create_asteroid_texture()
		sprite.texture = texture
		sprite.name = "Sprite2D"
		add_child(sprite)
	
	# Random rotation
	rotation_speed = randf_range(-0.5, 0.5)
	
	# Random scale for variety
	var random_scale = randf_range(0.6, 0.9)
	scale = Vector2(random_scale, random_scale)
	health *= random_scale
	max_health = health

func _process(delta):
	rotation += rotation_speed * delta

func take_damage(amount: float, _is_dot: bool = false, _is_crit: bool = false):
	health -= amount

	# Visual feedback - flash white
	modulate = Color(1.5, 1.5, 1.5, 1)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

	if health <= 0:
		explode()

func explode():
	print("💥 Asteroid exploding at position: ", global_position)
	
	# Drop loot
	spawn_drops()
	
	# Visual explosion effect
	create_explosion_particles()
	
	# Emit signal
	destroyed.emit()
	
	# Remove asteroid
	queue_free()

func spawn_drops():
	var drop_position = global_position

	# Roll for drop type
	var roll = randf()
	print("🎲 Drop roll: %.2f" % roll)

	if roll < DROP_SHARD_CHANCE:
		# 80% chance for shards
		print("💎 Spawning shards...")
		if NEBULA_SHARD_SCENE:
			var shard_count = randi_range(1, 4)
			for i in range(shard_count):
				var shard = NEBULA_SHARD_SCENE.instantiate()
				var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
				shard.global_position = drop_position + offset
				if shard.has_method("set") and "value" in shard:
					shard.value = 1
				get_parent().add_child(shard)
			print("✅ Spawned %d shards" % shard_count)

	elif roll < DROP_SHARD_CHANCE + DROP_HEALTHPACK_CHANCE:
		# 5% chance for health pack
		print("❤️ Spawning health pack...")
		spawn_healthpack(drop_position)

	else:
		# 15% chance for powerup
		print("⭐ Spawning POWERUP!")
		spawn_powerup(drop_position)

func spawn_healthpack(pos: Vector2):
	# Create simple health pack
	var healthpack = Area2D.new()
	healthpack.global_position = pos
	healthpack.add_to_group("healthpack")
	healthpack.collision_layer = 8
	healthpack.collision_mask = 4
	
	# Visual - Green plus sign
	var sprite = Sprite2D.new()
	var plus_texture = create_plus_texture(25, Color(0, 1, 0, 1))
	sprite.texture = plus_texture
	healthpack.add_child(sprite)
	
	# Collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 25
	collision.shape = shape
	healthpack.add_child(collision)
	
	# Add floating animation
	add_floating_animation(healthpack)
	
	get_parent().add_child(healthpack)
	print("✅ Health pack spawned!")

func spawn_powerup(pos: Vector2):
	print("⭐ spawn_powerup() called at position: ", pos)
	
	# Randomly choose powerup type
	var powerup_types = ["invincible", "magnet", "attack_speed", "nuke"]
	var powerup_type = powerup_types[randi() % powerup_types.size()]
	print("   Selected type: ", powerup_type)
	
	if POWERUP_SCENE:
		print("   ✅ Using Powerup.tscn")
		var powerup = POWERUP_SCENE.instantiate()
		powerup.global_position = pos
		powerup.powerup_type = powerup_type
		get_parent().add_child(powerup)
		print("   ✅ Powerup spawned successfully!")
	else:
		print("   ⚠️ No Powerup.tscn, creating fallback powerup")
		# Create fallback powerup if scene doesn't exist
		var powerup = Area2D.new()
		powerup.global_position = pos
		powerup.add_to_group("powerup")
		powerup.set_meta("powerup_type", powerup_type)
		powerup.collision_layer = 8
		powerup.collision_mask = 4
		
		# Visual based on type
		var color = Color(1, 1, 0, 1)
		var size = 30
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
		var star_texture = create_star_texture(size, color)
		sprite.texture = star_texture
		powerup.add_child(sprite)
		
		# Add glow effect
		var glow = Sprite2D.new()
		glow.texture = create_circle_texture(size + 10, Color(color.r, color.g, color.b, 0.3))
		glow.z_index = -1
		powerup.add_child(glow)
		
		# Collision
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = size
		collision.shape = shape
		powerup.add_child(collision)
		
		# Add floating animation
		add_floating_animation(powerup)
		add_pulse_animation(glow)
		
		get_parent().add_child(powerup)
		print("   ✅ Fallback powerup created!")

func create_explosion_particles():
	# Simple particle explosion
	for i in range(8):
		var particle = Node2D.new()
		particle.global_position = global_position
		get_parent().add_child(particle)
		
		var angle = (i / 8.0) * TAU
		var velocity = Vector2(cos(angle), sin(angle)) * 150
		
		var tween = create_tween()
		tween.tween_property(particle, "position", particle.position + velocity, 0.5)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.5)
		tween.tween_callback(particle.queue_free)

func create_circle_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

func create_asteroid_texture() -> ImageTexture:
	var size = 80
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var base_color = Color(0.5, 0.4, 0.3, 1)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= 35:
				var noise = randf_range(0.8, 1.2)
				var color = Color(
					base_color.r * noise,
					base_color.g * noise,
					base_color.b * noise,
					1.0
				)
				img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)

func create_plus_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2.5)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var thickness = radius * 0.4
	
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			if abs(pos.x - center.x) <= thickness:
				img.set_pixel(x, y, color)
			elif abs(pos.y - center.y) <= thickness:
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

func add_floating_animation(node: Node2D):
	var script_text = """
extends Node2D
var time = 0.0
var start_y = 0.0
var float_speed = 2.0
var float_amount = 15.0

func _ready():
	start_y = global_position.y

func _process(delta):
	time += delta * float_speed
	global_position.y = start_y + sin(time) * float_amount
"""
	var script = GDScript.new()
	script.source_code = script_text
	script.reload()
	node.set_script(script)

func add_pulse_animation(sprite: Sprite2D):
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.8)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.8)
