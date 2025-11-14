# DragonLaser.gd - Omega Dragon laser beam attack
extends Area2D

var damage_per_tick: float = 15.0
var tick_rate: float = 0.1
var tick_timer: float = 0.0
var duration: float = 1.5
var duration_timer: float = 0.0
var width: float = 50.0
var length: float = 800.0
var beam_direction: Vector2 = Vector2.RIGHT
var telegraph_time: float = 0.3
var telegraph_timer: float = 0.0
var is_firing: bool = false
var hit_players: Dictionary = {}  # Track when we last hit each player

# Visual elements
var beam_rect: ColorRect = null
var telegraph_rect: ColorRect = null

func _ready():
	# Collision setup
	collision_layer = 4  # Bullet layer
	collision_mask = 1   # Player layer

	# Create telegraph warning
	telegraph_rect = ColorRect.new()
	telegraph_rect.color = Color(1.0, 0.5, 0.0, 0.3)  # Orange transparent
	telegraph_rect.size = Vector2(length, width * 0.5)
	telegraph_rect.position = Vector2(0, -width * 0.25)
	add_child(telegraph_rect)

	# Create beam visual (initially hidden)
	beam_rect = ColorRect.new()
	beam_rect.color = Color(1.0, 0.4, 0.0, 0.0)  # Orange, start invisible
	beam_rect.size = Vector2(length, width)
	beam_rect.position = Vector2(0, -width * 0.5)
	add_child(beam_rect)

	# Collision shape for beam
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(length, width)
	collision.shape = shape
	collision.position = Vector2(length * 0.5, 0)
	add_child(collision)
	collision.disabled = true  # Start disabled during telegraph
	set_meta("collision_node", collision)

	# Connect signals
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	# Set rotation based on direction
	rotation = beam_direction.angle()

func _process(delta):
	# Telegraph phase
	if not is_firing:
		telegraph_timer += delta

		# Pulse telegraph warning
		var pulse = sin(telegraph_timer * 15.0) * 0.2 + 0.3
		telegraph_rect.color.a = pulse

		if telegraph_timer >= telegraph_time:
			# Start firing
			is_firing = true
			telegraph_rect.visible = false
			beam_rect.color.a = 0.8

			# Enable collision
			var collision = get_meta("collision_node")
			if collision:
				collision.disabled = false
	else:
		# Firing phase
		duration_timer += delta
		tick_timer += delta

		# Pulse beam visual
		var pulse = sin(duration_timer * 20.0) * 0.2 + 0.8
		beam_rect.color.a = pulse

		# Tick damage
		if tick_timer >= tick_rate:
			tick_timer = 0.0
			damage_overlapping_players()

		# Check if duration expired
		if duration_timer >= duration:
			queue_free()

func _on_area_entered(area):
	if area.is_in_group("player"):
		pass  # Will be handled in damage_overlapping_players

func _on_body_entered(body):
	if body.is_in_group("player"):
		pass  # Will be handled in damage_overlapping_players

func damage_overlapping_players():
	# Find all overlapping players
	var overlapping_areas = get_overlapping_areas()
	var overlapping_bodies = get_overlapping_bodies()

	var all_overlapping = overlapping_areas + overlapping_bodies

	for node in all_overlapping:
		if node.is_in_group("player") and node.has_method("take_damage"):
			node.take_damage(damage_per_tick)
			# Visual feedback could be added here
