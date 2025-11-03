# nebula_shard.gd - PHASE 4: Meta-currency that drops from enemies
extends Area2D

@export var value: int = 1  # How many shards this pickup gives
@export var float_speed: float = 2.0
@export var float_amount: float = 15.0

var time: float = 0.0
var start_y: float = 0.0

func _ready():
	add_to_group("currency")
	start_y = global_position.y
	
	# Visual setup
	modulate = Color(0.3, 0.8, 1.0)  # Cyan color for shards
	
	# Animate
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.5)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.5)

func _physics_process(delta):
	# Float up and down
	time += delta * float_speed
	global_position.y = start_y + sin(time) * float_amount
	
	# Auto-collect if close to player
	var player = get_tree().get_first_node_in_group("player_group")
	if is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		# Magnetic pull when close
		if distance < 150:
			var direction = global_position.direction_to(player.global_position)
			global_position += direction * 300 * delta

func _on_body_entered(body):
	if body.is_in_group("player_group"):
		collect(body)

func collect(player):
	if player.has_method("collect_currency"):
		player.collect_currency(value)
	
	# Particle effect would go here
	print("💎 Collected %d Nebula Shards!" % value)
	
	queue_free()
