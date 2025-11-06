# Asteroid.gd - Destructible space rocks with loot!
extends Area2D

signal destroyed

var health: float = 30.0
var max_health: float = 30.0

# Drop chances
const DROP_SHARD_CHANCE = 1.0  # 100% drop shards
const DROP_POWERUP_CHANCE = 0.25  # 25% drop powerup
const DROP_HEALTHPACK_CHANCE = 0.35  # 35% drop health pack

# Try to preload scenes (may not exist)
var NEBULA_SHARD_SCENE = null
const FLOATING_DMG_SCENE = preload("res://FloatingDmg.tscn")

var rotation_speed: float = 0.0

func _ready():
	add_to_group("asteroid")
	collision_layer = 8  # Layer 4 for asteroids
	collision_mask = 0  # Don't collide with anything physically
	
	# Try to load shard scene
	if ResourceLoader.exists("res://NebulaShard.tscn"):
		NEBULA_SHARD_SCENE = load("res://NebulaShard.tscn")
	
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
	var random_scale = randf_range(0.8, 1.3)
	scale = Vector2(random_scale, random_scale)
	health *= random_scale  # Bigger asteroids = more HP
	max_health = health

func _process(delta):
	rotation += rotation_speed * delta

func take_damage(amount: float, _is_dot: bool = false, _is_crit: bool = false):
	health -= amount
	
	# Show damage number
	show_damage_number(amount)
	
	# Visual feedback - flash white
	modulate = Color(1.5, 1.5, 1.5, 1)
	await get_tree().create_timer(0.1).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)
	
	if health <= 0:
		explode()

func show_damage_number(amount: float):
	if not FLOATING_DMG_SCENE:
		return
		
	var dmg = FLOATING_DMG_SCENE.instantiate()
	var ui_layer = get_tree().root.get_node_or_null("MainGame/UILayer")
	if ui_layer:
		ui_layer.add_child(dmg)
	else:
		get_parent().add_child(dmg)
	
	dmg.global_position = global_position
	if dmg.has_method("set_damage_text"):
		dmg.set_damage_text(amount, Color(0.8, 0.8, 0.8))

func explode():
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
	
	# Always drop shards (1-3) if scene exists
	if randf() < DROP_SHARD_CHANCE and NEBULA_SHARD_SCENE:
		var shard_count = randi_range(1, 3)
		for i in range(shard_count):
			var shard = NEBULA_SHARD_SCENE.instantiate()
			var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
			shard.global_position = drop_position + offset
			if shard.has_method("set") and "value" in shard:
				shard.value = 1
			get_parent().add_child(shard)
	elif randf() < DROP_SHARD_CHANCE:
		# If no shard scene, give currency directly to player
		var player = get_tree().get_first_node_in_group("player_group")
		if player and player.has_method("collect_currency"):
			player.collect_currency(randi_range(1, 3))
	
	# 35% chance for health pack
	if randf() < DROP_HEALTHPACK_CHANCE:
		spawn_healthpack(drop_position)
	
	# 25% chance for powerup (only if no health pack)
	elif randf() < DROP_POWERUP_CHANCE:
		spawn_powerup(drop_position)

func spawn_healthpack(pos: Vector2):
	# Create health pack scene
	if not ResourceLoader.exists("res://HealthPack.tscn"):
		# Create simple health pack if scene doesn't exist
		var healthpack = Area2D.new()
		healthpack.global_position = pos
		healthpack.add_to_group("healthpack")
		
		# Visual
		var sprite = Sprite2D.new()
		var circle = create_circle_texture(20, Color(0, 1, 0, 1))
		sprite.texture = circle
		healthpack.add_child(sprite)
		
		# Collision
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 20
		collision.shape = shape
		healthpack.add_child(collision)
		
		get_parent().add_child(healthpack)
	else:
		var healthpack_scene = load("res://HealthPack.tscn")
		var healthpack = healthpack_scene.instantiate()
		healthpack.global_position = pos
		get_parent().add_child(healthpack)

func spawn_powerup(pos: Vector2):
	# Randomly choose powerup type
	var powerup_types = ["invincible", "magnet", "attack_speed", "nuke"]
	var powerup_type = powerup_types[randi() % powerup_types.size()]
	
	# Create powerup scene
	if not ResourceLoader.exists("res://Powerup.tscn"):
		# Create simple powerup if scene doesn't exist
		var powerup = Area2D.new()
		powerup.global_position = pos
		powerup.add_to_group("powerup")
		powerup.set_meta("powerup_type", powerup_type)
		
		# Visual based on type
		var color = Color(1, 1, 0, 1)  # Default yellow
		match powerup_type:
			"invincible":
				color = Color(1, 1, 0, 1)  # Yellow
			"magnet":
				color = Color(0, 1, 1, 1)  # Cyan
			"attack_speed":
				color = Color(1, 0, 1, 1)  # Magenta
			"nuke":
				color = Color(1, 0.5, 0, 1)  # Orange
		
		var sprite = Sprite2D.new()
		var circle = create_circle_texture(25, color)
		sprite.texture = circle
		powerup.add_child(sprite)
		
		# Collision
		var collision = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 25
		collision.shape = shape
		powerup.add_child(collision)
		
		get_parent().add_child(powerup)
	else:
		var powerup_scene = load("res://Powerup.tscn")
		var powerup = powerup_scene.instantiate()
		powerup.global_position = pos
		powerup.powerup_type = powerup_type
		get_parent().add_child(powerup)

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
	# Create a rocky-looking asteroid texture
	var size = 80
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	var base_color = Color(0.5, 0.4, 0.3, 1)  # Brown/gray rock
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= 35:  # Irregular shape
				# Add some texture variation
				var noise = randf_range(0.8, 1.2)
				var color = Color(
					base_color.r * noise,
					base_color.g * noise,
					base_color.b * noise,
					1.0
				)
				img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)
