# Explosion.gd – SIMPLE EXPLOSION VISUAL
extends Node2D

func _ready():
	# Create multiple expanding circles for explosion effect
	create_explosion_particles()
	
	# Auto-delete after animation
	await get_tree().create_timer(0.5).timeout
	queue_free()

func create_explosion_particles():
	# Create 3 expanding circles
	for i in range(3):
		var circle = Sprite2D.new()
		circle.texture = create_circle_texture(50 + i * 20)
		circle.modulate = Color(1.0, 0.4 + i * 0.1, 0.0, 0.8 - i * 0.2)
		add_child(circle)
		
		# Animate scale and fade
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(circle, "scale", Vector2(2.0, 2.0), 0.4 + i * 0.1)
		tween.tween_property(circle, "modulate:a", 0.0, 0.4 + i * 0.1)

func create_circle_texture(radius: float) -> ImageTexture:
	var size = int(radius * 2)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				# Gradient from center
				var alpha = 1.0 - (dist / radius)
				img.set_pixel(x, y, Color(1.0, 0.5, 0.0, alpha))
	
	return ImageTexture.create_from_image(img)
