# DarkMageProjectile.gd - Blue fireball that damages the player
extends Area2D

var damage: float = 8.0  # Base damage
var speed: float = 300.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 5.0  # Despawn after 5 seconds

func _ready():
	# Set up collision
	collision_layer = 4  # Enemy projectile layer
	collision_mask = 1   # Player layer

	# Create visual - blue fireball
	var sprite = Sprite2D.new()
	sprite.texture = create_fireball_texture(15, Color(0.2, 0.5, 1.0))
	add_child(sprite)

	# Add glow effect
	var glow = Sprite2D.new()
	glow.texture = create_glow_texture(20, Color(0.4, 0.7, 1.0, 0.5))
	glow.z_index = -1
	add_child(glow)

	# Pulse animation for glow
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(glow, "scale", Vector2(1.3, 1.3), 0.4)
	tween.tween_property(glow, "scale", Vector2(1.0, 1.0), 0.4)

	# Create collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	add_child(collision)

	# Connect signals
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _process(delta):
	# Move in direction
	global_position += direction * speed * delta

	# Rotate for visual effect
	rotation += delta * 3.0

	# Lifetime countdown
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player_group") or body.name == "Player":
		# Damage player through collision (player's HurtBox handles this)
		queue_free()

func _on_area_entered(area):
	# Destroy on hitting asteroids or other obstacles
	if area.is_in_group("asteroid"):
		queue_free()

func create_fireball_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2.5)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				# Gradient from bright center to darker edge
				var brightness = 1.0 - (dist / radius) * 0.4
				var final_color = Color(
					color.r * brightness,
					color.g * brightness,
					color.b * brightness,
					color.a
				)
				img.set_pixel(x, y, final_color)

	return ImageTexture.create_from_image(img)

func create_glow_texture(radius: float, color: Color) -> ImageTexture:
	var size = int(radius * 2.5)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				# Soft gradient glow
				var alpha = (1.0 - (dist / radius)) * color.a
				var glow_color = Color(color.r, color.g, color.b, alpha)
				img.set_pixel(x, y, glow_color)

	return ImageTexture.create_from_image(img)
