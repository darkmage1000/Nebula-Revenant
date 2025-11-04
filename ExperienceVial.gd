# ExperienceVial.gd - FIXED: Magnetic pull instead of instant pickup
extends Area2D

# This value will be set by the mob that drops it
var value = 10

# Magnetic pull settings
var being_pulled: bool = false
var pull_speed: float = 400.0  # Speed when being sucked to player
var player_ref: Node2D = null

func _ready():
	add_to_group("xp_vial")
	# Don't collect instantly - wait for player's pickup radius

func _physics_process(delta):
	if being_pulled and is_instance_valid(player_ref):
		# Move towards player
		var direction = global_position.direction_to(player_ref.global_position)
		global_position += direction * pull_speed * delta
		
		# Check if close enough to collect
		if global_position.distance_to(player_ref.global_position) < 30.0:
			collect()

func start_pull(player: Node2D):
	if not being_pulled:
		being_pulled = true
		player_ref = player
		# Optional: Add a visual effect when pull starts
		modulate = Color(1.2, 1.2, 1.2)

func collect():
	if is_instance_valid(player_ref) and player_ref.has_method("pickup_xp"):
		player_ref.pickup_xp(value)
	queue_free()
