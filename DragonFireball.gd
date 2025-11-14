# DragonFireball.gd - Omega Dragon fireball projectile
extends Area2D

var damage: float = 40.0
var speed: float = 350.0
var direction: Vector2 = Vector2.RIGHT
var lifetime: float = 3.0
var lifetime_timer: float = 0.0

func _ready():
	# Collision setup
	collision_layer = 4  # Bullet layer
	collision_mask = 1   # Player layer

	# Visual setup - Orange/red fireball
	var sprite = Sprite2D.new()
	sprite.texture = create_fireball_texture()
	add_child(sprite)

	# Add glow effect
	var glow = Sprite2D.new()
	glow.texture = create_fireball_texture()
	glow.modulate = Color(1.0, 0.6, 0.2, 0.4)
	glow.scale = Vector2(1.3, 1.3)
	add_child(glow)

	# Collision shape
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	add_child(collision)

	# Connect area entered
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _process(delta):
	# Move forward
	global_position += direction * speed * delta

	# Update lifetime
	lifetime_timer += delta
	if lifetime_timer >= lifetime:
		queue_free()

	# Rotate sprite for visual effect
	if has_node("Sprite2D"):
		get_node("Sprite2D").rotation += delta * 3.0

func _on_area_entered(area):
	# Hit player
	if area.is_in_group("player"):
		hit_player(area)

func _on_body_entered(body):
	# Hit player
	if body.is_in_group("player"):
		hit_player(body)

func hit_player(player_node):
	# Deal damage to player
	if player_node.has_method("take_damage"):
		player_node.take_damage(damage)
		print("🔥 Fireball hit player for %.0f damage!" % damage)

	# Destroy fireball on hit
	queue_free()

func create_fireball_texture() -> ImageTexture:
	var size = 32
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center = Vector2(size / 2, size / 2)

	for x in range(size):
		for y in range(size):
			var pos = Vector2(x, y)
			var dist = pos.distance_to(center)

			if dist <= 15:
				# Create gradient from bright orange center to dark red edges
				var t = dist / 15.0
				var color: Color

				if t < 0.5:
					# Bright yellow-orange core
					color = Color(1.0, 1.0 - t * 0.6, 0.0, 1.0)
				else:
					# Orange to red edges
					color = Color(1.0, 0.4 - (t - 0.5) * 0.4, 0.0, 1.0 - (t - 0.5) * 0.5)

				img.set_pixel(x, y, color)

	return ImageTexture.create_from_image(img)
