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

# Evolution flags
var cluster_bomb: bool = false
var sticky_mine: bool = false

var player: CharacterBody2D = null
var traveled_distance: float = 0.0
var velocity: Vector2 = Vector2.ZERO

# Sticky mine tracking
var is_stuck: bool = false
var detection_radius: float = 120.0

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

	# Sticky mines: stop and wait for enemies after reaching max distance
	if sticky_mine and is_stuck:
		check_for_nearby_enemies()
		return

	# Move grenade
	var movement = velocity * delta
	position += movement
	traveled_distance += movement.length()

	# Explode when distance reached
	if traveled_distance >= distance:
		if sticky_mine:
			# Stick to ground and wait
			is_stuck = true
			velocity = Vector2.ZERO
			if has_node("Sprite2D"):
				$Sprite2D.modulate = Color(1.0, 0.2, 0.2)  # Red to show armed
		else:
			explode()

func _on_body_entered(body: Node2D):
	# Explode on contact with enemy (unless it's a sticky mine that needs to arm first)
	if body.is_in_group("mob") and not has_exploded and not (sticky_mine and not is_stuck):
		explode()

func check_for_nearby_enemies():
	# Sticky mine: explode when enemy gets close
	var enemies = get_tree().get_nodes_in_group("mob")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= detection_radius:
				explode()
				return

func explode():
	if has_exploded:
		return
	has_exploded = true

	# CLUSTER BOMB: Spawn 3 mini-grenades before exploding
	if cluster_bomb:
		spawn_cluster_grenades()

	# Create explosion visual
	spawn_explosion_effect()

	# Find all enemies in AOE
	var final_aoe = aoe * aoe_mult
	var enemies_in_range = get_tree().get_nodes_in_group("mob")

	for enemy in enemies_in_range:
		if is_instance_valid(enemy) and enemy is Node2D:
			var dist = global_position.distance_to(enemy.global_position)

			# Account for enemy scale - larger enemies (like bosses) get larger hit radius
			var avg_scale = (enemy.scale.x + enemy.scale.y) / 2.0
			var enemy_scale_bonus = avg_scale * 30.0  # Add 30 pixels per scale unit

			if dist <= (final_aoe + enemy_scale_bonus):
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
	
	# Also damage obstacles (asteroids and flowers) in range!
	var asteroids_in_range = get_tree().get_nodes_in_group("asteroid")
	var flowers_in_range = get_tree().get_nodes_in_group("flower")
	var obstacles = asteroids_in_range + flowers_in_range

	for obstacle in obstacles:
		if is_instance_valid(obstacle) and obstacle is Node2D:
			var dist = global_position.distance_to(obstacle.global_position)

			# Account for obstacle scale
			var avg_scale = (obstacle.scale.x + obstacle.scale.y) / 2.0
			var obstacle_scale_bonus = avg_scale * 30.0

			if dist <= (final_aoe + obstacle_scale_bonus) and obstacle.has_method("take_damage"):
				obstacle.take_damage(damage)
	
	# Remove grenade
	queue_free()

func spawn_explosion_effect():
	# Always use simple explosion for reliable visual feedback
	create_simple_explosion()

# OPTIMIZED explosion - uses simple ColorRect instead of textures
func create_simple_explosion():
	# Use lightweight ColorRect circles instead of image textures for better FPS
	var explosion = Node2D.new()
	explosion.global_position = global_position
	get_parent().add_child(explosion)
	
	# Calculate final AOE size
	var final_aoe = aoe * aoe_mult
	
	# Create 2 circles only (was 3) for better performance
	for i in range(2):
		# Use canvas drawing instead of sprites
		var circle_drawer = Node2D.new()
		explosion.add_child(circle_drawer)
		
		var circle_size = final_aoe * (1.0 + i * 0.2)
		var circle_color = Color(1.0, 0.5 - i * 0.1, 0.0, 0.7 - i * 0.2)
		
		# Draw circle using custom draw function
		circle_drawer.draw.connect(func():
			circle_drawer.draw_circle(Vector2.ZERO, circle_size, circle_color)
		)
		circle_drawer.queue_redraw()
		
		# Simple scale animation
		var tween = create_tween()
		tween.tween_property(circle_drawer, "scale", Vector2(1.3, 1.3), 0.25)
		tween.parallel().tween_property(circle_drawer, "modulate:a", 0.0, 0.25)
	
	# Delete explosion quickly
	get_tree().create_timer(0.3).timeout.connect(func():
		if is_instance_valid(explosion):
			explosion.queue_free()
	)

func spawn_cluster_grenades():
	# Spawn 3 mini-grenades in 120° spread
	const GRENADE_PROJECTILE_SCENE = preload("res://GrenadeProjectile.tscn")
	var angles = [-120, 0, 120]  # 120° apart

	for angle_offset in angles:
		var mini_grenade = GRENADE_PROJECTILE_SCENE.instantiate()
		mini_grenade.global_position = global_position

		# Mini-grenades have 40% damage and smaller AOE
		mini_grenade.damage = damage * 0.4
		mini_grenade.aoe = aoe * 0.6  # Smaller explosion radius
		mini_grenade.distance = 150  # Shorter travel distance
		mini_grenade.speed = 300
		mini_grenade.aoe_mult = aoe_mult
		mini_grenade.player = player

		# Inherit status effects
		mini_grenade.poison_enabled = poison_enabled
		mini_grenade.poison_damage = poison_damage
		mini_grenade.burn_enabled = burn_enabled
		mini_grenade.burn_damage = burn_damage

		# Set direction (spread out)
		var angle_rad = deg_to_rad(angle_offset)
		mini_grenade.rotation = angle_rad

		# Visual distinction
		if mini_grenade.has_node("Sprite2D"):
			mini_grenade.scale = Vector2(0.6, 0.6)  # Smaller
			mini_grenade.get_node("Sprite2D").modulate = Color(1.0, 0.7, 0.2)

		get_parent().add_child(mini_grenade)
