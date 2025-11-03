# GrenadeProjectile.gd – COMPLETE: FLIES + EXPLODES + DAMAGES
extends Area2D

var damage: float = 50.0
var aoe: float = 100.0
var distance: float = 300.0
var speed: float = 400.0
var pierce: int = 0
var knockback_amount: float = 0.0
var aoe_mult: float = 1.0

var poison_enabled: bool = false
var poison_damage: float = 0.0
var burn_enabled: bool = false
var burn_damage: float = 0.0

var player: CharacterBody2D = null
var traveled_distance: float = 0.0
var velocity: Vector2 = Vector2.ZERO

# Explosion visual
const EXPLOSION_SCENE = preload("res://Explosion.tscn")  # We'll create this
var has_exploded: bool = false

func _ready():
	# Set velocity based on rotation
	velocity = Vector2.RIGHT.rotated(rotation) * speed
	
	# Visual indicator (optional - you can customize)
	if has_node("Sprite2D"):
		$Sprite2D.modulate = Color(1.0, 0.5, 0.0)  # Orange grenade

func _physics_process(delta: float):
	if has_exploded:
		return
		
	# Move grenade
	var movement = velocity * delta
	position += movement
	traveled_distance += movement.length()
	
	# Explode when distance reached
	if traveled_distance >= distance:
		explode()

func _on_body_entered(body: Node2D):
	# Explode on contact with enemy
	if body.is_in_group("mob") and not has_exploded:
		explode()

func explode():
	if has_exploded:
		return
	has_exploded = true
	
	# Create explosion visual
	spawn_explosion_effect()
	
	# Find all enemies in AOE
	var final_aoe = aoe * aoe_mult
	var enemies_in_range = get_tree().get_nodes_in_group("mob")
	
	for enemy in enemies_in_range:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			
			if dist <= final_aoe:
				# Apply damage
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
				
				# Apply knockback
				if knockback_amount > 0 and enemy.has_method("apply_knockback"):
					enemy.apply_knockback(knockback_amount, global_position)
				
				# Apply poison
				if poison_enabled and poison_damage > 0 and enemy.has_method("start_dot"):
					enemy.start_dot("grenade_poison", poison_damage * 0.2, 5, Color(0.0, 0.8, 0.2))
				
				# Apply burn
				if burn_enabled and burn_damage > 0 and enemy.has_method("start_dot"):
					enemy.start_dot("grenade_burn", burn_damage * 0.3, 3, Color(1.0, 0.4, 0.0))
	
	# Remove grenade
	queue_free()

func spawn_explosion_effect():
	# Always use simple explosion for reliable visual feedback
	create_simple_explosion()

func create_simple_explosion():
	# Create a simple visual explosion effect
	var explosion = Node2D.new()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	
	# Calculate final AOE size
	var final_aoe = aoe * aoe_mult
	
	# Create multiple expanding circles for better visual
	for i in range(3):
		var sprite = Sprite2D.new()
		var circle_size = final_aoe * (0.8 + i * 0.15)  # Different sizes
		var circle_texture = create_circle_texture(circle_size)
		sprite.texture = circle_texture
		sprite.modulate = Color(1.0, 0.5 - i * 0.1, 0.0, 0.8 - i * 0.2)  # Orange gradient
		explosion.add_child(sprite)
		
		# Animate each circle
		var tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(sprite, "scale", Vector2(1.5, 1.5), 0.3 + i * 0.05)
		tween.tween_property(sprite, "modulate:a", 0.0, 0.3 + i * 0.05)
	
	# Delete explosion after animation completes
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

func create_circle_texture(radius: float) -> ImageTexture:
	var size = int(radius * 2)
	var img = Image.create(size, size, false, Image.FORMAT_RGBA8)
	
	var center = Vector2(size / 2, size / 2)
	
	for x in range(size):
		for y in range(size):
			var dist = Vector2(x, y).distance_to(center)
			if dist <= radius:
				var alpha = 1.0 - (dist / radius) * 0.5
				img.set_pixel(x, y, Color(1.0, 0.5, 0.0, alpha))
	
	return ImageTexture.create_from_image(img)
