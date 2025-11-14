# Flower.gd - Destructible flowers for grassy field map (replaces asteroids)
extends Area2D

signal destroyed

var health: float = 15.0
var max_health: float = 15.0

# Drop chances (mutually exclusive) - same as asteroids
const DROP_SHARD_CHANCE = 0.30  # 30% drop shards (further reduced for slower progression)
const DROP_HEALTHPACK_CHANCE = 0.10  # 10% drop health pack
const DROP_POWERUP_CHANCE = 0.60  # 60% drop powerup

# Preload scenes
const NEBULA_SHARD_SCENE = preload("res://NebulaShard.tscn")
const POWERUP_SCENE = preload("res://Powerup.tscn")

# Flower colors
var flower_colors = [
	Color(1.0, 0.2, 0.2),  # Red
	Color(1.0, 0.9, 0.2),  # Yellow
	Color(0.8, 0.5, 1.0),  # Purple
	Color(1.0, 0.5, 0.7),  # Pink
	Color(1.0, 0.6, 0.2),  # Orange
	Color(1.0, 1.0, 1.0),  # White
]

var sway_speed: float = 0.0
var sway_amount: float = 0.0
var time: float = 0.0

func _ready():
	add_to_group("flower")
	collision_layer = 8
	collision_mask = 1

	# Create visual sprite if doesn't exist
	if not has_node("Sprite2D"):
		var sprite = Sprite2D.new()
		var flower_color = flower_colors[randi() % flower_colors.size()]
		var texture = create_flower_texture(flower_color)
		sprite.texture = texture
		sprite.name = "Sprite2D"
		add_child(sprite)

	# Gentle swaying motion
	sway_speed = randf_range(1.5, 2.5)
	sway_amount = randf_range(0.05, 0.15)

	# Random scale for variety
	var random_scale = randf_range(0.7, 1.0)
	scale = Vector2(random_scale, random_scale)
	health *= random_scale
	max_health = health

func _process(delta):
	time += delta * sway_speed
	rotation = sin(time) * sway_amount

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
	print("🌸 Flower destroyed at position: ", global_position)

	# Drop loot
	spawn_drops()

	# Visual petal scatter effect
	create_petal_particles()

	# Emit signal
	destroyed.emit()

	# Remove flower
	queue_free()

func spawn_drops():
	var drop_position = global_position

	# Roll for drop type
	var roll = randf()

	if roll < DROP_SHARD_CHANCE:
		# 50% chance for shards (reduced for slower progression)
		var shard_count = randi_range(1, 2)  # Reduced from 1-4 to 1-2
		for i in range(shard_count):
			var shard = NEBULA_SHARD_SCENE.instantiate()
			var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
			shard.global_position = drop_position + offset
			shard.value = 1
			get_parent().add_child(shard)

	elif roll < DROP_SHARD_CHANCE + DROP_HEALTHPACK_CHANCE:
		# 10% chance for health pack
		spawn_healthpack(drop_position)

	else:
		# 40% chance for powerup
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

	get_parent().add_child(healthpack)

func spawn_powerup(pos: Vector2):
	# Randomly choose powerup type
	var powerup_types = ["invincible", "magnet", "attack_speed", "nuke"]
	var powerup_type = powerup_types[randi() % powerup_types.size()]

	var powerup = POWERUP_SCENE.instantiate()
	powerup.global_position = pos
	powerup.powerup_type = powerup_type
	get_parent().add_child(powerup)

func create_petal_particles():
	# Scatter colorful petals
	for i in range(6):
		var particle = Sprite2D.new()
		particle.texture = create_petal_texture()
		particle.global_position = global_position
		particle.modulate = flower_colors[randi() % flower_colors.size()]
		get_parent().add_child(particle)

		var angle = (i / 6.0) * TAU
		var velocity = Vector2(cos(angle), sin(angle)) * 100

		var tween = create_tween()
		tween.tween_property(particle, "position", particle.position + velocity, 0.6)
		tween.parallel().tween_property(particle, "rotation", randf_range(-PI, PI), 0.6)
		tween.parallel().tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_callback(particle.queue_free)

func create_flower_texture(petal_color: Color) -> ImageTexture:
	var size = 100
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)

	var center = Vector2(size / 2, size / 2)

	# Draw 6 petals around the center
	for petal in range(6):
		var angle = (petal * TAU / 6.0)
		var petal_center = center + Vector2(cos(angle), sin(angle)) * 20

		# Draw petal (oval shape)
		for x in range(size):
			for y in range(size):
				var pos = Vector2(x, y)
				var dist_to_petal = pos.distance_to(petal_center)

				if dist_to_petal <= 15:
					img.set_pixel(x, y, petal_color)

	# Draw center (yellow/orange)
	var center_color = Color(0.9, 0.7, 0.2, 1.0)
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= 12:
				img.set_pixel(x, y, center_color)

	# Draw stem (green line at bottom)
	var stem_color = Color(0.2, 0.6, 0.2, 1.0)
	for y in range(int(center.y), size):
		for x in range(int(center.x - 3), int(center.x + 3)):
			if x >= 0 and x < size and y >= 0 and y < size:
				img.set_pixel(x, y, stem_color)

	return ImageTexture.create_from_image(img)

func create_petal_texture() -> ImageTexture:
	var size = 20
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)

	var center = Vector2(size / 2, size / 2)
	var color = Color(1, 1, 1, 1)

	# Draw small oval petal
	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)
			if dist <= 8:
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
